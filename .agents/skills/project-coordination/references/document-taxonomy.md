# Document Taxonomy

Use `docs/PROJECT_TASKS.md` as a light index, not as the full task record. Each row contains only the task link, status, current gate, owner/branch, and one-line scope.

Create these directories only when their document type is needed:

| Path | Purpose |
| --- | --- |
| `docs/tasks/` | Executable work with scope, dependencies, validation, and an execution record |
| `docs/decisions/` | Accepted or proposed durable product and architecture decisions |
| `docs/plans/` | Direction, sequencing, and multi-stage planning; create with `assets/plan-template.md` |
| `docs/guides/` | Reusable development, integration, operation, or troubleshooting guidance |

Do not create new `docs/prompts/` files. Generate handoff prompts from the canonical task document in the current conversation. Treat an existing `docs/prompts/` directory as historical archive only.

Use `docs/fixtures/` only for reusable protocol examples or validation inputs when the project has a real need. It is not a workflow document category.

Create a component-level `docs/PROJECT_TASKS.md` lazily when an independent Git repository owns executable tasks. Keep the root index as the cross-component entry point and link to the owning component record instead of duplicating its body.

The task document is the sole canonical source for scope, gates and reconciled task state. Per-session execution and
acceptance records live at assigned paths under `docs/evidence/<task-id>/` and are linked from the canonical task after
handoff, following `references/session-monitoring.md`. They contain evidence, not a competing task contract or prompt.
Use `assets/decision-template.md` for durable decisions, `assets/task-template.md` for executable work,
`assets/execution-record-template.md` for implementation evidence, and `assets/acceptance-record-template.md` for
independent acceptance. Do not add generic contract or guide templates: their useful structure depends on the target
project's stack and audience.
