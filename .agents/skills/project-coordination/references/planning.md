# Coordinated Planning

Create a plan with `assets/plan-template.md` when the intended outcome spans multiple executable tasks, repositories, release stages, or unresolved decisions. Do not create a plan merely to restate one task.

A plan owns direction, decomposition, sequencing, and completion conditions. It does not own live task status or execution evidence. Keep those in `docs/PROJECT_TASKS.md` and `docs/tasks/`.

Before making a plan active:

1. Ground the current state in decisions, contracts, code, incidents, or validation evidence.
2. State outcomes and non-goals so later task sessions cannot silently expand scope.
3. Apply the Task Granularity Gate before dividing the outcome into workstreams or Tasks. Keep stages that share one
   delivery objective and final acceptance/merge unit inside one Task.
   For a large module, model candidate vertical capability stages in the Plan first. Promote a stage to a Task only
   after it independently passes the Task Granularity Gate. Keep horizontal persistence/domain/API/test layers together
   unless a concrete repository, owner, dependency, release, rollback, or acceptance boundary requires a split.
4. Split only at a real independent implementation, acceptance, merge, rollback, release, hard-dependency, ownership,
   or security-approval boundary. A repository or owner difference is a split signal only when it also provides a safe
   independent merge point.
5. Run the consolidation check: when every candidate Task must finish before any one can merge safely, use one Task
   with internal implementation stages, review packets, and Contract Closure Matrix rows.
6. Divide genuinely independent work into owner-aligned workstreams with explicit hard and soft dependencies.
7. Identify decisions and external inputs that must resolve before dispatch.
8. Define cross-workstream validation and release conditions.
9. Create task documents only when a workstream is executable; link them from the plan and task index. Assign branches,
   sessions, and worktrees only after Task boundaries are fixed.

Use a plan by default for `complex` multi-stage work. Use one for `standard` work when more than one task or component needs sequencing. Skip it for `compact` work unless the user explicitly needs a roadmap.

Mark a plan `Completed` only after its required tasks are accepted and its completion conditions are independently checked. Mark it `Superseded` rather than rewriting historical direction after a replacement decision.
