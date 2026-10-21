# Session Monitoring

Use this reference for tracked execution and acceptance work. Keep session state, implementation state,
acceptance-flow state, and canonical task state separate.

## Result Delivery Channel

Execution and acceptance sessions report completion, `CHANGES_REQUIRED`, or a concrete blocker in their own final
response, link their owned evidence, and stop writing the handed-off paths. The coordinator reads the result from the
delegated subagent's final report or from the user-visible session's response; use a fresh read of the task and
evidence to resolve a concrete question and before any continuation.

"Report back", "notify coordination", and "handoff" mean this in-session terminal result; they do not authorize an
extra message to another session. Do not add a cross-session completion/blocker message, ask the coordinator to reply,
or create a wakeup to duplicate the result. A task's handoff prompt, parent session ID, or this Skill cannot grant
messaging permission. Cross-session messaging requires explicit authorization from the human user for that destination
and purpose; otherwise deliver the result in the current session without asking for messaging permission. Authorized
coordinator-to-executor continuations remain governed by the event loop below; permission in that direction does not
authorize a reply in the reverse direction.

## File Writers And Handoff

Record exact writable paths and their sole session owner before dispatch. Ownership is per file, not per section or
repository. Separate worktrees do not isolate a shared absolute coordination-document path.

| File surface | Default writer | Other sessions |
| --- | --- | --- |
| Canonical task, session registry, closure matrix, project index and umbrella status | Coordination session | Read-only; submit proposed updates in owned evidence and the terminal handoff |
| Product source and execution evidence/record for one lane or round | Assigned execution session | Read-only until that owner stops writing or explicitly releases the exact paths |
| Independent acceptance evidence/record for one round | Assigned acceptance session | Read-only until handoff; coordination imports the terminal result into canonical state |
| Skill/config/instruction paths | Explicitly authorized instruction-governance owner | No concurrent writer; follow `instruction-governance.md` |

Give execution and acceptance distinct evidence paths, including lane/round identity where needed. They record
commands, UTC, checkout/fingerprints, results, blockers, and proposed matrix updates there, using the existing record
templates. They do not edit canonical state or indexes. The canonical task remains the controlling record and links
the evidence; separate evidence files are not competing task documents or persistent handoff prompts.

During an active execution or acceptance turn:

- Normally monitor by reading the task, the evidence files, and `git status`; inspect only the sources needed for a
  concrete coordination gate. A changing checkout is provisional evidence, not a frozen fingerprint or accepted diff.
- Do not write its source, evidence, or shared records that its current handoff permits it to write. A different
  section, append-only operation, file format, or patch tool is not a substitute for exclusive ownership.
- The coordinator may update its exclusively owned administrative fields, such as dispatched session identity and
  monitoring state. Do not change scope, contract, baseline, harness, or effective instructions underneath active work.
- Explicitly authorized Skill/config edits may proceed on disjoint, coordinator-owned paths without stopping code
  execution. They are not a retroactive change to the running turn's contract; identify the revision to read at the
  next authorized handoff/continuation and follow the instruction-materialization gate before new dispatch.
- Do not launch competing runtime validation against the emulator, a device, a locked database file, or another shared
  fixture. Any allowed independent diagnostic must have disjoint resources and respect the task's bounded worker
  budget.

Before taking over a file, fresh-read every session authorized to write that path. Require idle/terminal state or an
explicit path-specific stop-writing handoff, then re-read the latest file and preserve its existing content. After
execution or acceptance handoff, coordination imports the evidence summary and result into the canonical task, updates
indexes as needed, and runs `validate-task` plus required structural checks. Never overwrite another owner's evidence or
convert an execution claim into independent acceptance. A failed read or unknown writer state blocks shared-file edits.

An existing running handoff that permits execution to update the canonical task keeps that write ownership until it
releases the file. The coordinator must wait; a Skill edit does not revoke that permission mid-turn. Establish the new
file boundary on the next idle continuation rather than silently changing an active owner's contract.

## Registry

Keep one record per stable slot and update it in place. A Task has one execution slot per independently assigned lane
and one acceptance slot. Turns, retries, remediation, and re-acceptance rounds do not create slots.

```text
Task ID:
Stable slot: execution:<lane> | acceptance:<task>
Turn / round:
Role: execution | acceptance
Session kind: same-session | delegated-subagent | separate-user-session | review-only
Session ID: <agent ID, conversation handle, or user-provided label>
Repository / branch / worktree:
Dispatch base:
Coordination instruction revision / materialization check:
Handoff serialization checked:
Task status:
Implementation State:
Validation Evidence:
Validation phase / result:
Recovery classification:
Delivery state / method:
Pre-send snapshot / continuation fingerprint:
Observed effect / result source:
Direct delivery attempts:
Last observed:
Next action:
```

Do not use a title, assistant summary, idle state, or handoff prompt as a substitute for the canonical session record.

## Event Loop

When the next stage is already authorized, its prerequisites are met, and the assigned execution slot is idle, advance
it in the same coordination turn: fresh-read the task and evidence, send one precise implementation continuation, then
wait for independent execution evidence under the Delivery Confirmation Gate. A reservation, prepared prompt, or index
update is not a dispatch. An acknowledgement is not proof that implementation started. A tool/usage-limit failure is a
transport blocker, not product progress; record the concrete failure without creating another chat, timer, or review
layer. An explicit user pause, including Skill-first remediation, takes precedence over this advancement rule.

1. Reconcile the task, stable-slot registry, known sessions, and exact worktree before every delegation or
   replacement. Confirm that the coordination Skill/config revision is materialized and available to the target;
   delegated subagents and separate checkouts do not inherit uncommitted instruction files.
2. Dispatch initial execution only for an absent slot and only with explicit user authorization. Record the returned
   session identity back into the task immediately.
3. Keep current-turn coordination focused on the task's evidence and the actual repository state. An unchanged status
   is not a reason to resend work or create another owner. Send a continuation only after a fresh read proves an idle,
   incomplete turn. A returned acknowledgement is pending until the Delivery Confirmation Gate passes. Use an
   automation only for user-requested scheduled or cross-turn follow-up, not as an implicit replacement for direct
   waiting. A request to supervise an already-running execution session until completion means direct waiting unless
   the user explicitly requests periodic or background follow-up. A status question or process objection during that
   work does not cancel the delivery objective: answer briefly, correct the process, and resume the next authorized
   gate in the same turn. End only on completion, an explicit stop, or a concrete blocker requiring external input or
   new authority after independent work is exhausted.
4. Start acceptance only after execution stops writing or explicitly hands off a stable worktree. Record the acceptance
   session identity before waiting for its result.
5. After file handoff, reconcile execution evidence into canonical state; apply acceptance outcomes only from the
   terminal independent acceptance result. Execution cannot self-accept, and coordination review cannot impersonate
   acceptance. Then select the next authorized gate under
   `session-lifecycle.md#delivery-continuity-and-exit-conditions`; recording the handoff alone does not complete
   ongoing coordination.
6. Run the applicable `coordctl.py` preflight before dispatch, acceptance, and merge, and `validate-task` after every
   canonical state update. The recorded registry supplements rather than replaces live session reconciliation.

## Failure Routing

- Execution `BLOCKED`: coordination resolves the recorded blocker, then resumes the same execution session and
  worktree.
- Acceptance `CHANGES_REQUIRED`: coordination appends the exact failed criteria and routes remediation to the
  originating execution session; never send implementation work to the completed acceptance session.
- Acceptance `BLOCKED`: coordination resolves the external/tooling gate, then resumes the same acceptance slot for the
  missing gate only.
- Unavailable or corrupted origin: replacement requires a recorded reason and a compatible existing branch/worktree.
- Missing result without conflicting evidence: record `TELEMETRY_GAP`; do not infer a terminal result.
- Conflicting session, task, or Git evidence: record `RESULT_CHANNEL_CONFLICT` and stop all sends, replacements,
  acceptance, and merge until reconciled.

Every recovery continuation is preceded by a fresh read of the task, evidence, and repository. Terminal acceptance
results receive no duplicate review. A new remediation review or authorized Phase 4 check may continue the same slot
for that specific delta, retaining unaffected PASS evidence.

## Delivery Confirmation And Same-Session Recovery

Before a continuation, capture the current task state, evidence files, and a stable fingerprint of the exact targeted
prompt. Send once and mark delivery `PENDING`. Treat the new instruction as effective only when a bounded read proves:

- a new response that is not a replay of an earlier terminal result;
- independent execution evidence: a changed file, an updated execution record, or a worktree change; and
- an observable effect matching the requested gate.

An empty final, a stale replay, or a summary with no observable effect is `NO_EFFECT_COMPLETION` and
`DELIVERY_CHANNEL_MISMATCH`. Reconcile the exact turn and do not resend through the same transport. There is exactly
one same-session transport in Claude Code: one bounded continuation message (or one bounded `SendMessage` to the same
delegated agent). Do not start a second agent on the same paths to work around a silent agent.

If the bounded continuation also produces no effective turn, record `DELIVERY_CHANNEL_MISMATCH`, leave the slot,
history, branch, worktree, dirty diff, and evidence intact, and stop automated progression. Transport failure does not
increment a product remediation or acceptance-failure count. Replacement requires exhausted transports, the ordinary
duplicate-dispatch gate, demonstrated origin unavailability/corruption, and explicit user authorization.

## Merge Gate

Only a terminal independent acceptance result with `Outcome: ACCEPTED`, a non-empty acceptance session ID, an
originating execution session ID, and decisive `IMPLEMENTED + RUNTIME_PASS` or `IMPLEMENTED + E2E_PASS` evidence can
return to coordination for authorized commit or merge. A historical merged task may use the explicit
`merged-commit-review-after-origin-unavailable` exception only after the original session is proven unavailable by
reconciliation; any required remediation then needs a recorded replacement execution task.

The acceptance slot must record a scope other than `same-session`. A same-session review, even if technically
thorough, remains auxiliary evidence and does not satisfy acceptance.

After merge authorization, audit two separate worktree classes. Remove a clean declared product task worktree only
after recording the verified destination branch ref and ancestry. For app-managed detached worktrees, reconcile the
owning session and lifecycle state first; retain or remove them only through the app/Git lifecycle and record the paths
checked. A dirty source checkout with unrelated user changes is preserved and is not a cleanup failure.
