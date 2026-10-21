#!/usr/bin/env python3
"""Deterministic gates for coordinated task records and Git closure."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_POLICY = Path(__file__).resolve().parents[1] / "workflow-policy.json"


@dataclass(frozen=True)
class TaskRecord:
    path: Path
    text: str
    preamble: str
    fields: dict[str, str]
    phases: dict[str, str]
    registry: list[dict[str, str]]


def normalized(value: str | None) -> str:
    return (value or "").strip().strip("`").strip()


def canonical(value: str | None, options: list[str]) -> str:
    normalized_value = normalized(value).casefold()
    for option in options:
        if option.casefold() == normalized_value:
            return option
    return normalized(value)


def is_placeholder(value: str | None) -> bool:
    value = normalized(value)
    return not value or value.startswith("<") or " | " in value or value.lower() in {
        "yes | no",
        "not started",
        "missing",
        "none",
        "n/a",
    }


def parse_fields(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for match in re.finditer(r"(?m)^-\s+([^:\n]+):\s*(.*?)\s*$", text):
        field_name = match.group(1).strip().replace("`", "")
        fields[field_name] = normalized(match.group(2))
    return fields


def section(text: str, title: str) -> str:
    match = re.search(rf"(?m)^##\s+{re.escape(title)}\s*$", text)
    if not match:
        return ""
    following = text[match.end() :]
    next_heading = re.search(r"(?m)^##\s+", following)
    return following[: next_heading.start()] if next_heading else following


def parse_markdown_table(text: str) -> list[dict[str, str]]:
    rows = [line.strip() for line in text.splitlines() if line.strip().startswith("|")]
    if len(rows) < 2:
        return []
    headers = [cell.strip() for cell in rows[0].strip("|").split("|")]
    separator = [cell.strip() for cell in rows[1].strip("|").split("|")]
    if len(separator) != len(headers) or not all(re.fullmatch(r":?-{3,}:?", cell) for cell in separator):
        return []
    result: list[dict[str, str]] = []
    for raw in rows[2:]:
        values = [normalized(cell) for cell in raw.strip("|").split("|")]
        if len(values) != len(headers):
            continue
        result.append(dict(zip(headers, values, strict=True)))
    return result


def load_record(path: Path) -> TaskRecord:
    text = path.read_text(encoding="utf-8")
    first_heading = re.search(r"(?m)^##\s+", text)
    preamble = text[: first_heading.start()] if first_heading else text
    return TaskRecord(
        path=path,
        text=text,
        preamble=preamble,
        fields=parse_fields(preamble),
        phases=parse_fields(section(text, "Validation Phase State")),
        registry=parse_markdown_table(section(text, "Session Registry")),
    )


def load_policy(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def latest_acceptance_fields(text: str) -> dict[str, str]:
    body = section(text, "Acceptance Records")
    blocks = re.findall(r"(?ms)^###\s+.+?(?=^###\s+|\Z)", body)
    candidates = [parse_fields(block) for block in blocks]
    candidates = [fields for fields in candidates if "Outcome" in fields]
    return candidates[-1] if candidates else {}


def validate_phase_state(record: TaskRecord, policy: dict[str, object]) -> list[str]:
    errors: list[str] = []
    phase_names = list(policy["validation_phases"])
    allowed_results = set(policy["phase_results"])
    na_allowed = set(policy["phase_not_applicable_allowed"])
    results: list[str] = []
    for phase in phase_names:
        field = f"Phase {phase.split('_', 1)[0]} Result"
        result = normalized(record.phases.get(field, "NOT_STARTED")).upper()
        if result not in allowed_results:
            errors.append(f"{field} has invalid result {result!r}")
        if result == "NOT_APPLICABLE" and phase not in na_allowed:
            errors.append(f"{field} cannot be NOT_APPLICABLE")
        results.append(result)

    for index, result in enumerate(results[1:], 1):
        if result != "NOT_STARTED" and results[index - 1] not in {"PASS", "NOT_APPLICABLE"}:
            errors.append(f"Phase {index + 1} cannot start before Phase {index} passes")

    current = normalized(record.phases.get("Current Validation Phase", "NOT_STARTED")).upper()
    allowed_current = {"NOT_STARTED", "COMPLETE", *phase_names}
    if current not in allowed_current:
        errors.append(f"Current Validation Phase has invalid value {current!r}")
    if current == "COMPLETE" and results[-1] not in {"PASS", "NOT_APPLICABLE"}:
        errors.append("Current Validation Phase COMPLETE requires Phase 4 PASS or NOT_APPLICABLE")
    return errors


def validate_registry(record: TaskRecord, policy: dict[str, object]) -> list[str]:
    errors: list[str] = []
    active_states = set(policy["active_session_states"])
    terminal_states = set(policy["terminal_session_states"])
    allowed_states = active_states | terminal_states
    allowed_scopes = {scope.casefold() for scope in policy["session_scopes"]}
    seen_active: dict[tuple[str, str, str, str], int] = {}
    seen_slots: dict[str, int] = {}
    active_acceptance_rows: list[int] = []
    for index, row in enumerate(record.registry, 1):
        state = normalized(row.get("State")).upper()
        role = normalized(row.get("Role")).lower()
        slot = normalized(row.get("Slot"))
        scope = normalized(row.get("Scope")).lower()
        if slot:
            if slot in seen_slots:
                errors.append(f"session registry rows {seen_slots[slot]} and {index} duplicate stable slot {slot!r}")
            else:
                seen_slots[slot] = index
        if role not in {"execution", "acceptance"}:
            errors.append(f"session registry row {index} has invalid role {role!r}")
        if state not in allowed_states:
            errors.append(f"session registry row {index} has invalid state {state!r}")
        if scope not in allowed_scopes:
            errors.append(
                f"session registry row {index} must record a scope from {sorted(allowed_scopes)}, got {scope!r}",
            )
        if state != "RESERVED" and is_placeholder(row.get("Session ID")):
            errors.append(f"session registry row {index} requires Session ID outside RESERVED state")
        if state in active_states:
            if role == "acceptance":
                active_acceptance_rows.append(index)
            key = (
                role,
                normalized(row.get("Repository")),
                normalized(row.get("Branch")),
                normalized(row.get("Worktree")),
            )
            if any(not value for value in key):
                errors.append(f"session registry row {index} has an incomplete ownership tuple")
            elif key in seen_active:
                errors.append(
                    f"duplicate active session ownership tuple in rows {seen_active[key]} and {index}: {key}",
                )
            else:
                seen_active[key] = index
    if len(active_acceptance_rows) > 1:
        errors.append(f"task has multiple active acceptance owners in rows {active_acceptance_rows}")
    return errors


def validate_task(record: TaskRecord, policy: dict[str, object]) -> list[str]:
    errors: list[str] = []
    all_fields = parse_fields(record.text)
    max_lines = int(policy["limits"]["max_task_lines"])
    line_count = len(record.text.splitlines())
    if line_count > max_lines:
        errors.append(f"task has {line_count} lines; maximum is {max_lines}; move long evidence to an evidence file")

    required = ("Status", "Task Lifecycle", "Implementation State", "Validation Evidence")
    for field in required:
        if is_placeholder(record.fields.get(field)):
            errors.append(f"missing concrete top-level {field}")

    status = normalized(record.fields.get("Status")).upper()
    lifecycle = canonical(record.fields.get("Task Lifecycle"), list(policy["task_lifecycles"]))
    implementation = normalized(record.fields.get("Implementation State")).upper()
    evidence = normalized(record.fields.get("Validation Evidence")).upper()

    if lifecycle not in policy["task_lifecycles"]:
        errors.append(f"invalid Task Lifecycle {lifecycle!r}")
    if implementation not in policy["implementation_states"]:
        errors.append(f"invalid Implementation State {implementation!r}")
    if evidence not in policy["validation_evidence"]:
        errors.append(f"invalid Validation Evidence {evidence!r}")
    expected_statuses = policy["status_by_validation_evidence"].get(evidence, [])
    if status not in expected_statuses:
        errors.append(f"Status {status!r} is inconsistent with Validation Evidence {evidence!r}")
    if evidence in {"RUNTIME_PASS", "E2E_PASS"} and implementation != "IMPLEMENTED":
        errors.append(f"{evidence} requires Implementation State IMPLEMENTED")

    worker_limit = all_fields.get("Bounded compile/test worker limit and serialization rule")
    if is_placeholder(worker_limit) or not re.search(r"\d", normalized(worker_limit)):
        errors.append("a concrete bounded compile/test worker limit is required")
    elif any(
        int(value) > int(policy["limits"]["max_parallel_compile_test_workers"])
        for value in re.findall(r"\d+", normalized(worker_limit))
    ):
        errors.append(
            "compile/test worker limit exceeds policy maximum "
            f"{policy['limits']['max_parallel_compile_test_workers']}",
        )
    evidence_location = all_fields.get("Evidence directory")
    if is_placeholder(evidence_location):
        errors.append("a concrete Evidence directory is required")

    recovery = normalized(all_fields.get("Recovery classification", "NONE")).upper()
    if recovery not in policy["recovery_classifications"]:
        errors.append(f"invalid Recovery classification {recovery!r}")
    retries = normalized(all_fields.get("Recovery attempts without state change", "0"))
    if not retries.isdigit():
        errors.append("Recovery attempts without state change must be an integer")
    elif int(retries) > int(policy["limits"]["max_recovery_attempts_without_change"]):
        errors.append("recovery attempt limit exceeded")

    delivery_value = all_fields.get("Delivery state")
    if delivery_value is not None:
        delivery = normalized(delivery_value).upper()
        if delivery not in policy["delivery_states"]:
            errors.append(f"invalid Delivery state {delivery!r}")

        attempts = normalized(all_fields.get("Direct delivery attempts", "0"))
        if not attempts.isdigit():
            errors.append("Direct delivery attempts must be an integer")
        elif int(attempts) > int(policy["limits"]["max_direct_delivery_attempts"]):
            errors.append(f"Direct delivery attempts exceeds policy maximum {policy['limits']['max_direct_delivery_attempts']}")

        if delivery == "CONFIRMED":
            if is_placeholder(all_fields.get("Confirmed response ID")):
                errors.append("CONFIRMED delivery requires Confirmed response ID")
            if normalized(all_fields.get("Confirmed independent execution evidence")) != "yes":
                errors.append("CONFIRMED delivery requires Confirmed independent execution evidence: yes")
        if delivery == "CHANNEL_MISMATCH" and recovery != "DELIVERY_CHANNEL_MISMATCH":
            errors.append("CHANNEL_MISMATCH delivery requires Recovery classification DELIVERY_CHANNEL_MISMATCH")

    errors.extend(validate_phase_state(record, policy))
    errors.extend(validate_registry(record, policy))

    if lifecycle == "Accepted":
        acceptance = latest_acceptance_fields(record.text)
        if normalized(acceptance.get("Outcome")).upper() != "ACCEPTED":
            errors.append("Accepted lifecycle requires a latest ACCEPTED acceptance record")
        if implementation != "IMPLEMENTED" or evidence not in {"RUNTIME_PASS", "E2E_PASS"}:
            errors.append("Accepted lifecycle requires IMPLEMENTED plus RUNTIME_PASS or E2E_PASS")
        phase_results = [normalized(record.phases.get(f"Phase {number} Result")).upper() for number in (1, 2, 3)]
        if phase_results[0:2] != ["PASS", "PASS"] or phase_results[2] not in {"PASS", "NOT_APPLICABLE"}:
            errors.append("Accepted lifecycle requires Phase 1/2 PASS and Phase 3 PASS or NOT_APPLICABLE")
    return errors


def require_fields(record: TaskRecord, checks: dict[str, set[str] | None]) -> list[str]:
    errors: list[str] = []
    combined = {
        **record.fields,
        **parse_fields(section(record.text, "Session Registry And Recovery")),
        **parse_fields(section(record.text, "Dispatch Reconciliation")),
    }
    for field, allowed in checks.items():
        value = normalized(combined.get(field))
        if is_placeholder(value):
            errors.append(f"missing concrete {field}")
        elif allowed is not None and value.lower() not in allowed:
            errors.append(f"{field} must be one of {sorted(allowed)}, got {value!r}")
    return errors


def preflight_dispatch(record: TaskRecord, policy: dict[str, object]) -> list[str]:
    errors = validate_task(record, policy)
    lifecycle = canonical(record.fields.get("Task Lifecycle"), list(policy["task_lifecycles"]))
    if lifecycle != "Planned":
        errors.append("dispatch preflight requires Task Lifecycle Planned")
    errors.extend(
        require_fields(
            record,
            {
                "Coordination instruction revision / materialization check": None,
                "Delegation explicitly authorized by the user": {"yes"},
                "Dispatch target recorded with its role and scope": {"yes"},
                "Dispatch reservation ID / UTC": None,
                "Registry status": {"complete"},
                "Dispatch base consistency across task / handoff / branch / worktree / reservation": {"yes"},
                "Exclusive execution ownership verified": {"yes"},
            },
        ),
    )
    reserved_execution = [
        row
        for row in record.registry
        if normalized(row.get("Role")).lower() == "execution"
        and normalized(row.get("State")).upper() == "RESERVED"
    ]
    if len(reserved_execution) != 1:
        errors.append("dispatch preflight requires exactly one RESERVED execution registry row")
    return errors


def preflight_acceptance(record: TaskRecord, policy: dict[str, object]) -> list[str]:
    errors = validate_task(record, policy)
    if canonical(record.fields.get("Task Lifecycle"), list(policy["task_lifecycles"])) != "Ready for Acceptance":
        errors.append("acceptance preflight requires Task Lifecycle Ready for Acceptance")
    if normalized(record.phases.get("Phase 1 Result")).upper() != "PASS":
        errors.append("acceptance preflight requires Phase 1 PASS")
    completed_execution = [
        row
        for row in record.registry
        if normalized(row.get("Role")).lower() == "execution"
        and normalized(row.get("State")).upper() == "COMPLETED"
        and not is_placeholder(row.get("Session ID"))
    ]
    if not completed_execution:
        errors.append("acceptance preflight requires a completed execution registry row")
    acceptance_scope = [
        normalized(row.get("Scope")).lower()
        for row in record.registry
        if normalized(row.get("Role")).lower() == "acceptance"
    ]
    if acceptance_scope and "same-session" in acceptance_scope:
        errors.append("acceptance must not be recorded in the same session that implemented the task")
    return errors


def preflight_merge(record: TaskRecord, policy: dict[str, object]) -> list[str]:
    errors = validate_task(record, policy)
    if canonical(record.fields.get("Task Lifecycle"), list(policy["task_lifecycles"])) != "Accepted":
        errors.append("merge preflight requires Task Lifecycle Accepted")
    if normalized(record.phases.get("Phase 4 Result")).upper() not in {"PASS", "NOT_APPLICABLE"}:
        errors.append("merge preflight requires Phase 4 PASS or evidence-backed NOT_APPLICABLE")
    return errors


def run_git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def verify_ref(repo: Path, accepted_commit: str, target_branch: str, expected_ref: str | None) -> list[str]:
    errors: list[str] = []
    root = run_git(repo, "rev-parse", "--show-toplevel")
    if root.returncode != 0 or Path(root.stdout.strip()).resolve() != repo.resolve():
        return [f"repository is not the exact Git root: {repo}"]
    branch_ref = f"refs/heads/{target_branch}"
    actual = run_git(repo, "rev-parse", branch_ref)
    if actual.returncode != 0:
        errors.append(f"cannot resolve target branch {target_branch!r}: {actual.stderr.strip()}")
        return errors
    ancestor = run_git(repo, "merge-base", "--is-ancestor", accepted_commit, branch_ref)
    if ancestor.returncode != 0:
        errors.append(f"accepted commit {accepted_commit} is not an ancestor of {target_branch}")
    if expected_ref and actual.stdout.strip() != expected_ref:
        errors.append(f"target branch ref {actual.stdout.strip()} does not equal expected ref {expected_ref}")
    return errors


def print_result(errors: list[str], success: str) -> int:
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(success)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, default=DEFAULT_POLICY)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("validate-task", "preflight-dispatch", "preflight-acceptance", "preflight-merge"):
        sub = subparsers.add_parser(name)
        sub.add_argument("task", type=Path)
    transition = subparsers.add_parser("check-transition")
    transition.add_argument("from_lifecycle")
    transition.add_argument("to_lifecycle")
    ref = subparsers.add_parser("verify-ref")
    ref.add_argument("--repo", type=Path, required=True)
    ref.add_argument("--accepted-commit", required=True)
    ref.add_argument("--target-branch", required=True)
    ref.add_argument("--expected-ref")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    policy = load_policy(args.policy)
    if args.command == "verify-ref":
        return print_result(
            verify_ref(args.repo, args.accepted_commit, args.target_branch, args.expected_ref),
            "Ref verification passed.",
        )
    if args.command == "check-transition":
        allowed = policy["allowed_lifecycle_transitions"].get(args.from_lifecycle, [])
        errors = [] if args.to_lifecycle in allowed else [
            f"lifecycle transition {args.from_lifecycle!r} -> {args.to_lifecycle!r} is not allowed",
        ]
        return print_result(errors, "Lifecycle transition is allowed.")

    record = load_record(args.task)
    functions = {
        "validate-task": validate_task,
        "preflight-dispatch": preflight_dispatch,
        "preflight-acceptance": preflight_acceptance,
        "preflight-merge": preflight_merge,
    }
    errors = functions[args.command](record, policy)
    return print_result(errors, f"{args.command} passed for {args.task}.")


if __name__ == "__main__":
    raise SystemExit(main())
