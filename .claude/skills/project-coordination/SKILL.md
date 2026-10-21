---
name: project-coordination
description: Coordinate PageSage work across reader, database, renderer bridge, AI, and platform components. Use for multi-stage planning, cross-component task dispatch, execution-session handoff, dependency sequencing, independent acceptance, release readiness, or acting on a workstream established by workstream-triage. Do not use for a small local implementation or a quick read-only question that has no coordination impact.
---

# Project Coordination

Read `AGENTS.md`, `docs/00-overview.md`, `docs/05-technical-architecture.md`, and only the project documents required
by the requested mode. Reuse instructions already read in the current context; reread only changed guidance or missing
context. There is no generated project profile: derive facts from `docs/`, `pubspec.yaml`, and the code.

## Select A Mode

| User intent | Read |
| --- | --- |
| Remaining work, next wave, continue, priority, schedule | Use the `workstream-triage` skill first; return here only when planning or dispatch is requested |
| Create or revise a multi-stage plan | `references/planning.md` and `references/document-taxonomy.md` |
| Create a handoff or split reader/database/renderer/AI work | `references/task-dispatch.md` and `references/dependency-gates.md` |
| Coordinate a task across sessions, start implementation, or return for acceptance | `references/session-lifecycle.md`, `references/session-monitoring.md`, and `references/acceptance-loop.md` |
| Validate task state, phase order, recovery, dispatch, acceptance, or merge readiness | `references/coordination-state-machine.md` |
| Choose tests, prove a fix, run runtime or device smoke, or classify evidence | Use the `validation-harness` skill; return here for independent acceptance |
| Assign branches or worktrees, or audit formatter changes | `references/worktree-policy.md` |
| Validate, accept, or close work | `references/validation-and-acceptance.md` and `references/contract-closure.md` |
| Decide release readiness | `references/release-readiness.md` |
| Create or classify project documentation | `references/document-taxonomy.md` |
| Select or revise a task's process level | `references/workflow-profiles.md` and `references/task-profile-selection.md` |
| Consolidate `AGENTS.md`, `CLAUDE.md`, Skills, or MCP config | `references/instruction-governance.md` |

## Session Role Gate

Apply the [request intent and change boundary](references/session-lifecycle.md#request-intent-and-change-boundary)
before product writes, including when a review uncovers a cross-component defect. Existing implementation authority
continues within its assigned scope; a comparison or process-review request does not silently transfer execution
ownership.

Resolve the current role from the user's request and the task's ownership before dispatching. Task complexity requires
tracked scope and evidence; it does not turn an execution session into a coordinator. A session handed implementation
work reads the existing task and implements its assigned scope itself. It must not spawn another agent, hand the
assignment to an old session, or delegate implementation unless the user explicitly authorizes delegation.

When the user asks for a clean chat to continue implementation, preserve the execution role. Use the ownership-transfer
procedure in `references/session-lifecycle.md`; do not label the replacement a coordinator merely because the task is
cross-component. Replace a coordinator only when the requested continuation is coordination. Every handoff names its
role and whether it is an initial assignment, normal continuation, or user-requested context transfer.

For implementation continuations, apply the
[delivery continuity and exit conditions](references/session-lifecycle.md#delivery-continuity-and-exit-conditions).
For execution and acceptance handoffs, follow the
[result delivery channel](references/session-monitoring.md#result-delivery-channel); reporting a result does not
authorize cross-session messaging.

## Task Granularity Gate

Determine task granularity before assigning owners, branches, sessions, or worktrees.

- Default to one Task for one complete delivery objective and one final acceptance/merge unit. A final merge unit may
  be one repository merge or an explicitly coordinated set of repository merges that cannot be accepted safely in
  isolation.
- Split only when each resulting Task has a real independent boundary: it can be implemented, accepted, merged, and
  rolled back or released safely; it must land first to unblock a hard-dependent downstream Task; it has an independent
  repository/owner boundary with a safe merge point; or it requires a separate release, store, security-approval, or rollback
  control.
- Different repositories, owners, or concurrent writers are split signals, not automatic proof. If all candidate Tasks
  must finish before any one can merge safely, consolidate them into one Task with internal stages or review packets.
- Multiple files, packages, modules, migrations, test scenarios, risk categories, validation commands, or Contract
  Closure Matrix rows do not justify separate Tasks. A larger test matrix does not imply more Tasks.
- Size or implementation complexity may require a Plan, internal stages, or review packets, but does not by itself
  require multiple Tasks. For a large module, prefer independently usable vertical capability slices where a real
  acceptance and merge boundary exists. Do not split persistence, domain, application, presentation, or tests into
  separate Tasks unless each has its own safe acceptance and merge boundary.
- Worktrees and sessions are execution topology. Allocate them only after granularity is decided; never create a Task
  merely to justify another worktree or session.

## Resource Budget

PageSage is a single Flutter repository; most work does not need parallel writers.

- Bound every compile, analyze, and test launch explicitly: `flutter test --concurrency=<n>`, and serialize broad
  suites when memory impact is uncertain. The policy maximum is 16 workers.
- Do not run two `flutter test`, `flutter build`, or Gradle sessions against the same `build/` directory concurrently.
  A worktree exists mainly to isolate a long-running manual device verification from a coding session.
- Record the selected limit and the actual command values in the task's validation harness.

## Product Maturity And Compatibility

Honor the posture declared by `AGENTS.md` and the canonical task. PageSage is pre-1.0 and the roadmap governs
compatibility: do not invent legacy aliases, dual reads/writes, fallback lookup, data translation, or deprecated
paths. Freeze the clean target contract, replace the old path directly, and require only the migrations or fixture
resets needed for structural integrity and the declared runtime evidence. Compatibility work requires an explicit
product contract; the mere presence of old code or development data is not such a contract.

## Instruction Materialization Gate

The repository working tree is the source of truth for this Skill, its references and templates, and the task
registry. An execution subagent or a separate session may start from a committed revision, so an uncommitted Skill
change is not available to it. Before every delegated dispatch:

- inspect `git status --short` and `git diff --name-only` for the relevant `AGENTS.md`, `CLAUDE.md`, `.claude/skills/`,
  `.agents/skills/`, `.codex/`, and task-template paths;
- materialize relevant instruction changes in a committed revision, or explicitly authorize a working-tree start state
  and record that exact state in the reservation; never rely on an uncommitted change that the target session cannot
  see;
- if materialization or the recorded revision is missing, block dispatch and reconcile before delegating.

The handoff must state the materialized revision (or the explicitly authorized working-tree state) that the new
session is expected to read. Historical records remain unchanged; this gate applies to new dispatches and recovery
attempts.

## Machine Gate

New tracked tasks use `workflow-policy.json`, the session registry, and the four validation phases defined in
`references/coordination-state-machine.md`. Run the matching `coordctl.py` preflight before dispatch, acceptance, and
merge; run `validate-task` after every canonical state update. The tool validates recorded state but does not replace
live session reconciliation or independent acceptance.

## Stable Session Slots

A tracked Task owns one stable execution slot per independently assigned lane and one stable acceptance slot for the
Task. Initial delegation requires an absent slot, dispatch reconciliation, and an explicit user request for delegation.
A normal retry, continuation, execution blocker recovery, remediation round, or re-acceptance stays in its existing
slot. User-requested context transfers follow `references/session-lifecycle.md` and may change the slot's session
identity after exclusive ownership is transferred. Never allow two execution slots to write the same branch/worktree,
and never allow more than one active acceptance slot to own a Task.

Advance an authorized ready stage through the [event loop](references/session-monitoring.md#event-loop): a reservation
or written handoff is not execution, and an acknowledgement is not confirmed delivery. Honor an explicit user pause;
Skill-first remediation does not resume product work automatically.

## Shared File Ownership

Follow the file-writer ownership and handoff protocol in `references/session-monitoring.md` before dispatch or edits
to shared records. The coordinator owns canonical task state and indexes; execution and acceptance own separate
evidence files. Different sections, append-only writes, or separate edits do not make concurrent writes to one file
safe. Read-only monitoring and explicitly authorized instruction edits on disjoint paths may coexist with active
execution; they do not authorize product edits or a live contract change.

## Evidence And Context Budget

Use one concise execution/acceptance record per coherent delivery stage. Canonical state links it; the index names
only the current gate. Store commands, UTC, source revisions, results, and concrete failures once. No per-command
logs, copied scanner dumps, or full manifests unless a named criterion needs them. Do not regenerate an unchanged
registry or instruction inventory on each wait; update at ownership, source, or outcome transitions.

Same-slot continuations carry only findings, required behavior, affected selectors, changed boundaries, and record
links. Refer to the established route, WIP, and permission constraints rather than copying the original assignment.
Fresh-read before sending remains required. Never narrate unchanged polls as progress.

Apply the [acceptance convergence rules](references/acceptance-loop.md#acceptance-convergence) before splitting reviews
or requesting another validation round. Preserve independent acceptance without multiplying review layers. Follow the
focus/stop rule in `references/acceptance-loop.md#acceptance-focus-and-stop-rule` for user outcomes, material risks,
and consolidated remediation; optional improvements do not create acceptance turns.

## Session Interruption And Recovery

Keep session state, implementation state, acceptance-flow state, and task state separate. A session can finish while
acceptance ends with `CHANGES_REQUIRED`, and that result must not be converted to `Accepted`. Recovery applies to both
execution and acceptance sessions, but the next owner depends on which session produced the state.

- Treat a user `continue` as recovery of the existing task graph. Read the canonical task first, then inspect the
  current repository and evidence state before deciding anything.
- If the execution session is `BLOCKED`, the coordination session owns the blocker. Resolve the missing input, hard
  dependency, path/authority issue, or transient tooling condition first; do not blindly re-delegate. When the blocker
  is cleared, re-read the same task and send one precise continuation that reuses its task, branch, worktree, and
  history. If the blocker requires user input, stop and request it.
- If an acceptance session ends with `CHANGES_REQUIRED`, the acceptance flow is complete but the task is not accepted.
  The coordination session records each failed criterion and routes the exact delta to the originating execution
  session. Do not message the completed acceptance session, create a replacement task, or discard the implementation
  history. After execution returns to `Ready for Acceptance`, reuse the same independent acceptance slot for the delta.
- If an acceptance session is `BLOCKED`, the coordination session resolves the external, tooling, authorization, or
  dependency gate and then reruns acceptance. Do not infer an implementation defect from an acceptance blocker; if the
  evidence instead identifies a product defect, record `CHANGES_REQUIRED` and route it to the originating execution
  session.
- Do not resend a terminal acceptance review. Continue that slot only for a resolved blocker, completed remediation,
  or an authorized Phase 4 candidate check; retain unaffected PASS evidence. Otherwise proceed to task closure.
- Only an idle session with an authorized unfinished gate or next stage, and no conflicting newer intervention, may
  receive one precise continuation naming that gate or stage. Every continuation must be preceded by a fresh read of
  the task, the evidence, and the changed files; an old status snapshot is never sufficient.
- A successful delegation is only `Delivery state: PENDING`. Require independent execution evidence — a changed file,
  a record update, or a worktree change — before reporting progress. Empty completion, a stale replay, or a summary
  with no observable effect is `DELIVERY_CHANNEL_MISMATCH`; do not repeat the failed transport.
- For a transient tool failure or usage-limit interruption, after the user or tool becomes available, re-read the same
  task and retry that same session once. Preserve its task, branch, worktree, and history.
- Classify incomplete or conflicting result recovery as defined in `references/coordination-state-machine.md`. A
  `TELEMETRY_GAP` does not authorize an inferred terminal result; a `RESULT_CHANNEL_CONFLICT` blocks sends,
  replacements, acceptance, and merge until the recorded sources agree.
- After the bounded same-session transports produce no state change, stop automated retries and report the blocker.
  Replacement requires exhausted transports, evidence that the origin is unavailable or corrupted, the normal
  duplicate-dispatch gate, and explicit user authorization. Reuse the compatible worktree when authorized.
- Preserve execution and acceptance histories across every recovery branch. Creating a replacement session never
  resets the task, branch, worktree, evidence, or attempt count.

### Independent Acceptance Hard Gate

For every tracked product task, acceptance is a required independent role. In Claude Code that role is satisfied by
one of the policy `session_scopes` other than `same-session`: a delegated acceptance subagent, a separate user-visible
session, or an explicitly recorded review-only session that did not write the implementation. The coordination session
may dispatch, monitor, inspect, and decide, but its own review is not an acceptance session, and a subagent that
assisted implementation cannot accept that same work.

Before `Accepted`, commit, or merge, the task record must contain a terminal acceptance result with
`Outcome: ACCEPTED`, a non-empty acceptance session ID, a non-empty originating execution session ID, and an
acceptance registry row whose `Scope` is not `same-session`. Missing, placeholder, or same-session values keep the
task at `Ready for Acceptance` and block merge.

For a historical task whose implementation is already merged, and whose original execution session is unavailable
after branch, task, and commit reconciliation, record the explicit exception
`Historical acceptance exception: merged-commit-review-after-origin-unavailable` with
`Originating execution session ID: unavailable (historical)`. This exception is valid only for read-only review of the
exact merged commit; a discovered product defect requires a separately recorded replacement execution task.

`Status` and `Task Lifecycle` are separate axes. `Status` is the evidence state and must be one of the checker-approved
values such as `DESIGN_ONLY`, `BLOCKED`, `RUNTIME_PASS`, or `E2E_PASS`; `ACCEPTED` is never a `Status` value. Workflow
progress belongs in `Task Lifecycle: Planned | Dispatched | Implementing | Ready for Acceptance | Accepted | Blocked`.
Product completion therefore requires `Task Lifecycle: Accepted` together with `Status: RUNTIME_PASS` or
`Status: E2E_PASS`, `Implementation State: IMPLEMENTED`, and the terminal independent acceptance record.

The acceptance result controls the next branch: `ACCEPTED` returns to coordination for closure and authorized merge;
`CHANGES_REQUIRED` sends an exact remediation delta to the originating execution session and never to the completed
acceptance session; `BLOCKED` returns to coordination for external/tooling resolution before a new independent
acceptance attempt. Each attempt is appended without deleting prior evidence.

When writing a delegation prompt, treat it as data. Avoid embedding unescaped backticks, template interpolation
markers, or other delimiters in a generated string. A parser error is a dispatch failure: correct the concrete
serialization error and retry the same topology at most once, and otherwise record `BLOCKED`.

## Dispatch Reconciliation Gate

Never interpret a missing session ID in a task document as proof that no session exists. Treat it as an incomplete
registry until task history, session discovery, and worktree state have been reconciled.

Before every delegation:

1. Read the canonical task, its execution/acceptance history, and the task's session registry.
2. Discover any existing session for this task, then inspect every candidate that could match the task, repository,
   branch, worktree, or role. A task-document omission is not a negative search result.
3. Verify the target Git root, branch, worktree, `HEAD`, declared dispatch base, and `git status --short`. Classify
   dirty files as accounted task-scoped changes, unaccounted task-scoped changes, unrelated changes, or a conflict.
4. Enforce one active execution owner for each `(task, repository, branch, worktree, role)` tuple. Any existing session,
   unaccounted task-scoped change, unexplained dirty target worktree, or duplicate tuple blocks new dispatch and enters
   reconciliation.
5. Require exact base consistency: the task document, handoff, branch/worktree snapshot, and dispatch reservation must
   name the same base revision. Do not repair a mismatch by silently changing the handoff description.
6. Materialize a dispatch reservation in the canonical task before delegating. After the delegation returns its
   identity, write its session ID into the same registry. If verification or write-back fails, create no further
   session and reconcile by discovery and worktree inspection first.
7. If reconciliation finds an existing incomplete execution attempt, recover that session according to the recovery
   protocol, or transfer it under the user-requested context procedure in `references/session-lifecycle.md`. Preserve
   the reason and history; a clean-context request does not require pretending the original is unavailable or
   corrupted.

The same gate applies when dispatching a replacement or a second role. Acceptance may use a separate session, but it
must not share an active execution worktree. When a duplicate session is discovered, stop sends and new dispatches
until the coordinator has recorded the conflict and selected one authoritative execution source.

## Core Protocol

1. Discover project facts from `AGENTS.md`, `docs/`, `pubspec.yaml`, and source documents. Do not require the user to
   maintain commands or repository lists in a separate form.
2. Classify the current session as coordination, execution, or acceptance. Follow `references/session-lifecycle.md`
   before changing a tracked task's stage.
3. Use the configured workflow profile as a project default — PageSage is `standard`. Before tracked work, select the
   effective task profile from discovered facts and record any raise or reduction with its reason. Reduce only an
   explicitly local-only task.
4. Apply the Task Granularity Gate and record the delivery objective, final merge unit, independent acceptance
   boundary, and any justified split before creating task records or assigning execution topology.
5. For tracked product work, keep coordination, implementation, and independent acceptance responsibilities explicit.
   Reuse the existing task and assigned execution session; an implementation handoff does not require another
   execution handoff. Explicit instruction-governance work follows `references/instruction-governance.md` and may
   remain in the coordination session when it changes no product behavior.
6. Treat external proposals, locally accepted decisions, implementation authorization, executable task documents,
   commit evidence, and validation evidence as separate facts. Verify decision owner, document source, local
   disposition, and implementation authority before using a document to dispatch work. Do not infer one fact from
   another or from directory placement.
7. After granularity is fixed, complete the ownership and dependency gate: confirm the target Git root is under the
   current session's allowed workspace root, read target and parent instructions, and record owner, branch, base,
   worktree, writable roots, and external dependencies. If an expected path is absent, stop for explicit directory
   authorization; do not search for or adopt another same-name checkout.
8. Identify hard prerequisites before dispatching downstream work. A widget must not guess an unresolved renderer
   bridge or locator contract. Dispatch only the prerequisite task; create a downstream future placeholder only on
   explicit user request, marked `DESIGN_ONLY + BLOCKED`, with no dispatch, worktree, or implementation.
9. Keep the task registry light. PageSage uses `docs/tasks/<name>.md` as the canonical task record and
   `docs/tasks/README.md` plus `docs/implementation-status.md` as the index. Do not introduce a second competing
   index; when a task index row is needed, keep it to task link, status, current gate, owner/branch, and one-line
   scope.
10. Use `assets/plan-template.md` for multi-stage direction and `assets/task-template.md` for executable work. Use
    `docs/decisions/` for decisions and `docs/guides/` for durable guidance when those directories are actually
    created. Do not duplicate live task status inside a plan or create a prompt document; generate a handoff from
    the task document in the current conversation.
11. Require the `validation-harness` skill before non-trivial implementation and when reviewing evidence. Require
    `assets/execution-record-template.md` after implementation and `assets/acceptance-record-template.md` during
    independent acceptance. For new tracked tasks, initialize the session registry and four validation phases, run
    `coordctl.py preflight-dispatch` before delegation, `preflight-acceptance` before review, and `preflight-merge`
    before merge.
12. Declare the `code-quality-audit` skill requirement during dispatch, using the `flutter-dart` profile for this
    repository. Use changed-file review according to `references/workflow-profiles.md`, and classify findings without
    treating them as proof of defects.
13. Follow the project's declared branch, worktree, and commit-authority policy. Use a separate worktree for concurrent
    writes to the same Git root or when an existing checkout must be preserved. Treat read-only dependencies as pinned
    evidence, not writable workspaces.
14. Require both state axes for every non-trivial task, bug, or smoke. `Status` records evidence; `Task Lifecycle`
    records workflow. Never use `Status: ACCEPTED`; only `Task Lifecycle: Accepted` plus `IMPLEMENTED + RUNTIME_PASS`
    or `IMPLEMENTED + E2E_PASS` can be product completion. Documentation, static inspection, formatting, mocks,
    stubs, `flutter analyze`, and builds cannot establish it.
15. Require a short, named focused validation matrix. Bare `flutter test`, `dart test`, directory-scoped aggregates,
    wildcard selectors, and full-repository aggregates are prohibited as final acceptance unless the coordinator
    explicitly records a complete impact matrix and necessity in the task. A selector that expands unexpectedly is
    exploratory evidence only; record its count/result and stop until replaced by named selectors.
16. Require a Contract Closure Matrix for tracked work. Derive changed contracts and affected surfaces from the actual
    diff, ownership, and dependency tracing rather than the implementation file list alone. Treat execution status,
    checked criteria, and test summaries as claims to verify. Every production consumer and official runtime or
    packaging entry point must be `VERIFIED` or evidence-backed `NOT_AFFECTED`; any `BLOCKED` row prevents acceptance
    or merge. Use static tracing first, then only the smallest missing named runtime gates. Do not use closure review
    to authorize broad aggregate testing.
17. Add conditional contracts before dispatch: UI structure names route, widget, semantic container, order,
    visibility, the other viewport's layout, and excluded siblings; Drift or persistence work names the schema delta,
    upgrade source, data-preservation rule, and backup/restore impact; renderer work names the locator and bridge
    message contract plus the manual validation loop.
18. Implementation sessions do not commit unless the task and user explicitly grant that authority. Coordination
    commit authority after acceptance is project-owned policy. Complete the merge/ref and detached-worktree audit in
    `references/worktree-policy.md` before closing the task. Never change remote state or overwrite an existing
    project instruction file without explicit authorization.

## Process Threshold

Work directly in the current session only when the change is local, low-risk, and has a focused validation command.
Explicit instruction-governance work may span several instruction roots in one coordination session when the user
authorizes that scope and the diff remains limited to instruction, skill, MCP configuration, and deterministic
setup/check files.

For product work, require a task record, a declared execution owner, and independent acceptance when any of these
apply:

- Multiple components or layers must change.
- A locator format, Drift schema or migration, renderer bridge protocol, privacy boundary, export format, or
  secure-storage contract changes.
- Work is handed to another session or person.
- Runtime validation needs a device, a sample book, a credential, or another external input.
- The work implements or changes an accepted decision or plan stage.

Crossing this threshold determines whether tracked scope and acceptance are required; it does not determine how many
Tasks or sessions to create. An already assigned execution session continues the implementation itself. Apply the
Session Role Gate and Task Granularity Gate before dispatch or decomposition.

## Output Requirements

For workstream status, use the `workstream-triage` result as the controlling scope. For planning, produce the canonical
plan and identify which stages are ready to become tasks. For dispatch, link the canonical task and send its current
delta to the assigned execution session under the event loop; a written prompt alone is not dispatch. For acceptance,
append an acceptance record and report implementation state, independently checked validation evidence, remaining
risks, and any blocked external gate.

Use the companion skills for validation and code audit, plus project-local capability skills for implementation or
domain-specific work. This skill coordinates those capabilities; it does not replace them.

This installed copy is project-owned. Do not synchronize it from an upstream Skill repository or replace it wholesale.
Absorb upstream improvements only after checking them against the current workspace topology and explicit user
authorization.

When establishing project instructions, adapt `assets/AGENTS.root.md` only when the corresponding `AGENTS.md` is
missing or the user explicitly requests an update. Use `assets/decision-template.md` for a new durable product or
architecture decision. Never overwrite an existing instruction or decision document implicitly.
