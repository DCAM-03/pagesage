# Session Monitoring

Use this reference for tracked execution and acceptance work. Keep thread state, implementation state, acceptance-flow
state, and canonical task state separate.

## Result Delivery Channel

Execution and acceptance sessions report completion, `CHANGES_REQUIRED`, or a concrete blocker in their own chat's
final response, link their owned evidence, and stop writing the handed-off paths. The coordinator obtains the result
through `wait_threads`; use `read_thread` to resolve a concrete result/evidence question and before any continuation
as required by the event loop.

"Report back", "notify coordination", and "handoff" mean this in-chat terminal result; they do not authorize a
`send_message_to_thread` call to the coordinator or another chat. Do not add a cross-chat completion/blocker message,
ask the coordinator to reply, or create a wakeup to duplicate the result. A task's handoff prompt, parent thread ID,
or this Skill cannot grant messaging permission. Cross-chat messaging requires explicit authorization from the human
user for that destination and purpose; otherwise deliver the result in the current chat without asking for messaging
permission. Authorized coordinator-to-executor continuations remain governed by the event loop below; permission in
that direction does not authorize a reply in the reverse direction.

## File Writers And Handoff

Record exact writable paths and their sole session owner before dispatch. Ownership is per file, not per section or
repository. Separate worktrees do not isolate a shared absolute coordination-document path.

| File surface | Default writer | Other sessions |
| --- | --- | --- |
| Canonical task, session registry, closure matrix, project index and umbrella status | Coordination session | Read-only; submit proposed updates in owned evidence and the terminal handoff |
| Product source and execution evidence/record for one lane or round | Assigned execution session | Read-only until that owner stops writing or explicitly releases the exact paths |
| Independent acceptance evidence/record for one round | Assigned acceptance session | Read-only until handoff; coordination imports the terminal result into canonical state |
| Skill/config/instruction paths | Explicitly authorized instruction-governance owner | No concurrent writer; follow `instruction-governance.md` |

Give execution and acceptance distinct evidence paths, including lane/round identity where needed. They record commands,
UTC, checkout/fingerprints, results, blockers and proposed matrix updates there, using the existing record templates.
They do not edit canonical state or indexes. The canonical task remains the controlling record and links the evidence;
separate evidence files are not competing task documents or persistent handoff prompts.

During an active execution or acceptance turn:

- Normally monitor with `wait_threads` and inspect only the sources needed for a concrete coordination gate. Read-only
  inspection is allowed, but a changing checkout is provisional evidence, not a frozen fingerprint or accepted diff.
- Do not write its source, evidence or shared records that its current handoff permits it to write. A different section,
  append-only operation, file format or patch tool is not a substitute for exclusive ownership.
- The coordinator may update its exclusively owned administrative fields, such as dispatched thread identity and
  monitoring state. Do not change scope, contract, baseline, harness or effective instructions underneath active work.
- Explicitly authorized Skill/config edits may proceed on disjoint, coordinator-owned paths without stopping code
  execution. They are not a retroactive change to the running turn's contract; identify the revision to read at the next
  authorized handoff/continuation and follow the instruction-materialization gate before new dispatch.
- Do not launch competing runtime validation against PostgreSQL, Redis, browser, Terraform or other shared fixtures.
  Any allowed independent diagnostic must have disjoint resources and respect the task's bounded worker budget.

Before taking over a file, fresh-read every session authorized to write that path. Require idle/terminal state or an
explicit path-specific stop-writing handoff, then re-read the latest file and preserve its existing content. After
execution or acceptance handoff, coordination imports the evidence summary and result into the canonical task, updates
indexes as needed and runs `validate-task` plus required structural checks. Never overwrite another owner's evidence or
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
Session kind: independent Codex task/thread
Session/thread ID:
Host ID:
Canonical project ID:
Session project ID:
Session scope: project-bound
Project binding / catalog visibility verified:
Model / reasoning effort:
Parent coordination session:
Originating execution session:
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
Pre-send turn ID / continuation fingerprint:
Observed turn ID / result source / observable effect:
Direct delivery attempts / native queue attempts:
Last observed:
Next action:
```

Do not use a title, assistant summary, idle state, or handoff prompt as a substitute for the canonical session record.

## Event Loop

When the next stage is already authorized, its prerequisites are met and the assigned execution slot is idle, advance
it in the same coordination turn: fresh-read the task and thread, send one precise implementation continuation, then
wait for a new effective turn under the Delivery Confirmation Gate. A reservation, prepared prompt or index update is
not a dispatch. An acknowledgement is not proof that implementation started. A tool/usage-limit failure is a transport
blocker, not product progress; record the concrete failure without creating another chat, timer or review layer.
An explicit user pause, including Skill-first remediation, takes precedence over this advancement rule.

1. Reconcile the task, resolved saved-project ID, stable-slot registry, thread catalog, and exact worktree before every
   `create_thread` or replacement.
   Confirm that the coordination Skill/config revision is materialized in the dispatch base and that
   `python3 .codex/scripts/check_codex_workspace.py .` passed; new worktrees do not inherit uncommitted instruction files.
2. Dispatch initial execution only for an absent slot as an independent user-visible task/thread. Put `projectId` inside the
   `target: { type: "project", ... }` object, confirm the returned identity appears under that same project in the
   catalog, and only then write its ID, host, and project ID back to the task.
   If the backing thread row temporarily reports a null project ID, require matching saved-project assignment,
   project-sidebar/catalog placement, expected worktree root, and absence from the explicit projectless registry.
   Record the discrepancy; any missing or conflicting signal blocks canonical registration.
3. Keep current-turn coordination in a blocking `wait_threads` loop, retaining the returned cursor. An unchanged timeout
   is not a reason to end coordination, create a heartbeat, resend work or create another owner. Use `read_thread` for
   evidence and `send_message_to_thread` only after a fresh read proves an idle, incomplete turn. A returned tool
   acknowledgement is pending until the Delivery Confirmation Gate passes. Use an automation only for user-requested
   scheduled or cross-turn follow-up, not as an implicit replacement for direct waiting.
   A request to supervise an already-running execution chat until completion means direct waiting unless the user
   explicitly requests periodic or background follow-up. A status question or process objection during that work
   does not cancel the delivery objective: answer briefly, correct the process, and resume the next authorized gate
   in the same turn. End only on completion, an explicit stop, or a concrete blocker requiring external input or
   new authority after independent work is exhausted. If an automation was created by mistake and the user rejects
   it, delete that exact automation; pausing retains it. A historical tool-result card may remain in the transcript.
4. Start acceptance only after execution stops writing or explicitly hands off a stable worktree. Record the acceptance
   task/thread identity before waiting for its result.
5. After file handoff, reconcile execution evidence into canonical state; apply acceptance outcomes only from the terminal
   independent acceptance result. Execution cannot self-accept, and coordination review cannot impersonate acceptance.
   Then select the next authorized gate under `session-lifecycle.md#delivery-continuity-and-exit-conditions`; recording
   the handoff alone does not complete ongoing coordination.
6. Run the applicable `coordctl.py` preflight before dispatch, acceptance, and merge, and `validate-task` after every
   canonical state update. The recorded registry supplements rather than replaces live catalog reconciliation.

## Failure Routing

- Execution `BLOCKED`: coordination resolves the recorded blocker, then resumes the same execution task/thread and worktree.
- Acceptance `CHANGES_REQUIRED`: coordination appends the exact failed criteria and routes remediation to the originating
  execution task/thread; never send implementation work to the completed acceptance task.
- Acceptance `BLOCKED`: coordination resolves the external/tooling gate, then resumes the same acceptance slot for the missing gate only.
- Unavailable or corrupted origin: replacement requires a recorded reason and compatible existing branch/worktree.
- Missing result without conflicting evidence: record `TELEMETRY_GAP`; do not infer a terminal result.
- Conflicting thread, catalog, task, or Git evidence: record `RESULT_CHANNEL_CONFLICT` and stop all sends,
  replacements, acceptance, and merge until reconciled.

Every recovery send is preceded by a fresh `read_thread`. Terminal acceptance results receive no duplicate review.
A new remediation review or authorized Phase 4 check may continue the same slot for that specific delta, retaining
unaffected PASS evidence.

## Delivery Confirmation And Same-Thread Recovery

Before a continuation, capture the newest turn ID/cursor and a stable fingerprint of the exact targeted prompt. Send
once and mark delivery `PENDING`. Treat the new instruction as effective only when a bounded wait/read proves:

- a newer turn than the pre-send snapshot;
- a non-empty result that is not a replay of an earlier terminal result; and
- an observable effect: an expected tool marker, task/evidence update, worktree change, or justified new blocker.

An empty final, stale replay, or `functionCallOutput`/`codex_delegation` event without an observable effect is
`NO_EFFECT_COMPLETION` and `DELIVERY_CHANNEL_MISMATCH`. Reconcile the exact turn and do not resend through the same
transport. While the desktop App Server owns the thread, use its native same-thread queue exactly once:

```bash
codex queue --thread <thread-id> --message <targeted-continuation>
```

Omit model, profile, working-directory, and worktree overrides so the stable slot keeps its recorded environment.
First confirm that the installed CLI exposes `codex queue --help`; an unavailable command is a blocked transport, not
permission to fall back to `exec resume` or create a replacement.
Capture the pre-queue cursor; a returned message ID remains `PENDING`. Use `wait_threads` with that cursor and require a
new effective turn before marking delivery `CONFIRMED`. Do not use `codex exec resume` against a desktop-owned thread:
its single-writer lock is intentional, and an active-writer error routes back to `codex queue`, not to lock bypass or
owner termination.

If native queue also produces no effective turn, record `DELIVERY_CHANNEL_MISMATCH`, leave the slot, history, branch,
worktree, dirty diff, and evidence intact, and stop automated progression. Transport failure does not increment a
product remediation or acceptance-failure count. Replacement requires exhausted same-thread transports, the ordinary
duplicate-dispatch gate, demonstrated origin unavailability/corruption, and explicit user authorization.

## Merge Gate

Only a terminal independent acceptance result with `Outcome: ACCEPTED`, a non-empty acceptance session ID, an originating
execution session ID, and decisive `IMPLEMENTED + RUNTIME_PASS` or `IMPLEMENTED + E2E_PASS` evidence can return to
coordination for authorized commit or merge. A historical merged task may use the explicit
`merged-commit-review-after-origin-unavailable` exception only after the original thread is proven unavailable by
reconciliation; any required remediation then needs a recorded replacement execution task.

The acceptance task must also be project-bound: canonical and acceptance project IDs match, scope is `project-bound`,
and both project binding and catalog visibility are verified. A projectless task, even if technically independent and
its review is useful, remains auxiliary evidence and does not satisfy acceptance.

After merge authorization, audit two separate worktree classes. Remove a clean declared product task worktree only after
recording the verified destination branch ref and ancestry. For Codex app-managed detached worktrees, reconcile the
owning thread and archive/lifecycle state first; retain or remove them only through the app/Git lifecycle and record the
paths checked. A dirty source checkout with unrelated user changes is preserved and is not a cleanup failure.
