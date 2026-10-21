# Coordination State Machine

Use this reference for new tracked tasks. Historical task records remain truthful in their original schema unless they
are reopened for new work.

## Four Validation Phases

1. `1_EXECUTION_FOCUSED`: the execution task runs the named focused harness and records implementation evidence.
2. `2_INDEPENDENT_ACCEPTANCE`: a separate project-bound acceptance task derives the actual diff scope, checks the
   contract matrix, and independently verifies the decisive focused evidence. Reuse applicable evidence; rerun only
   checks needed to resolve a named material gap or risk under `validation-harness`.
3. `3_IMPACT_REGRESSION`: the same acceptance task runs only the regression lanes required by the derived impact
   matrix. Use `NOT_APPLICABLE` only with an evidence-backed no-impact reason.
4. `4_MERGE_READINESS`: after coordination materializes the accepted candidate commit, the same stable acceptance task
   independently verifies its identity, destination-ref plan, ancestry, diff equivalence, and cleanup eligibility.
   Coordination remains the only role that may perform the merge and cleanup. This phase may be `NOT_APPLICABLE` only
   when no merge is part of the task.

Phases are gates inside one canonical product Task, not reasons to create four product Tasks. The acceptance task owns
Phases 2-4 in one stable slot. Phase labels do not require separate turns, records or test runs; combine applicable
Phase 2/3 work in one review and retain unaffected PASS evidence. A further turn needs a named unresolved gate,
remediation, changed candidate identity or authorized merge-readiness check. Product acceptance follows Phase 2/3;
merge authorization remains blocked until Phase 4 PASS against the materialized candidate. When merge is outside the
authorized scope, record Phase 4 `NOT_APPLICABLE`; do not delay product acceptance waiting for commit authority.

## Machine Gates

Run the project-owned tool against every new tracked task:

```bash
python3 .agents/skills/project-coordination/scripts/coordctl.py validate-task <task.md>
python3 .agents/skills/project-coordination/scripts/coordctl.py preflight-dispatch <task.md>
python3 .agents/skills/project-coordination/scripts/coordctl.py preflight-acceptance <task.md>
python3 .agents/skills/project-coordination/scripts/coordctl.py preflight-merge <task.md>
python3 .agents/skills/project-coordination/scripts/coordctl.py verify-ref \
  --repo <git-root> --accepted-commit <commit> --target-branch <branch> --expected-ref <ref>
```

`workflow-policy.json` owns enum values, lifecycle transitions, active session states, stable continuation transports,
delivery states, recovery classifications, and task-size/retry limits. Do not duplicate those values in another policy
file.

`Status` is a compatibility summary mapped from `Validation Evidence`: `TOOLING_PASS` maps to `TOOLING_ONLY`, while
runtime and E2E values retain their spelling. It is not a fourth independent state axis. The authoritative fields are
`Task Lifecycle`, `Implementation State`, and `Validation Evidence`.

## Session Registry

Materialize a `RESERVED` execution slot before `create_thread`, then replace its provisional identity immediately after
project-catalog verification. Keep one row per stable slot and update its turn/round and result source in place. At most
one active row may own a `(role, repository, branch, worktree)` tuple, and a Task has at most one active acceptance slot.
A `BLOCKED` row retains ownership until coordination resolves it or the user authorizes an evidence-backed replacement.

Offline tooling validates the recorded registry; it cannot prove the live Codex catalog. The coordinator must still use
`list_threads`, optional `list_archived_threads`, and fresh `read_thread` calls and record that evidence before a
dispatch or replacement.

## Recovery Classification

- `TRANSIENT_TOOL_FAILURE`: the tool or service failed and the same thread receives at most one bounded retry after a
  fresh read.
- `DELIVERY_CHANNEL_MISMATCH`: an acknowledged continuation produced no effective new turn, only an empty/stale replay,
  or delegation output without observable effect. Try the other configured same-thread transport once, then stop.
- `TELEMETRY_GAP`: a result is temporarily absent, but catalog/task/Git evidence does not conflict. Do not invent a
  terminal result.
- `RESULT_CHANNEL_CONFLICT`: thread, task record, catalog, or worktree evidence disagrees. Stop sends, replacements,
  acceptance, and merge until reconciled.
- `ORIGIN_UNAVAILABLE`: catalog and archived reconciliation prove the origin cannot be resumed.
- `CONTEXT_CORRUPTION`: the origin is reachable but demonstrably cannot continue the recorded task safely.

Canonical task records and Git state may preserve evidence but do not impersonate a missing terminal thread result.
After the bounded same-thread transports produce no state change, stop automated retries. A technical-recovery replacement requires
`ORIGIN_UNAVAILABLE` or `CONTEXT_CORRUPTION`, exhausted transports, duplicate-dispatch reconciliation, and explicit user
authorization. User-requested clean-context transfers are separate from technical recovery and follow
`references/session-lifecycle.md`; do not fabricate a recovery classification for them.

## Delivery State

- `NOT_SENT`: no continuation was attempted for the current round.
- `PENDING`: direct send or native queue acknowledged the message, but no effective newer turn is proven.
- `CONFIRMED`: a newer turn produced a non-stale result and an observable effect.
- `CHANNEL_MISMATCH`: the transport completed without an effective newer turn.

`send_message_to_thread` and `codex_queue` each receive at most one attempt per continuation round. `codex exec resume`
is not a same-thread transport for a desktop-owned thread because it competes for the single-writer lock.

## Resource And Evidence Limits

Every task records a numeric compile/test worker cap and serialization rule before dispatch. The policy maximum is 16;
a task may select a lower cap, and a user override may lower it further. Testcontainer lanes remain serialized unless the
task records a stricter measured exception. Store long logs beneath the task's declared evidence directory and keep only
commands, results, paths, and high-signal excerpts in the task record. The policy line limit prevents operational
transcripts from becoming the canonical state store.
