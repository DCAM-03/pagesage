# Workflow Profiles

Treat the profile in `docs/PROJECT_PROFILE.md` as a project default, not a permanent task classification. Before creating or dispatching a tracked task, select its effective profile using `references/task-profile-selection.md` and record the result in the task document. Escalate when the actual risk is higher; reduce a project default only for an explicitly local-only task.

## Compact

Use for a small project, a single repository, or a small backend and frontend pair.

- Make local changes directly when the owner, scope, and validation are obvious.
- Create a task document only for cross-component work, a decision, a risky change, or explicit tracking.
- Skip a separate plan unless the user needs a roadmap or the work grows into multiple tasks.
- Run the `code-quality-audit` skill for risky changes or when explicitly requested.
- Use one task branch or worktree for one writable repository.
- A tracked or handed-off task uses its assigned execution session and returns to coordination for acceptance. Follow the stable-slot rules in `session-lifecycle.md`; tracking does not require a new chat.
- Keep the index concise; do not create empty plans or decision directories merely for taxonomy.

## Standard

Use when backend and frontend are independently developed or when an API contract requires sequencing.

- Record cross-component tasks in `docs/tasks/`.
- Identify the API contract owner before frontend or SDK implementation.
- Record one workspace decision per writable Git root. Use a secondary worktree only for same-repository concurrency or when a checkout must be preserved.
- Record focused build and behavior evidence in the execution record.
- Create a plan when multiple tasks or components need sequencing.
- Run a changed-file quality audit for public contracts, security boundaries, or cross-component work.
- The coordination session continues the assigned execution slot, then routes its result to independent acceptance.

## Complex

Use when several repositories, SDKs, teams, sessions, external gates, migrations, or release checks are involved.

- Build a dependency graph before dispatching parallel work.
- Create and maintain a plan for multi-stage work before dispatching its executable tasks.
- Require per-repository workspace policies and execution records; use secondary worktrees where concurrency or checkout preservation requires them.
- Distinguish raw API, SDK, browser, and operational validation lanes.
- Audit accepted decisions for unfinished implementation stages before status or release conclusions.
- Treat credentials, third-party setup, DNS/TLS, callback URLs, and manual approvals as explicit external gates.
- Reuse assigned execution slots for implementation; component count and process profile do not require additional chats. Keep coordination and independent acceptance roles distinct.
- Run changed-file quality audits by default. Use a full baseline only for a dedicated hardening workstream.

The required-artifact matrix, conservative-baseline rule, and typical decisions are defined in `references/task-profile-selection.md`. Do not rely on repository size alone when choosing task process.
