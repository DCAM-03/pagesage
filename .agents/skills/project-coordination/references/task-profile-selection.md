# Task Profile Selection

The workflow profile in `docs/PROJECT_PROFILE.md` is the project default, not a permanent task classification. Before dispatching or creating a tracked task, select and record an effective task profile from the discovered facts.

Derive the task facts from project instructions, Git roots, accepted decisions, affected components, and required validation. Do not ask the user to classify flags or choose another profile for every task.

Use the project default as a conservative baseline. Raise it when the task needs stronger controls. Reduce it to `compact` only when the task is explicitly local-only and every compact condition is satisfied.

## Selection Rules

| Effective profile | Select when | Required artifacts |
| --- | --- | --- |
| `compact` | The task is explicitly local-only: one writable Git root, one component, focused validation, and no handoff, contract, security, migration, external gate, release, or multi-wave trigger. | Focused harness. Create a task document and use the three-session lifecycle only when the work becomes tracked or handed off. |
| `standard` | Multiple components or writable roots, handoff, public contract, security boundary, or a migration that does not meet the complex threshold. | Canonical task, execution record, assigned execution session, independent acceptance, contract owner when applicable, and focused behavior evidence. |
| `complex` | Parallel execution sessions, three or more writable roots, external gate, release scope, multi-wave delivery, or a migration spanning multiple components/repositories. | Plan, dependency graph, task records, per-root workspace policy, lane-specific evidence, independent acceptance, and changed-file audit by default. |

When several rules apply, choose the strongest effective profile. A `complex` project default remains `complex` unless the task satisfies the complete local-only rule; a standard-level trigger never silently lowers it.

## Typical Decisions

| Project default | Task facts | Effective profile | Reason |
| --- | --- | --- | --- |
| `complex` | One local documentation or styling change, one Git root, focused validation, no handoff or risk trigger | `compact` | Explicit local-only exception |
| `complex` | Public API contract across backend and frontend | `complex` | The default remains the conservative baseline |
| `compact` | Backend and frontend must synchronize a public contract | `standard` | Cross-component contract and handoff controls are required |
| `standard` | External credentials and several dependent delivery waves | `complex` | External gate and multi-wave sequencing require complex controls |
| `compact` | One repository changes an authorization boundary | `standard` | Security-sensitive tracked work requires a task, harness, execution owner, and acceptance |

## Task Record

For every tracked task, record:

```text
- Project Default Profile: compact | standard | complex
- Effective Task Profile: compact | standard | complex
- Selection Reason / Escalation Trigger: <discovered facts and controlling rule>
```

Re-run the selection when scope grows, another writable root is added, a contract becomes public, validation introduces an external gate, or the task is handed off. Update the task before dispatching new work; do not silently continue at the old profile.
