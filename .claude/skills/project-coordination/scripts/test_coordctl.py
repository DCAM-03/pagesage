#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

import coordctl


POLICY = coordctl.load_policy(coordctl.DEFAULT_POLICY)

PAGE_SAGE_ROW = (
    "| execution:pdf | execution | RESERVED | pending | same-session | pagesage "
    "| poc/pdf-graphics-canvas | <PROJECT_ROOT> | not applicable | 2026-10-20T00:00:00Z |"
)


def task_text(
    *,
    lifecycle: str = "Planned",
    status: str = "DESIGN_ONLY",
    implementation: str = "DESIGN_ONLY",
    evidence: str = "UNVERIFIED",
    phases: tuple[str, str, str, str] = ("NOT_STARTED", "NOT_STARTED", "NOT_STARTED", "NOT_STARTED"),
    registry_rows: str = PAGE_SAGE_ROW,
    acceptance: str = "",
) -> str:
    return f"""# Test Task

- Status: {status}
- Task Lifecycle: {lifecycle}
- Implementation State: {implementation}
- Validation Evidence: {evidence}
- Bounded compile/test worker limit and serialization rule: flutter test --concurrency=4; analyze serialized
- Evidence directory: docs/evidence/test-task
- Recovery classification: NONE
- Recovery attempts without state change: 0
- Delivery state: NOT_SENT
- Delivery method: not sent
- Intended continuation fingerprint: not applicable
- Confirmed response ID: not applicable
- Confirmed independent execution evidence: not applicable
- Direct delivery attempts: 0

## Session Registry And Recovery

- Coordination instruction revision / materialization check: abc123 / PASS
- Delegation explicitly authorized by the user: yes
- Dispatch target recorded with its role and scope: yes

## Dispatch Reconciliation

- Dispatch reservation ID / UTC: dispatch-1 / 2026-10-20T00:00:00Z
- Registry status: COMPLETE
- Dispatch base consistency across task / handoff / branch / worktree / reservation: yes
- Exclusive execution ownership verified: yes

## Validation Phase State

- Current Validation Phase: NOT_STARTED
- Phase 1 Result: {phases[0]}
- Phase 2 Result: {phases[1]}
- Phase 3 Result: {phases[2]}
- Phase 4 Result: {phases[3]}

## Session Registry

| Slot | Role | State | Session ID | Scope | Repository | Branch | Worktree | Originating execution | Last observed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
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


ACCEPTED_REGISTRY = "\n".join(
    [
        "| execution:pdf | execution | COMPLETED | execution-1 | same-session | pagesage "
        "| poc/pdf-graphics-canvas | <PROJECT_ROOT> | not applicable | 2026-10-20T00:00:00Z |",
        "| acceptance:task | acceptance | ACCEPTED | acceptance-1 | separate-user-session | pagesage "
        "| poc/pdf-graphics-canvas | <PROJECT_ROOT>-review | execution-1 | 2026-10-20T00:10:00Z |",
    ],
)

ACCEPTED_RECORD = """### 2026-10-20 - acceptance

- Outcome: ACCEPTED
- Acceptance session ID: acceptance-1
- Originating execution session ID: execution-1
"""


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
                task_text().replace("--concurrency=4", "--concurrency=17"),
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
                "| execution:a | execution | ACTIVE | session-1 | same-session | pagesage "
                "| poc/pdf-graphics-canvas | <PROJECT_ROOT> | not applicable | 2026-10-20T00:00:00Z |",
                "| execution:b | execution | BLOCKED | session-2 | same-session | pagesage "
                "| poc/pdf-graphics-canvas | <PROJECT_ROOT> | not applicable | 2026-10-20T00:01:00Z |",
            ],
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(registry_rows=duplicate), directory)
            self.assertTrue(any("duplicate active" in error for error in coordctl.validate_task(record, POLICY)))

    def test_confirmed_delivery_requires_independent_execution_evidence(self) -> None:
        confirmed = (
            task_text()
            .replace("- Delivery state: NOT_SENT", "- Delivery state: CONFIRMED")
            .replace("- Confirmed response ID: not applicable", "- Confirmed response ID: response-2")
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(confirmed, directory)
            self.assertTrue(
                any(
                    "Confirmed independent execution evidence" in error
                    for error in coordctl.validate_task(record, POLICY)
                ),
            )

    def test_confirmed_delivery_passes_with_both_confirmations(self) -> None:
        confirmed = (
            task_text()
            .replace("- Delivery state: NOT_SENT", "- Delivery state: CONFIRMED")
            .replace("- Confirmed response ID: not applicable", "- Confirmed response ID: response-2")
            .replace(
                "- Confirmed independent execution evidence: not applicable",
                "- Confirmed independent execution evidence: yes",
            )
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(confirmed, directory)
            self.assertEqual([], coordctl.validate_task(record, POLICY))

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

    def test_registry_requires_a_known_scope(self) -> None:
        unknown_scope = PAGE_SAGE_ROW.replace("same-session", "project-bound")
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(registry_rows=unknown_scope), directory)
            self.assertTrue(any("must record a scope" in error for error in coordctl.validate_task(record, POLICY)))

    def test_registry_requires_session_id_outside_reserved(self) -> None:
        missing_id = PAGE_SAGE_ROW.replace(
            "| execution | RESERVED | pending |",
            "| execution | ACTIVE | <pending> |",
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(registry_rows=missing_id), directory)
            self.assertTrue(any("requires Session ID" in error for error in coordctl.validate_task(record, POLICY)))

    def test_multiple_active_acceptance_owners_are_rejected(self) -> None:
        duplicate = "\n".join(
            [
                "| acceptance:a | acceptance | ACTIVE | acceptance-1 | separate-user-session | pagesage "
                "| poc/pdf-graphics-canvas | /tmp/review-a | execution-1 | 2026-10-20T00:00:00Z |",
                "| acceptance:b | acceptance | BLOCKED | acceptance-2 | separate-user-session | pagesage "
                "| poc/pdf-graphics-canvas | /tmp/review-b | execution-1 | 2026-10-20T00:01:00Z |",
            ],
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(task_text(registry_rows=duplicate), directory)
            self.assertTrue(any("multiple active acceptance owners" in error for error in coordctl.validate_task(record, POLICY)))

    def test_accepted_requires_terminal_acceptance_and_phases(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(
                task_text(
                    lifecycle="Accepted",
                    status="RUNTIME_PASS",
                    implementation="IMPLEMENTED",
                    evidence="RUNTIME_PASS",
                    phases=("PASS", "PASS", "NOT_APPLICABLE", "PASS"),
                    registry_rows=ACCEPTED_REGISTRY,
                    acceptance=ACCEPTED_RECORD,
                ),
                directory,
            )
            self.assertEqual([], coordctl.preflight_merge(record, POLICY))

    def test_merge_rejects_missing_phase_four_acceptance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(
                task_text(
                    lifecycle="Accepted",
                    status="RUNTIME_PASS",
                    implementation="IMPLEMENTED",
                    evidence="RUNTIME_PASS",
                    phases=("PASS", "PASS", "NOT_APPLICABLE", "NOT_STARTED"),
                    registry_rows=ACCEPTED_REGISTRY,
                    acceptance=ACCEPTED_RECORD,
                ),
                directory,
            )
            self.assertTrue(any("Phase 4 PASS" in error for error in coordctl.preflight_merge(record, POLICY)))

    def test_acceptance_rejects_same_session_scope(self) -> None:
        same_session = "\n".join(
            [
                "| execution:pdf | execution | COMPLETED | execution-1 | same-session | pagesage "
                "| poc/pdf-graphics-canvas | <PROJECT_ROOT> | not applicable | 2026-10-20T00:00:00Z |",
                "| acceptance:task | acceptance | ACTIVE | execution-1 | same-session | pagesage "
                "| poc/pdf-graphics-canvas | <PROJECT_ROOT> | execution-1 | 2026-10-20T00:10:00Z |",
            ],
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(
                task_text(
                    lifecycle="Ready for Acceptance",
                    status="RUNTIME_PASS",
                    implementation="IMPLEMENTED",
                    evidence="RUNTIME_PASS",
                    phases=("PASS", "NOT_STARTED", "NOT_STARTED", "NOT_STARTED"),
                    registry_rows=same_session,
                ),
                directory,
            )
            self.assertTrue(
                any("same session" in error for error in coordctl.preflight_acceptance(record, POLICY)),
            )

    def test_dispatch_requires_explicit_delegation_authorization(self) -> None:
        unauthorized = task_text().replace(
            "- Delegation explicitly authorized by the user: yes",
            "- Delegation explicitly authorized by the user: no",
        )
        with tempfile.TemporaryDirectory() as directory:
            record = load_temp(unauthorized, directory)
            self.assertTrue(
                any("Delegation explicitly authorized by the user" in error for error in coordctl.preflight_dispatch(record, POLICY)),
            )


class PolicyTest(unittest.TestCase):
    def test_policy_has_no_codex_transport_or_model_routing(self) -> None:
        self.assertNotIn("model_routing", POLICY)
        self.assertNotIn("codex_queue", POLICY["continuation_policy"]["same_session_transports"])
        self.assertEqual(["same-session", "delegated-subagent", "separate-user-session", "review-only"], POLICY["session_scopes"])

    def test_lifecycle_transitions_are_closed(self) -> None:
        self.assertEqual(
            [],
            [
                name
                for name, targets in POLICY["allowed_lifecycle_transitions"].items()
                if not set(targets) <= set(POLICY["task_lifecycles"])
            ],
        )


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
