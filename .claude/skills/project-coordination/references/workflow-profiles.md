# Workflow Profiles

Treat `standard` as the PageSage project default, not a permanent task classification. Before creating or dispatching
a tracked task, select its effective profile using `references/task-profile-selection.md` and record the result in the
task document. Escalate when the actual risk is higher; reduce the default only for an explicitly local-only task.

PageSage is one Flutter repository with one writer per branch in the normal case. "Multiple components" here means
multiple layers (domain, data, application, presentation, renderer bridge) — not multiple repositories.

## Compact

Use for an explicitly local-only change.

- Make local changes directly when the owner, scope, and validation are obvious.
- Create a task document only for cross-layer work, a decision, a risky change, or explicit tracking.
- Skip a separate plan unless the user needs a roadmap or the work grows into multiple tasks.
- Run the `code-quality-audit` skill for risky changes or when explicitly requested.
- One task branch; a worktree is not needed unless a long-running manual device check must coexist with coding.
- A tracked or handed-off task uses its assigned execution session and returns to coordination for acceptance. Follow
  the stable-slot rules in `session-lifecycle.md`; tracking does not require delegation.
- Keep the index concise; do not create empty plans or decision directories merely for taxonomy.

## Standard

Use for PageSage's normal work: a change that crosses layers, touches persistence, or needs a declared contract.

- Record the task in `docs/tasks/` and link it from `docs/tasks/README.md` or `docs/implementation-status.md`.
- Identify the owning layer and freeze the contract (locator format, bridge message, schema, export format) before
  dependent implementation.
- Record focused build and behavior evidence in the execution record.
- Create a plan when multiple tasks or stages need sequencing.
- Run a changed-file quality audit (`flutter-dart` profile) for persistence, privacy, renderer-bridge, or cross-layer
  work.
- The coordination session continues the assigned execution slot, then routes its result to independent acceptance.

## Complex

Use when external gates (devices, signing, store accounts), a release with platform packaging, long parallel sessions,
or a cross-surface migration are involved.

- Build a dependency graph before parallelizing.
- Create and maintain a plan for multi-stage work before dispatching its executable tasks.
- Distinguish tooling, runtime, and end-to-end validation lanes explicitly.
- Audit accepted decisions and `AGENTS.md` constraints for unfinished stages before status or release conclusions.
- Treat signing keys, store accounts, device availability, and manual approvals as explicit external gates.
- Reuse assigned execution slots; layer count and process profile do not require additional chats. Keep coordination
  and independent acceptance roles distinct.
- Run changed-file quality audits by default. Use a full baseline only for a dedicated hardening workstream.

The required-artifact matrix, conservative-baseline rule, and typical decisions are defined in
`references/task-profile-selection.md`. Do not rely on repository size alone when choosing task process.
