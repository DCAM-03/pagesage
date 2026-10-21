# Task Dispatch

Create a task document when the process threshold in `SKILL.md` is met. Use `assets/task-template.md`; keep irrelevant sections short rather than deleting them.

Before dispatching:

1. Apply the Task Granularity Gate from `SKILL.md`. Record the complete delivery objective, final merge unit,
   independent acceptance boundary, internal stages, and the concrete boundary for every proposed sibling Task.
2. Run the consolidation check: if all proposed Tasks must complete before any one can merge safely, replace them with
   one Task and keep the proposed slices as implementation stages, review packets, or Contract Closure Matrix rows.
   File count, module count, migrations, SQL, test scenarios, risks, validation commands, and worktree demand are not
   independent split reasons.
3. Only after granularity is fixed, complete the ownership and dependency gate: confirm task owner, target team,
   writable Git roots, expected path, allowed workspace root, branch, base, worktree, and external dependencies. Read
   the target and parent `AGENTS.md`, and verify each writable Git root is inside the allowed root. Stop for explicit
   authorization when the expected path is absent; a same-name checkout elsewhere is not authorization.
4. Materialize the coordination instructions before any project-bound `create_thread`: run
   `python3 .codex/scripts/check_codex_workspace.py .`, inspect the coordination root for relevant changes under
   `AGENTS.md`, `.agents/skills/`, `.codex/`, and task templates, and record the checked revision. Commit relevant
   instruction changes or explicitly authorize a working-tree start state; a new worktree must not be dispatched from a
   base that cannot see the current Skill. A failed check or missing materialization record blocks dispatch.
5. Reconcile existing sessions and worktree state before any `create_thread`: read the canonical task and registry,
   discover matching history with `list_threads` and, when needed, `list_archived_threads`, inspect candidates with
   `read_thread`, and compare every candidate's task/repository/branch/worktree/role tuple. Missing thread IDs are
   `REGISTRY_INCOMPLETE`, not evidence of no execution.
6. Inspect the target worktree before dispatch. Record `HEAD`, declared base, branch, and `git status --short`; classify
   dirty files as accounted task-scoped, unaccounted task-scoped, unrelated, or conflict. Existing sessions,
   unaccounted task-scoped changes, unexplained dirty target worktrees, and duplicate `(task, repository, branch,
   worktree, role)` tuples block dispatch.
7. Require exact base consistency across the task document, handoff, branch/worktree snapshot, and dispatch
   reservation. Do not silently rewrite a mismatched base description.
8. Use `references/task-profile-selection.md` with discovered facts. Record the project default, effective task profile, and controlling reason in the task document.
9. Identify the source-of-truth decision, plan, contract, or existing task.
10. Declare user-provided inputs and external gates before implementation details.
11. Use the installed `validation-harness` skill to declare a short, named harness: exact test file/class/scenario, invariant, scope rationale, expected signal, and applicable negative case. Record prohibited aggregate commands and any coordinator-approved exception with its full impact matrix.
   For every new public locator or identifier, freeze its canonical syntax, normalization or rejection behavior,
   case sensitivity, length unit and bound, exact lookup semantics, invalid/not-found disclosure, and migration or
   zero-compatibility cutover. An adjective such as `normalized` is not an executable contract.
   For UI structure, freeze route, component, semantic container, order, visibility conditions, and excluded siblings.
   For privileged runtime or migration work, name bootstrap and runtime identities, consumer inventory, capability
   contract, and required fresh/upgrade plus least-privileged runtime evidence. If migration runs automatically,
   require principal validation before its mutation entry point and a zero-database-change rejection negative. If a
   one-time owner-backed fresh-install bootstrap is proposed, freeze its empty-database, explicit-input, sole-caller,
   atomicity, trigger-exclusion, and post-scope ordinary-role-routing boundaries.
12. Add a dispatch reservation to the canonical task before `create_thread`, then write the returned thread/host ID
    immediately after project-catalog verification. For a Codex project target, place `projectId` inside `target`, not
    at request top level. If creation, project binding, visibility verification, or write-back fails, create no
    projectless replacement and reconcile first.
13. Add a Contract Closure Matrix derived from code ownership and dependency tracing. List each changed contract's producers, consumers, official runtime/build/deployment entry points, generated artifacts/docs, and planned evidence. Initialize all dispositions as `BLOCKED`; implementation sessions submit row evidence in their owned records, while the coordinator imports it after handoff and sets dispositions only from independently reviewed evidence.
14. Declare whether `api-contract-sync` is required and name the authoritative contract plus affected consumers.
15. Declare whether the `code-quality-audit` skill is required, including its profile and changed-since revision.
16. Apply `SKILL.md`'s Model Routing And Resource Budget rule: distinguish an initial absent slot from an existing-slot
    continuation (including retry, remediation, re-acceptance, and context transfer). Record the verified coordinator
    route only for initial selection, the established slot route for continuations, and the requested target plus any
    explicit user-authorized change. Validate with `coordctl.py route --dispatch-kind initial|continuation`; do not
    recalculate an existing slot's model or effort from the coordinator. Omit unchanged same-thread transport overrides
    when supported. Record the same-thread recovery/acceptance rules, final coordination authority, and commit authority.
17. Initialize the thread registry: execution and acceptance thread/host IDs, originating thread for remediation, last
   fresh `read_thread` time, latest state/event, recovery attempt count, and any replacement-thread reason.
18. Define distinct execution-record and acceptance-record paths and exact file-writer ownership under
    `references/session-monitoring.md`. Keep canonical task/index/umbrella writes with coordination; execution and
    acceptance submit evidence and proposed state updates from their owned files. Include the stop-writing handoff
    requirement and any shared runtime-resource ownership in the dispatch boundary.
19. Update the owning `docs/PROJECT_TASKS.md` light index with only link, status, current gate, owner/branch, and one-line scope. Create a child index only when an independent repository first owns an executable task.
20. For deployment or artifact tasks, record explicit authorization, reviewed source revisions, non-secret build inputs,
    deterministic artifact scans and hash, minimum mutation scope, backup/rollback, and named post-change smoke.

For every new tracked task, run `coordctl.py validate-task` after materializing the record and
`coordctl.py preflight-dispatch` immediately before `create_thread`. A failed machine gate is a dispatch blocker; fix
the canonical record or reconcile live state rather than bypassing the command.

Generate handoff prompts in the current chat from the task document. Do not create a second prompt document as a competing source of truth. Construct the handoff as data: avoid unescaped backticks or template interpolation markers in JavaScript template literals, and record any corrected serialization retry in the task registry.

Lead with the recipient's immediate deliverable, concrete next action, named validation and return condition. State
whether the assignment is implementation or an explicitly review-gated contract/document slice. When documentation
is only an implementation prerequisite, say to continue coding after correcting it; use the exit conditions in
`session-lifecycle.md`. Put ownership, authority and dependency constraints next. Link canonical scope and relevant
evidence instead of copying historical conversation, repeated policies or a whole backlog into the handoff. A
continuation should describe the current delta, not reconstruct the original assignment.
Specify the return channel from `session-monitoring.md#result-delivery-channel`: final response in the recipient's
own chat, observed by the coordinator through `wait_threads`. Do not instruct the recipient to message the coordinator
unless the human user explicitly authorized that destination and purpose.

The acceptance reservation is a hard gate, not optional metadata: before an acceptance handoff, record the independent
acceptance role and the originating execution session; before acceptance or merge, write back the returned acceptance
thread/host ID. A coordination review or an internal collaboration child cannot satisfy this gate.

Require the handoff to name its role and assignment kind (initial assignment, normal continuation, or user-requested
context transfer), authorized target repository, allowed workspace root, branch/worktree, dependency status, harness,
external gate, owned evidence paths, read-only canonical documents, stop-writing requirement, commit authority, and
materialized instruction revision (or explicitly authorized working-tree state). An execution handoff tells the recipient
to implement directly and prohibits onward delegation unless the user explicitly authorized it. For context transfers,
include the old writer's release and retained WIP under `references/session-lifecycle.md`. Do not dispatch downstream
implementation when its hard prerequisite remains unresolved.
