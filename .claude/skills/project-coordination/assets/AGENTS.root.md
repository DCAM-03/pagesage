# Project Instructions

## Coordination

- Use the installed `workstream-triage` skill before answering status, remaining-work, next-wave, continue, prioritization, or release questions.
- Use the installed `project-coordination` skill for planning, cross-component task dispatch, dependency sequencing, acceptance, and release readiness.
- Use the `validation-harness` skill before non-trivial implementation, when proving a fix, and for runtime or device smoke. Match completion claims to the recorded evidence depth.
- For tracked or handed-off work, keep coordination, assigned execution, and independent acceptance roles distinct. Reuse assigned slots under the coordination Skill's session lifecycle; tracking does not require a new chat.
- Treat the installed workflow profile as a project default. Select and record an effective task profile before dispatching; raise or reduce it only from discovered task facts.
- Treat `docs/tasks/README.md` and `docs/implementation-status.md` as the task index. Use `docs/tasks/` for executable tracked work.
- Keep accepted decisions in `docs/decisions/`, plans in `docs/plans/`, and reusable guidance in `docs/guides/` when those directories are needed.
- Treat each task document as the canonical source for scope, gates and reconciled state; link separately owned session evidence through the coordination Skill's file-writer protocol. Generate handoff prompts only in the current conversation; do not create prompt documents.
- Use the installed `code-quality-audit` skill at the task's declared quality gate. Treat scanner findings as review candidates, not proof of defects.
- Record both `Implementation State` and `Validation Evidence` for every non-trivial task, bug, or smoke. Only `IMPLEMENTED + RUNTIME_PASS` or `IMPLEMENTED + E2E_PASS` is product completion; mocks, static checks, documentation, stubs, builds, and typechecks are not substitutes.
- Do not dispatch downstream work before its hard prerequisite is accepted.
- Before a cross-session task, confirm ownership, dependency gates, target Git root, allowed workspace root, owner, branch, base, worktree, and external dependencies. A discovered same-name checkout is not authorization to write there.
- Read the target and parent `AGENTS.md` and confirm the target Git root lies in the current session's allowed workspace root before writing. If the expected path does not exist, stop and request explicit directory authorization; do not search for alternatives.
- Use only the named focused validation matrix in the task document for final acceptance. Do not use wildcard selectors, unscoped module tests, `pnpm test`, no-argument Vitest, or full-repository aggregation unless the coordinator explicitly approves the complete impact matrix in that task.
- During independent acceptance, derive a Contract Closure Matrix from the actual diff, ownership, and dependency tracing. Do not accept the execution session's status, checked criteria, or test summary as authority. Every production consumer and official runtime/build/packaging entry point must be `VERIFIED` or evidence-backed `NOT_AFFECTED`; any `BLOCKED` row prevents acceptance or merge. Use static tracing first and only the smallest missing named runtime gates; closure review does not authorize broad aggregate testing.
- For UI structure, require route/component/container/order/visibility/exclusions plus target-container positive and excluded-sibling negative evidence. For migrations or authorization with elevated authority, require exact least-privileged runtime identity and focused consumer/capability evidence. Validate the migration principal before `migrate()` or equivalent and prove rejected principals leave migration history/schema unchanged. Allow owner-backed persistence only as a documented one-time fresh-install exception with empty-database, explicit-input, sole-caller, atomicity, trigger-exclusion, and ordinary-role-restoration evidence.
- For release artifacts, record the reviewed source revision, explicit build inputs, artifact hash, platform targets, installed smoke, and rollback path. A failed artifact gate does not authorize unrelated product or database changes.
- Do not modify an unknown dirty worktree or commit without explicit authorization.

## Instruction And Command Policy

- Keep project knowledge and engineering constraints in `AGENTS.md` or the nearest child instruction file.
- Keep reusable workflows in installed skills.

## Local Instructions

Read the nearest child `AGENTS.md` before modifying a component. Add project-specific ownership, commands, product constraints, and safety invariants here or in child instruction files; do not duplicate the complete coordination workflow.
