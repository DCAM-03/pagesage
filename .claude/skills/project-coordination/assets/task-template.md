# <Task Title>

- Date: YYYY-MM-DD
- Owner: <reader|database|renderer|ai|platform|ui|ops|coordination>
- Status: DESIGN_ONLY | CONTRACT_ONLY | STUB_ONLY | TOOLING_ONLY | RUNTIME_PASS | E2E_PASS | BLOCKED
- Task Lifecycle: Planned | Dispatched | Implementing | Ready for Acceptance | Accepted | Blocked
- Execution Work State: NOT_STARTED | ACTIVE | RELEASED
- Acceptance Work State: NOT_STARTED | ACTIVE | RELEASED
- Implementation State: DESIGN_ONLY
- Validation Evidence: UNVERIFIED
- Priority: P0 | P1 | P2
- Task Type: feature | hotfix | contract | migration | security | smoke | docs
- Tracking Plan:
- Project Default Profile: compact | standard | complex
- Effective Task Profile: compact | standard | complex
- Selection Reason / Escalation Trigger:

`Status` records evidence and never uses `ACCEPTED`. `Task Lifecycle` records workflow progress; product completion
requires `Task Lifecycle: Accepted` plus `Implementation State: IMPLEMENTED` and `Status: RUNTIME_PASS` or
`Status: E2E_PASS`.

## Granularity Decision

- Delivery objective:
- Final merge unit: `<one repository merge | coordinated per-repository merge set>`
- Independent acceptance boundary:
- Split gate satisfied: yes | no
- Internal stages / review packets kept in this Task:
- Reason a separate Task is required: `Not applicable` | `<independent boundary>`

If proposed sibling Tasks must all complete before any one can merge safely, consolidate them here as internal stages
or review packets. Allocate owners, branches, sessions, and worktrees only after this decision.

## Session Policy

- Coordination session: Creates the task, resolves dependencies, and generates the handoff prompt.
- Execution session: Reuse the assigned execution slot under the coordination Skill's session lifecycle. It reads this document and the current delta, implements the declared scope, writes its execution evidence, and does not edit canonical state/indexes or commit.
- Acceptance session: One stable, independent acceptance session owns Phases 2-4, combining applicable review gates and retaining unaffected PASS evidence. Phase labels do not require separate turns. Coordination finalizes state and performs authorized commit/merge/cleanup actions. A coordination-only review, or a subagent that implemented the work, is not acceptance.
- Required session scope: `delegated-subagent`, `separate-user-session`, or `review-only`; `same-session` is invalid for acceptance.
- Commit authority: User authorization required.

## File Writer Ownership

Use `references/session-monitoring.md` for file ownership and transfer. Assign one writer per exact file; separate
sections or append-only writes do not permit concurrent writers.

| Exact path / bounded source root | Sole writer / session slot | Other sessions |
| --- | --- | --- |
| Canonical task, project index and umbrella status: `<exact paths>` | coordination | read-only |
| Product worktree: `<declared source root>` | execution:`<lane>` | read-only until handoff |
| Execution evidence/record: `<distinct lane/round paths>` | execution:`<lane>` | read-only until handoff |
| Acceptance evidence/record: `<distinct round paths>` | acceptance:`<task>` | read-only until handoff |

- Shared runtime fixture / resource owner and serialization gate:
- Released candidate identity: repository/worktree/HEAD or dirty source fingerprint, Drift schema/migration
  fingerprint, running app/device identity, sample-book identity, configuration source:
- Stop-writing handoff: identify exact released paths and final checkout/fingerprints in the terminal result.
- Canonical write-back: coordination fresh-reads writer state and latest files, imports evidence after handoff, then validates.

## Resource Budget

- Bounded compile/test worker limit and serialization rule: maximum 16; use `flutter test --concurrency=<n>`; no two `build/` writers at once; select a lower task cap when memory impact is uncertain

## Session Registry And Recovery

- Execution session / scope: `<session ID>` / `<scope>`
- Execution session kind: delegated-subagent | separate-user-session | review-only | missing (blocks tracked execution)
- Acceptance session / scope (required before acceptance): `<session ID>` / `<scope>`
- Acceptance session kind: delegated-subagent | separate-user-session | review-only | missing (blocks acceptance)
- Acceptance outcome read from the terminal acceptance result: ACCEPTED | CHANGES_REQUIRED | BLOCKED | not started
- Accepted user outcomes / decisive completion criteria (link scope below):
- Acceptance evidence reuse / replay rationale:
- Originating execution session reused for remediation: yes | no | not applicable
- Last fresh observation before a recovery decision (UTC):
- Latest session state: active | idle-incomplete | ACCEPTED | CHANGES_REQUIRED | BLOCKED | unavailable
- Recovery classification: NONE | TRANSIENT_TOOL_FAILURE | DELIVERY_CHANNEL_MISMATCH | TELEMETRY_GAP | RESULT_CHANNEL_CONFLICT | ORIGIN_UNAVAILABLE | CONTEXT_CORRUPTION
- Recovery evidence sources reconciled: session report | canonical task | Git/worktree | evidence files
- Recovery action and stop condition:
- Retry count for the current interruption or unchanged state (maximum two):
- Recovery attempts without state change: 0
- Delivery state: NOT_SENT | PENDING | CONFIRMED | CHANNEL_MISMATCH
- Delivery method: not sent | direct
- Intended continuation fingerprint:
- Confirmed response ID:
- Confirmed independent execution evidence: yes | no
- Direct delivery attempts: 0
- Replacement session reason, when applicable:
- Execution `BLOCKED` resolution owner / gate:
- Acceptance `CHANGES_REQUIRED` remediation target: originating execution session
- Acceptance `BLOCKED` resolution owner / gate:
- Coordination instruction revision / materialization check:
- Relevant instruction files materialized in the dispatch base: yes | no
- Handoff serialization checked: yes | no

## Dispatch Reconciliation

- Delegation explicitly authorized by the user: yes | no
- Dispatch target recorded with its role and scope: yes | no
- Dispatch reservation ID / UTC:
- Session discovery sources checked: task history | evidence files | git log | session registry
- Registry status: COMPLETE | REGISTRY_INCOMPLETE | CONFLICT
- Existing session tuple(s): `<task, repository, branch, worktree, role>`
- Worktree dirty classification: CLEAN | ACCOUNTED_TASK_SCOPED | UNACCOUNTED_TASK_SCOPED | UNRELATED | CONFLICT
- Dispatch base consistency across task / handoff / branch / worktree / reservation: yes | no
- Exclusive execution ownership verified: yes | no
- New dispatch blocked reason, when applicable:

## Session Registry

Keep one row per stable slot and update its turn/round in place. A Task has one execution slot per independently assigned
lane and one acceptance slot. A `RESERVED`, `DISPATCHED`, `ACTIVE`, `IDLE_INCOMPLETE`, or `BLOCKED` row owns its
`(role, repository, branch, worktree)` tuple.

| Slot | Role | State | Session ID | Scope | Repository | Branch | Worktree | Originating execution | Last observed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| execution:<lane> | execution | RESERVED | pending | same-session |  |  |  | not applicable |  |

## Background

## User-Visible Behavior

## Goals

## Non-Goals / Stub Boundary

## Impact Scope

- Components / repositories affected:
- Users, contracts, persistence, security, or operations affected:
- Explicitly excluded surfaces:

## Contract Closure Matrix

Derive rows from code ownership, dependency tracing, and official entry points, not only from expected changed files. Initialize every coordinator disposition as `BLOCKED`. Execution submits row evidence in its owned record; coordination imports it after handoff and owns `VERIFIED` and `NOT_AFFECTED` after independent review.

| Changed contract / invariant | Producer(s) | Consumer(s) | Official runtime / build / packaging entry point | Generated artifacts / docs | Planned evidence | Implementation evidence | Coordinator disposition |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  | BLOCKED |

## Current Facts

- Verified code, runtime, incident, or prior-evidence facts:
- Assumptions still requiring a gate:

## Target Contract

- Required behavior, locator/schema, privacy, migration, or user-flow contract:
- Compatibility and failure behavior:

### Frontend Structural Contract (when applicable)

- Exact route / page and owning component:
- Target card / section / tab / menu / dialog:
- Relative order:
- Responsive / permission / state visibility conditions:
- Excluded sibling containers:

### Privileged Runtime / Migration Contract (when applicable)

- Drift schema delta and `schemaVersion`:
- Supported previous version(s) to upgrade from:
- Data-preservation rule (no clear-as-migration shortcut; forward migrations only):
- FTS index / derived data rebuild, if any:
- Backup and restore impact, including the rollback copy:
- Secure-storage keys affected and failure behavior:
- Deletion semantics: database rows removed, app copies removed, original user file preserved:
- Fresh-install and supported-upgrade paths:
- Page/device paths to re-verify after restore (progress, locators, bookmarks, annotations, search):

## Source Of Truth

- Decision / plan / contract:

## Ownership And Workspace Boundary

- Target repository / Git root:
- Target owner / layer:
- Allowed workspace root:
- Expected absolute path:
- `AGENTS.md` and the controlling docs read: yes | no
- Git-root-within-allowed-root confirmed: yes | no
- Path authorization status: AUTHORIZED | BLOCKED
- External dependencies (read-only unless explicitly writable):

Do not write until every required confirmation is `yes` and the path authorization is `AUTHORIZED`. A same-name checkout found elsewhere is not an authorized target.

## Dependency Gates

| Dependency / decision | Type: hard / soft / independent | Owner | Required evidence | Status | Downstream dispatch |
| --- | --- | --- | --- | --- | --- |

For an unresolved hard prerequisite, create and dispatch only its owner task. Create a downstream future placeholder only when the user explicitly requests it; it must be `DESIGN_ONLY + BLOCKED` and state: `Do not dispatch, create a worktree, or implement.`

## Worktree Policy

- Writable repository:
- Target owner / layer:
- Allowed workspace root:
- Source checkout:
- Worktree path:
- Base ref:
- Task branch:
- Cleanup owner:

### Starting Snapshot

- HEAD:
- Branch:
- `git status --short`:
- `git diff --name-only`:
- `git diff --stat`:

Add one entry for every writable Git root. State `Not applicable` for a single local change with no separate worktree requirement.

## Branch Policy

- Repository / Git root:
- Branch:
- Base:
- Worktree:
- Startup commands:
- Dirty-worktree handling: stop and report unexplained changes; do not adopt, discard, or overwrite them.
- Commit policy: no commit. User authorization is required for any commit.
- Merge strategy: branch-attached clean merge worktree | guarded detached fast-forward | not applicable
- Destination branch ref before merge:
- Accepted commit / expected post-merge ref:
- Destination branch ref after merge:
- Ref ancestry and equality checks:
- Merge worktree clean after merge: yes | no | not applicable
- Source checkout unrelated dirty changes preserved: yes | no | not applicable
- Product worktree cleanup owner / result:
- App-managed detached worktree audit / retained paths:

## User-Provided Inputs / External Access Gate

Write `No external inputs required` when none are needed. Otherwise record the missing input, owner, allowed interim state (`BLOCKED` or `TOOLING_ONLY`), and exact next command or flow. Do not implement against a guessed input.

## Implementation Plan

## Validation Harness

- Evidence directory: `docs/evidence/<task-id>/`
- Broad-output rule: store long analyze/test/run output in the evidence directory; keep only the command, result, and evidence path in this task.

Final acceptance must use a short, named matrix. List exact test files and test names, or manual device/desktop flows; list no wildcard or aggregate selector.

| Named command / manual flow | Exact test name or flow steps | Contract or invariant proved | Why in scope | Evidence depth | Expected signal |
| --- | --- | --- | --- | --- | --- |

- Before-change failure or expected behavior:
- Required semantic negative case (required for runtime, security, migration, deletion, or replacement work):
- Explicitly prohibited acceptance commands: bare `flutter test` / `dart test`, directory-scoped aggregates, wildcard `--plain-name` selectors, and full-repository aggregate runs.
- Approved exception: `None`. An exception requires coordinator approval here, a complete impact matrix, and why focused selectors cannot establish the required invariant.
- Broad closure, if run: command and exact limited claim. `flutter analyze`, `flutter build`, a static scan, a mock, and documentation cannot replace runtime or E2E evidence.
- Selector expansion response: allow the running process to finish; record actual test count and result as exploratory evidence; stop acceptance and replace it with a named selector before continuing.
- Deleted-test equivalence mapping (required when deleting tests): `<deleted semantic invariant> -> <new named replacement test>`.
- UI structure, when applicable: name the target-container positive assertion and the excluded-sibling and other-viewport negative assertions; whole-page text, snapshots, and successful writes do not prove placement.
- Migration / destructive data, when applicable: name fresh-install and upgrade evidence, a semantic negative case, backup/restore round-trip evidence, and deletion behavior that preserves the user's original file.

## Validation Phase State

- Current Validation Phase: NOT_STARTED | 1_EXECUTION_FOCUSED | 2_INDEPENDENT_ACCEPTANCE | 3_IMPACT_REGRESSION | 4_MERGE_READINESS | COMPLETE
- Phase 1 Result: NOT_STARTED | PASS | FAIL | BLOCKED
- Phase 1 session / attempt / evidence:
- Phase 2 Result: NOT_STARTED | PASS | FAIL | BLOCKED
- Phase 2 session / attempt / evidence:
- Phase 3 Result: NOT_STARTED | PASS | FAIL | BLOCKED | NOT_APPLICABLE
- Phase 3 impact matrix / session / evidence / N/A reason:
- Phase 4 Result: NOT_STARTED | PASS | FAIL | BLOCKED | NOT_APPLICABLE
- Phase 4 target ref / accepted commit / evidence / N/A reason:

Phase 1 belongs to execution. Phases 2-4 belong to one stable independent acceptance session; combine applicable Phase 2/3
work in one review. A further turn requires a named unresolved gate, remediation, changed candidate or authorized
merge-readiness check. Retain unaffected PASS evidence; do not replay product checks solely for Phase 4.
Product `ACCEPTED` requires Phase 2 PASS and Phase 3 PASS or evidence-backed `NOT_APPLICABLE`; merge requires Phase 4
PASS against the materialized candidate when merge is authorized and in scope. Otherwise Phase 4 is `NOT_APPLICABLE`.
Coordination alone performs authorized commit, merge, and cleanup actions.
Do not create separate product Tasks merely to represent these phases.

## Deployment / Artifact Gate (when applicable)

- Explicit user authorization and target environment:
- Reviewed source revisions and clean-worktree evidence:
- Explicit build inputs and source of truth:
- Secret-handling and redaction boundary:
- Artifact manifest, deterministic scans, and content hash:
- Minimal services / resources allowed to change:
- Pre-mutation backup and rollback path:
- Post-change named runtime / E2E smoke:

## Quality Audit

- Required: yes | no
- Skill / profile:
- Changed-since revision:
- Finding disposition required in execution record: yes | no

## Acceptance Criteria

- Product-complete claim allowed only when Implementation State is `IMPLEMENTED` and Validation Evidence is `RUNTIME_PASS` or `E2E_PASS`.
- Task index may be marked accepted/completed only after the coordination acceptance record confirms the declared runtime or E2E evidence.

## Acceptance Gate

- Required implementation state:
- Required validation evidence:
- Required named harness entries and semantic negative case:
- Contract Closure Matrix gate: every relevant production consumer and official entry point is `VERIFIED` or evidence-backed `NOT_AFFECTED`; no required row remains `BLOCKED`.
- Acceptance stop rule: close after the decisive criterion and affected closure rows pass; do not add a turn for unchanged evidence, record wording, or optional improvements.
- Coordination acceptance owner:

## Deliverables

- Canonical task document and linked per-session execution/acceptance records:
- Intended implementation or document outputs:
- Updated light index entry:

## Risks / Rollback

- Risks and residual gaps:
- Rollback or recovery action:

## Key Files

## Formatter / Generator Record

- Command:
- Timestamp:
- Before snapshot:
- After snapshot:
- Affected file count:
- Scope explanation:

## Execution Records

Execution writes its assigned evidence file using `assets/execution-record-template.md`. After stop-writing handoff,
coordination appends the canonical summary and evidence link here. Preserve prior rounds. Include exact commands and
results, named evidence, selector-expansion handling, deletion mappings, blockers, residual risk, and `Commit created: No`.

## Acceptance Records

Independent acceptance writes its assigned evidence file using `assets/acceptance-record-template.md`; coordination
imports the terminal result and evidence link here after handoff. Execution must not fill this section for its own work.
