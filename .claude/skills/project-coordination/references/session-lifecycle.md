# Session Lifecycle

Keep coordination, execution, and independent acceptance responsibilities distinct for tracked work. These are roles
in the task lifecycle, not an instruction for every newly opened chat to create or contact another execution chat.
An untracked `compact` local-only task may implement and verify in one session.

In Claude Code there are no project-bound threads. A "session" is one of the policy `session_scopes`:

| Scope | Meaning |
| --- | --- |
| `same-session` | The current conversation. Valid for implementation and for `compact` local work; never sufficient for independent acceptance of its own write. |
| `delegated-subagent` | An `Agent` tool call. Valid for implementation and for acceptance only when the subagent did not implement the same work. |
| `separate-user-session` | Another Claude Code conversation the user opens (for example after a clean-chat handoff). |
| `review-only` | A read-only review session or subagent that never wrote the implementation. |

| Stage | Owner | Required output | Exit gate |
| --- | --- | --- | --- |
| Plan and dispatch | Coordination session | Canonical task document, dependency decision, worktree policy, validation harness, external-gate status, and a handoff prompt | Task status is `Dispatched` |
| Implement | Assigned execution session | Scoped code or documentation changes and an execution record | Task status is `Ready for Acceptance` or `Blocked` |
| Accept | Independent acceptance session; coordination finalizes | Phase 2/3 product acceptance and Phase 4 candidate review | Task is accepted, then merge-ready, or returned as `Blocked` / `Implementing` |

The coordination session owns global context: decisions, sequencing, task scope, dispatch, cross-component
reconciliation, and final task-state decisions. It may inspect code and evidence, but it must not quietly become the
feature implementation session for a tracked task.

## Request Intent And Change Boundary

Resolve the latest request against the existing assignment before writing product code:

- Comparison, diagnosis, capability inventory, design review, and process questions produce findings first. For a
  mixed request such as "look at the other implementation and see how ours should improve", establish the observed
  problem and affected producer/consumer boundary before treating a proposed solution as implementation scope.
- An explicit fix/build/continue instruction within an authorized implementation assignment proceeds through the
  necessary inspection and coding in the same turn. Do not add a universal approval step, another document, chat, or
  acceptance round merely because inspection is necessary.
- Prior authorization covers the agreed outcome and ordinary implementation choices. It does not settle a newly
  introduced configuration meaning, inheritance rule, persistence change, locator format, or privacy-policy change.
  Identify that delta and resolve it through the task's existing decision authority before implementing affected
  consumers.
- Keep the current role and writer ownership. A coordinator may inspect across components and update authorized
  instructions; the request to review or optimize a feature is not itself an execution-ownership transfer.

Keep the pre-edit assessment proportional: a short finding/impact list or a delta in the existing task is enough.
Separate defects against agreed behavior, missing capabilities, and optional improvements; only the authorized scope
becomes required implementation. When the user asks to fix the Skill and then analyze a feature, finish those outputs
and keep product writes paused; do not reinterpret the analysis as permission to implement the proposed redesign.

## Delivery Continuity And Exit Conditions

Preserve the authorized delivery objective across turns and context compaction. A status question, process
correction, or newly supplied input normally steers unfinished work rather than replacing it. An explicit stop or an
instruction to handle another prerequisite first takes precedence; do not dispatch dependent product work while that
pause applies.

For an implementation assignment, reading instructions, correcting a contract, registering tests, and updating
records are prerequisites, not an implementation handoff. Once prerequisites within the assignment are satisfied,
continue directly to the authorized code changes and named validation. A documentation-only stop is correct when
documentation is the assigned output or the handoff explicitly requires coordinator review before source edits. Never
use this rule to bypass an unresolved contract, permission, or ownership gate.

The executor delivers its assigned slice or a concrete blocker in its own final response under
`session-monitoring.md#result-delivery-channel`, after implementation/validation or exhaustion of safe independent
work respectively. The coordinator reads that result and advances the next authorized gate in the same workstream.
STOP-WRITING and a completed turn release ownership; neither means the whole delivery is complete. Do not turn routine
technical choices, another finished prerequisite, or a successful dispatch into a request for the user to authorize
the same work again. A missing external input or new authority remains a real stopping condition.

When revising this workflow, review these decision scenarios; structural validation alone does not prove behavior:

| Scenario | Required next action |
| --- | --- |
| Implementation assignment includes correcting its contract before coding | Correct it, then implement and validate; do not end on the corrected document |
| Assignment is explicitly contract-only pending coordinator freeze | Deliver the contract and stop writing; coordinator resolves the freeze before source release |
| User asks to compare another product and assess improvements | Inspect equivalent contracts and runtime consumers, then report findings and impact; preserve current role and unresolved design boundaries |
| A layout review reveals missing persisted configuration or renderer semantics | Separate the layout defect from the capability/contract delta; resolve the latter before dependent product writes |
| User asks to adjust the Skill, then inventory product problems | Edit and validate instructions, complete read-only analysis, and keep product implementation paused |
| User asks about progress or process during unfinished work | Answer and resume the next authorized gate; preserve the objective after compaction |
| Executor hands off one stage; other authorized stages remain | Coordinator reviews, then continues the appropriate existing slot; do not claim whole-task completion |
| User says to pause product work and fix the Skill first | Finish and validate the instruction changes, report the result, and keep product execution paused until the user resumes it |
| A prerequisite passes and the next implementation stage is already authorized | Apply the event loop in `session-monitoring.md`; update records and actually continue the existing execution slot |
| Acceptance evidence still applies and no material gate remains | Close the review; do not open a turn merely for another phase label or green run |

## Stable Slots

- `initial_execution`: reuse an existing suitable execution session first. Delegate only when the slot is absent,
  reconciliation passes, and the user explicitly authorizes delegation. Task complexity or a profile is not
  delegation authorization. Apply the same rule to an absent acceptance slot.
- `validation_reopen`: after `CHANGES_REQUIRED`, continue the originating execution slot with the exact remediation
  delta, then reuse the same acceptance slot from the earliest invalidated phase.
- `replacement_continuation`: replace a slot only after the bounded same-session transports are exhausted, the origin
  is proven unavailable or corrupted, the duplicate-dispatch gate passes, and the user explicitly authorizes
  replacement.
- User-requested context transfer follows the procedure below; it is not a transport-failure recovery.

Session, turn, model, branch, and worktree identities are separate. A new round creates a turn, not a slot. Two
sessions never write the same execution branch/worktree concurrently, and a Task never has concurrent acceptance
owners.

## User-Requested Context Transfer

For requests such as "open a clean chat and continue implementing", transfer execution to the requested replacement.
Do not send the work back to the old execution context or add a coordinator layer. A request to continue coordination
instead transfers the coordination role. If correcting a mistaken role assignment, record that correction explicitly.

1. Fresh-read every current writer of the transferred paths. Require idle/terminal state, verify any background tool
   processes and database locks have stopped, and preserve the latest source, dirty inventory, and execution evidence.
   If a writer is still active, arrange its bounded stop-writing handoff before allowing the replacement to edit.
2. The coordinator records the old and replacement identities, the user's reason, retained task/branch/base/worktree,
   exact writable paths, and released fixture ownership. Update the existing stable slot and retain its history; do
   not create a competing task or writer. Reuse a suitable already-created replacement chat when available. Validate
   the task, live ownership, and instruction materialization. `preflight-dispatch` governs initial delegation; do not
   reset an implementing task to Planned merely to transfer ownership to an existing chat.
3. Give the replacement a concise execution handoff: current files, accepted scope, unresolved gates, named
   validation, instruction revision, evidence ownership, and explicit prohibition on onward delegation. It reads
   task-specific evidence without importing the old conversation. The old writer is read-only and receives no further
   execution work.

This transfer does not require transport exhaustion or an unavailable/corrupted origin, and it does not authorize
resetting WIP, changing product scope, self-acceptance, commits, or merges. Retain independent acceptance. A
coordinator may become the replacement execution owner only through this explicit transfer; transfer canonical-record
ownership to another coordinator before its product writes. The replacement may report blockers and handoff results,
but cannot redispatch its implementation or launch downstream execution without explicit user authorization.

The assigned execution session reads the canonical task and current delta before editing, confirms its declared Git
root remains inside the allowed workspace root and reads target/parent instructions, works only in declared
repositories and worktrees, follows the harness, and writes its execution record to its assigned evidence path. Follow
the file-writer protocol in `session-monitoring.md`: execution hands off evidence and proposed state changes without
editing canonical state or indexes. It must not expand scope, invent unresolved contracts, dispatch downstream work,
or commit unless the task and user explicitly grant that authority. After acceptance, any coordinator commit or merge
follows the project-owned policy recorded in project instructions and the task.

The acceptance step uses one required independent acceptance role after implementation and reuses that stable slot for
any necessary acceptance or Phase 4 continuation. Phase labels do not require separate turns; use `acceptance-loop.md`
for evidence reuse and review convergence. Do not accept solely because the execution session reports success or
because the coordinator performed an equivalent review. The acceptance session independently inspects the declared
scope and worktree state, reads the execution record, verifies the required evidence, and confirms hard prerequisites
and consumer contracts are reconciled. The acceptance record must contain the acceptance session ID, originating
execution session ID, and an acceptance registry row whose `Scope` is not `same-session`. The acceptance session writes
its independent record to its assigned evidence path and hands off the reviewed files. The coordination session then
imports the terminal outcome and is the only role that finalizes canonical task state.

Recovery ownership is state-specific:

- An execution session marked `BLOCKED` routes to coordination first. Coordination resolves the recorded input,
  dependency, path/authority, or tooling gate; only then may it continue the same execution session on its existing
  task, branch, worktree, and history. A user-input blocker remains paused until the user supplies the input.
- An acceptance session ending `CHANGES_REQUIRED` has completed that review round but has not accepted the task.
  Coordination records the exact failed criteria and sends a delta handoff to the originating execution session. The
  completed acceptance session receives no follow-up implementation message; after remediation, the same acceptance
  slot runs a new review round unless its identity is recorded as unavailable or corrupted.
- An acceptance session marked `BLOCKED` routes to coordination to resolve the external, tooling, authorization, or
  dependency gate before rerunning acceptance. It is not an implementation failure unless the evidence is explicitly
  reclassified as `CHANGES_REQUIRED`.

Before starting any additional execution or acceptance session, apply the dispatch reconciliation gate. Inspect task
history and discovered session candidates, compare the `(task, repository, branch, worktree, role)` tuple, classify
worktree dirtiness, and verify the exact dispatch base. A missing session ID, unaccounted task-scoped change, or
unexplained target-worktree change blocks new dispatch until the original attempt is reconciled. Also verify that the
current coordination Skill/config revision is materialized and available to the target; an uncommitted instruction
change that a delegated subagent or separate checkout cannot see blocks dispatch. Record a dispatch reservation before
delegating and write the returned session ID immediately; a failed write-back blocks all replacement dispatch.

Before any continuation, read the canonical task and fresh-read the target session; active sessions receive no
duplicate message, and a completed round receives only the next phase/remediation round authorized by canonical state.
Treat acknowledgement as pending until the effective-turn gate in `session-monitoring.md` passes. Retry a transient
tool or usage-limit interruption at most once; stop after the bounded same-session transports produce no change.
Technical-recovery replacement requires an explicitly recorded unavailable/corrupted origin, duplicate-dispatch
reconciliation, and user authorization. User-requested context transfer instead follows the separate procedure above.

An `Accepted` task, completion claim, commit, or merge is prohibited when the task has no terminal independent
acceptance result with both session IDs. Preserve old coordinator-only reviews as historical evidence, but reopen their
task to `Blocked`/`Ready for Acceptance` until a new independent acceptance attempt is recorded. Keep `Status`
(evidence) separate from `Task Lifecycle` (workflow): `Status: ACCEPTED` is invalid; use `Task Lifecycle: Accepted`
with `Status: RUNTIME_PASS` or `Status: E2E_PASS` only after the independent acceptance gate.

When later review invalidates accepted or ready-for-acceptance evidence, reopen the canonical task without rewriting
its history. Preserve `Implementation State: IMPLEMENTED` while the behavior still exists, set
`Validation Evidence: BLOCKED`, change task status to `Blocked`, append the invalidation reason, and reset only affected
Contract Closure Matrix rows to `BLOCKED`. List the exact remaining closure items. Preserve unaffected evidence and do
not widen the new harness unless dependency tracing identifies additional affected surfaces.

A handoff prompt or reservation does not start execution. For an authorized continuation, follow the event loop and
delivery confirmation gate in `session-monitoring.md`. For user-requested delegation, report creation only after the
Agent tool returns its identity. Validate prompt serialization before sending; correct a concrete parsing error in the
same topology within the bounded retry policy.

After an `ACCEPTED` result and explicit commit authorization, follow the merge/ref and cleanup audit in
`references/worktree-policy.md`. A detached worktree `HEAD` is not proof that the destination branch moved; record and
verify the actual branch ref, ancestry, clean merge worktree, and separate product/app-managed worktree inventories.

For a `compact` local-only change, one session may implement and verify directly. Once the change becomes tracked,
cross-component, privacy- or migration-sensitive, externally gated, or handed off, reselect the effective task profile
and establish scope, execution ownership, and independent acceptance. Do not convert the execution owner into a
dispatcher merely because the task crosses that threshold.
