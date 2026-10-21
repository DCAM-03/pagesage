#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

import coordctl


POLICY = coordctl.load_policy(coordctl.DEFAULT_POLICY)


def task_text(
    *,
    lifecycle: str = "Planned",
    status: str = "DESIGN_ONLY",
    implementation: str = "DESIGN_ONLY",
    evidence: str = "UNVERIFIED",
    phases: tuple[str, str, str, str] = ("NOT_STARTED", "NOT_STARTED", "NOT_STARTED", "NOT_STARTED"),
    registry_rows: str = "| execution:backend | execution | RESERVED | pending | axis-iam-project | project-bound | axis-iam | codex/scoped-config-foundation | /tmp/scoped-config | not applicable | 2026-09-05T00:00:00Z |",
    acceptance: str = "",
) -> str:
    return f"""# Test Task

- Status: {status}
- Task Lifecycle: {lifecycle}
- Implementation State: {implementation}
- Validation Evidence: {evidence}
- Bounded compile/test worker limit and serialization rule: go test -p 16; GOMAXPROCS=16; broad suites serialized
- Evidence directory: docs/evidence/test-task
- Recovery classification: NONE
- Recovery attempts without state change: 0
- Delivery state: NOT_SENT
- Delivery method: not sent
- Pre-send source turn ID: not applicable
- Intended continuation fingerprint: not applicable
- Observed target event kind: not applicable
- Confirmed target turn ID: not applicable
- Confirmed initiating event kind: not applicable
- Direct delivery attempts: 0
- Native queue attempts: 0

## Thread Registry And Recovery

- Canonical saved project / project ID: axis-iam / axis-iam-project
- Coordination instruction revision / materialization check: abc123 / PASS
- Relevant instruction files materialized in the dispatch base: yes
- Handoff serialization checked: yes

## Dispatch Reconciliation

- Dispatch reservation ID / UTC: dispatch-1 / 2026-09-05T00:00:00Z
- Registry status: COMPLETE
- Dispatch base consistency across task / handoff / branch / worktree / reservation: yes
- Exclusive execution ownership verified: yes
- `create_thread` project target shape verified (`projectId` nested inside `target`): yes

## Validation Phase State

- Current Validation Phase: NOT_STARTED
- Phase 1 Result: {phases[0]}
- Phase 2 Result: {phases[1]}
- Phase 3 Result: {phases[2]}
- Phase 4 Result: {phases[3]}

## Session Registry

| Slot | Role | State | Thread ID | Project ID | Scope | Repository | Branch | Worktree | Originating execution | Last observed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
{registry_rows}

## User-Visible Behavior

Test behavior.

## Acceptance Records

{acceptance}
"""


def load_temp(text: str, directory: str) -> coordctl.TaskRecord:
    path = Path(directory) / "task.md"
    path.write_text(text, encoding="utf-8")
    return coordctl.load_record(path)


class TaskValidationTest(unittest.TestCase):
    def test_planned_dispatch_preflight_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(), directory)
            self.assertEqual([], coordctl.preflight_dispatch(record, POLICY))

    def test_validation_evidence_requires_matching_status(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(status="TOOLING_ONLY", evidence="UNVERIFIED"), directory)
            self.assertTrue(any("inconsistent" in error for error in coordctl.validate_task(record, POLICY)))

    def test_worker_limit_above_policy_maximum_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(
                task_text().replace("go test -p 16; GOMAXPROCS=16", "go test -p 17; GOMAXPROCS=17"),
                directory,
            )
            self.assertTrue(any("exceeds policy maximum 16" in error for error in coordctl.validate_task(record, POLICY)))

    def test_phase_order_is_enforced(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(phases=("NOT_STARTED", "PASS", "NOT_STARTED", "NOT_STARTED")), directory)
            self.assertTrue(any("Phase 2 cannot start" in error for error in coordctl.validate_task(record, POLICY)))

    def test_duplicate_active_owner_is_rejected(self) -> None:
        duplicate = "\n".join(
            [
                "| execution:backend-a | execution | ACTIVE | thread-1 | axis-iam-project | project-bound | axis-iam | codex/scoped-config-foundation | /tmp/scoped-config | not applicable | 2026-09-05T00:00:00Z |",
                "| execution:backend-b | execution | BLOCKED | thread-2 | axis-iam-project | project-bound | axis-iam | codex/scoped-config-foundation | /tmp/scoped-config | not applicable | 2026-09-05T00:01:00Z |",
            ],
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(registry_rows=duplicate), directory)
            self.assertTrue(any("duplicate active" in error for error in coordctl.validate_task(record, POLICY)))

    def test_confirmed_delivery_requires_new_native_user_turn(self) -> None:
        confirmed = (
            task_text()
            .replace("- Delivery state: NOT_SENT", "- Delivery state: CONFIRMED")
            .replace("- Confirmed target turn ID: not applicable", "- Confirmed target turn ID: turn-2")
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(confirmed, directory)
            self.assertTrue(any("initiating event kind userMessage" in error for error in coordctl.validate_task(record, POLICY)))

    def test_channel_mismatch_requires_matching_recovery_classification(self) -> None:
        mismatched = task_text().replace("- Delivery state: NOT_SENT", "- Delivery state: CHANNEL_MISMATCH")
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(mismatched, directory)
            self.assertTrue(any("DELIVERY_CHANNEL_MISMATCH" in error for error in coordctl.validate_task(record, POLICY)))

    def test_delivery_attempt_limits_are_enforced(self) -> None:
        repeated = task_text().replace("- Direct delivery attempts: 0", "- Direct delivery attempts: 2")
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(repeated, directory)
            self.assertTrue(any("Direct delivery attempts exceeds" in error for error in coordctl.validate_task(record, POLICY)))

    def test_multiple_active_acceptance_owners_are_rejected(self) -> None:
        duplicate = "\n".join(
            [
                "| acceptance:task-a | acceptance | ACTIVE | acceptance-1 | axis-iam-project | project-bound | axis-iam | review/a | /tmp/review-a | execution-1 | 2026-09-05T00:00:00Z |",
                "| acceptance:task-b | acceptance | BLOCKED | acceptance-2 | axis-iam-project | project-bound | axis-iam | review/b | /tmp/review-b | execution-1 | 2026-09-05T00:01:00Z |",
            ],
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(registry_rows=duplicate), directory)
            self.assertTrue(any("multiple active acceptance owners" in error for error in coordctl.validate_task(record, POLICY)))

    def test_accepted_requires_terminal_acceptance_and_phases(self) -> None:
        registry = "\n".join(
            [
                "| execution:backend | execution | COMPLETED | execution-1 | axis-iam-project | project-bound | axis-iam | codex/scoped-config-foundation | /tmp/scoped-config | not applicable | 2026-09-05T00:00:00Z |",
                "| acceptance:task | acceptance | ACCEPTED | acceptance-1 | axis-iam-project | project-bound | axis-iam | codex/scoped-config-foundation | /tmp/scoped-config-review | execution-1 | 2026-09-05T00:10:00Z |",
            ],
        )
        acceptance = """### 2026-09-05 - acceptance

- Outcome: ACCEPTED
- Acceptance session ID: acceptance-1
- Originating execution session ID: execution-1
"""
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(
                task_text(
                    lifecycle="Accepted",
                    status="RUNTIME_PASS",
                    implementation="IMPLEMENTED",
                    evidence="RUNTIME_PASS",
                    phases=("PASS", "PASS", "NOT_APPLICABLE", "PASS"),
                    registry_rows=registry,
                    acceptance=acceptance,
                ),
                directory,
            )
            self.assertEqual([], coordctl.preflight_merge(record, POLICY))

    def test_merge_rejects_missing_phase_four_acceptance(self) -> None:
        registry = "\n".join(
            [
                "| execution:backend | execution | COMPLETED | execution-1 | axis-iam-project | project-bound | axis-iam | codex/scoped-config-foundation | /tmp/scoped-config | not applicable | 2026-09-05T00:00:00Z |",
                "| acceptance:task | acceptance | ACCEPTED | acceptance-1 | axis-iam-project | project-bound | axis-iam | codex/scoped-config-foundation | /tmp/scoped-config-review | execution-1 | 2026-09-05T00:10:00Z |",
            ],
        )
        acceptance = """### 2026-09-05 - acceptance

- Outcome: ACCEPTED
- Acceptance session ID: acceptance-1
- Originating execution session ID: execution-1
"""
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(
                task_text(
                    lifecycle="Accepted",
                    status="RUNTIME_PASS",
                    implementation="IMPLEMENTED",
                    evidence="RUNTIME_PASS",
                    phases=("PASS", "PASS", "NOT_APPLICABLE", "NOT_STARTED"),
                    registry_rows=registry,
                    acceptance=acceptance,
                ),
                directory,
            )
            self.assertTrue(any("Phase 4 PASS" in error for error in coordctl.preflight_merge(record, POLICY)))


class ModelRoutingTest(unittest.TestCase):
    def test_dispatch_uses_active_model_and_one_lower_effort(self) -> None:
        self.assertEqual(
            [],
            coordctl.check_route(
                POLICY,
                phase="phase2",
                role="acceptance",
                dispatch_kind="initial",
                model="gpt-6.1-sol",
                effort="high",
                source_model="gpt-6.1-sol",
                source_effort="xhigh",
            ),
        )

    def test_dispatch_rejects_same_effort(self) -> None:
        errors = coordctl.check_route(
            POLICY,
            phase="phase2",
            role="acceptance",
            dispatch_kind="initial",
            model="gpt-6.1-sol",
            effort="xhigh",
            source_model="gpt-6.1-sol",
            source_effort="xhigh",
        )
        self.assertTrue(any("one lower effort high" in error for error in errors))

    def test_dispatch_rejects_different_model_family(self) -> None:
        errors = coordctl.check_route(
            POLICY,
            phase="phase1",
            role="execution",
            dispatch_kind="initial",
            model="gpt-6-sol",
            effort="high",
            source_model="gpt-6.1-sol",
            source_effort="xhigh",
        )
        self.assertTrue(any("active coordination model gpt-6.1-sol" in error for error in errors))

    def test_dispatch_requires_source_route(self) -> None:
        errors = coordctl.check_route(
            POLICY,
            phase="phase1",
            role="execution",
            dispatch_kind="initial",
            model="gpt-6.1-sol",
            effort="high",
        )
        self.assertTrue(any("active coordination model" in error for error in errors))

    def test_explicit_user_model_override_is_recordable(self) -> None:
        self.assertEqual(
            [],
            coordctl.check_route(
                POLICY,
                phase="phase1",
                role="execution",
                dispatch_kind="initial",
                model="gpt-6-astra",
                effort="medium",
                user_model_override=True,
                override_reason="User explicitly selected a different model for this dispatch.",
            ),
        )

    def test_user_model_override_requires_reason(self) -> None:
        errors = coordctl.check_route(
            POLICY,
            phase="phase1",
            role="execution",
            dispatch_kind="initial",
            model="gpt-6-astra",
            effort="medium",
            user_model_override=True,
        )
        self.assertTrue(any("explicit reason" in error for error in errors))

    def test_existing_slot_preserves_model_and_effort_across_phases(self) -> None:
        for phase, role in POLICY["phase_roles"].items():
            with self.subTest(phase=phase):
                self.assertEqual(
                    [],
                    coordctl.check_route(
                        POLICY,
                        phase=phase,
                        role=role,
                        dispatch_kind="continuation",
                        model="gpt-6.1-sol",
                        effort="medium",
                        established_model="gpt-6.1-sol",
                        established_effort="medium",
                        source_model="gpt-5.6-sol",
                        source_effort="low",
                    ),
                )

    def test_existing_slot_does_not_need_coordinator_route(self) -> None:
        self.assertEqual(
            [],
            coordctl.check_route(
                POLICY,
                phase="phase1",
                role="execution",
                dispatch_kind="continuation",
                model="gpt-6.1-sol",
                effort="medium",
                established_model="gpt-6.1-sol",
                established_effort="medium",
            ),
        )

    def test_continuation_rejects_silent_model_or_effort_change(self) -> None:
        for model, effort in (("gpt-5.6-sol", "medium"), ("gpt-6.1-sol", "low"), ("gpt-5.6-sol", "low")):
            with self.subTest(model=model, effort=effort):
                errors = coordctl.check_route(
                    POLICY,
                    phase="remediation",
                    role="execution",
                    dispatch_kind="continuation",
                    model=model,
                    effort=effort,
                    established_model="gpt-6.1-sol",
                    established_effort="medium",
                    source_model="gpt-5.6-sol",
                    source_effort="medium",
                )
                self.assertTrue(any("preserve established slot" in error for error in errors))

    def test_missing_established_route_never_falls_back_to_coordinator(self) -> None:
        for established_model, established_effort in (
            (None, None), ("gpt-6.1-sol", None), (None, "medium"),
            ("<slot-model>", "medium"), ("unverified", "medium"), ("missing", "medium"),
        ):
            for override in (False, True):
                with self.subTest(model=established_model, effort=established_effort, override=override):
                    errors = coordctl.check_route(
                        POLICY,
                        phase="phase1",
                        role="execution",
                        dispatch_kind="continuation",
                        model="gpt-5.6-sol",
                        effort="low",
                        source_model="gpt-5.6-sol",
                        source_effort="medium",
                        established_model=established_model,
                        established_effort=established_effort,
                        user_model_override=override,
                        override_reason="User selected the target." if override else None,
                    )
                    self.assertTrue(any("verified established slot" in error for error in errors))

    def test_continuation_route_change_requires_explicit_override_and_reason(self) -> None:
        for override, reason, valid in (
            (False, "User selected the target.", False),
            (True, None, False),
            (True, "User selected this model and effort for the execution slot.", True),
        ):
            with self.subTest(override=override, reason=reason):
                errors = coordctl.check_route(
                    POLICY,
                    phase="remediation",
                    role="execution",
                    dispatch_kind="continuation",
                    model="gpt-6-astra",
                    effort="high",
                    established_model="gpt-6.1-sol",
                    established_effort="medium",
                    user_model_override=override,
                    override_reason=reason,
                )
                self.assertEqual(valid, not errors)

    def test_existing_slot_cannot_use_initial_routing(self) -> None:
        for phase, model, effort in (
            ("remediation", None, None),
            ("phase1", "gpt-6.1-sol", "medium"),
        ):
            with self.subTest(phase=phase):
                errors = coordctl.check_route(
                    POLICY,
                    phase=phase,
                    role="execution",
                    dispatch_kind="initial",
                    model="gpt-5.6-sol",
                    effort="low",
                    source_model="gpt-5.6-sol",
                    source_effort="medium",
                    established_model=model,
                    established_effort=effort,
                )
                self.assertTrue(any("requires dispatch kind continuation" in error for error in errors))

    def test_route_requires_valid_dispatch_kind_and_role_even_with_override(self) -> None:
        for kind, role in (("unknown", "execution"), ("initial", "acceptance")):
            with self.subTest(kind=kind, role=role):
                self.assertTrue(coordctl.check_route(
                    POLICY,
                    phase="phase1",
                    role=role,
                    dispatch_kind=kind,
                    model="gpt-6-astra",
                    effort="medium",
                    user_model_override=True,
                    override_reason="User selected the target.",
                ))

    def test_initial_route_cannot_silently_choose_a_tier_without_lower_option(self) -> None:
        errors = coordctl.check_route(
            POLICY,
            phase="phase1",
            role="execution",
            dispatch_kind="initial",
            model="gpt-6.1-sol",
            effort="none",
            source_model="gpt-6.1-sol",
            source_effort="none",
        )
        self.assertTrue(any("no lower supported tier" in error for error in errors))

    def test_route_rejects_missing_target_or_unknown_reasoning_effort(self) -> None:
        for model, effort in (("", "medium"), ("gpt-6-astra", ""), ("gpt-6-astra", "unknown")):
            with self.subTest(model=model, effort=effort):
                self.assertTrue(coordctl.check_route(
                    POLICY,
                    phase="phase1",
                    role="execution",
                    dispatch_kind="initial",
                    model=model,
                    effort=effort,
                    user_model_override=True,
                    override_reason="User selected the target.",
                ))

    def test_cli_enforces_continuation_route(self) -> None:
        base = [
            "python3", str(Path(coordctl.__file__)), "route",
            "--phase", "remediation", "--role", "execution",
            "--dispatch-kind", "continuation",
            "--established-model", "gpt-6.1-sol", "--established-effort", "medium",
        ]
        for model, effort, expected_code in (("gpt-6.1-sol", "medium", 0), ("gpt-5.6-sol", "low", 1)):
            with self.subTest(model=model, effort=effort):
                result = subprocess.run(base + ["--model", model, "--effort", effort], text=True, capture_output=True)
                self.assertEqual(expected_code, result.returncode, result.stderr)

    def test_cli_requires_explicit_dispatch_kind(self) -> None:
        result = subprocess.run(
            ["python3", str(Path(coordctl.__file__)), "route", "--phase", "phase1", "--role", "execution",
             "--model", "gpt-6.1-sol", "--effort", "medium"],
            text=True, capture_output=True,
        )
        self.assertEqual(2, result.returncode)
        self.assertIn("--dispatch-kind", result.stderr)


class GitRefTest(unittest.TestCase):
    def test_verify_ref_checks_ancestry_and_expected_ref(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(["git", "init", "-b", "main", str(repo)], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "coordctl@example.invalid"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "coordctl test"], check=True)
            (repo / "file.txt").write_text("test\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", "file.txt"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-m", "test"], check=True, stdout=subprocess.DEVNULL)
            commit = subprocess.run(
                ["git", "-C", str(repo), "rev-parse", "HEAD"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            ).stdout.strip()
            self.assertEqual([], coordctl.verify_ref(repo, commit, "main", commit))


if __name__ == "__main__":
    unittest.main()
