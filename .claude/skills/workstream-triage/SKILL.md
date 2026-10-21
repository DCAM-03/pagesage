---
name: workstream-triage
description: Anchor the active PageSage workstream and reconcile plans, accepted decisions, task records, validation, and commit evidence. Use before answering status, remaining-work, next-wave, continue, prioritization, parallelization, schedule, or release-readiness requests, especially when supporting validation or operations work may have interrupted the primary workstream.
---

# Workstream Triage

Prevent scope drift and stale backlog from controlling the next action. Read only the evidence relevant to the
user's requested workstream.

## Establish The Active Workstream

PageSage does not keep a generated `docs/PROJECT_TASKS.md`. The durable state lives in these documents; read them in
this order:

1. `docs/implementation-status.md` — the current milestone-by-milestone status table and known gaps.
2. `docs/plan-to-m5.md` — the active sequenced plan and its stage baseline.
3. The newest dated records: `docs/11-pdf-canvas-implementation-plan.md`, `docs/10-pdf-renderer-migration.md`,
   `docs/08-ui-ux-redesign-plan.md`, `docs/v1-experience-freeze.md`, `docs/changelog.md`.
4. `docs/tasks/<name>.md` for the tasks the requested scope names or affects, and `docs/tasks/README.md`.
5. `docs/07-roadmap.md` for milestone order, and `AGENTS.md` for the fixed product constraints.

Identify the workstream from explicit persisted state and the newest relevant evidence, not memory or an isolated
backlog heading. If the evidence is ambiguous, state `I am treating <name> as the active workstream` and explain the
source. Do not silently broaden the scope or persist the assumption.

When the documents carry these facts, treat them as the durable state:

- `Status`: `inactive`, `active`, `blocked`, or `completed`.
- `Name`: the primary capability, migration line, or release objective.
- `Scope`: included components and explicit exclusions.
- `Source`: the controlling plan, decision, or task.
- `Current Gate`: the prerequisite or acceptance condition controlling the next action.
- `Supporting Blockers`: validation, tooling, or environment work that blocks progress without replacing the primary
  workstream.
- `Last Confirmed`: the date and evidence that last established this state.

Do not edit an index merely to answer a status question. Update `docs/implementation-status.md` or the plan only when
the user explicitly switches or closes a workstream, or when a coordination session activates an accepted plan or
task transition. A supporting task, smoke check, dependency bump, cleanup, or release tag never switches the primary
workstream by itself.

## Build The Evidence Ledger

Reconcile four sources before claiming that a remaining-work list is complete:

| Evidence | Establishes |
| --- | --- |
| Active plan (`docs/plan-to-m5.md`, `docs/11-*.md`) | Intended direction, stages, and sequencing candidates |
| Accepted constraint (`AGENTS.md`, `docs/00`–`07`, freeze docs) | Authoritative product and architecture boundaries |
| Task index and task documents (`docs/tasks/`) | Assigned scope and recorded delivery state |
| Commit, branch, and validation evidence (`git log`, test runs, manual checks) | What changed, landed, and was actually verified |

Treat roadmap bullets, task checkboxes, priority lists, follow-ups, and tooling-only results as candidates, not
current facts. `docs/07-roadmap.md` checkboxes are known to lag implementation; cross-check them against
`docs/implementation-status.md` and the code.

## Run Required Audits

### Constraint Implementation Audit

Classify every relevant constraint from `AGENTS.md` and the accepted docs as `fully implemented`, `partially
implemented`, `implementation pending`, or `out of scope`. Add unfinished stages to the dependency graph even when
the active plan omitted them. When a plan conflicts with `AGENTS.md` (for example it proposes MOBI, cloud sync, OCR,
or DRM work), report the conflict and treat `AGENTS.md` as authoritative until the roadmap is deliberately changed.

### Supersession Audit

For every candidate remaining item:

1. Search newer task, plan, changelog, and validation records.
2. Verify referenced commit evidence when available.
3. Classify the candidate as `active`, `blocked`, `completed`, `superseded`, or `uncertain`.
4. Exclude completed or superseded history from remaining work.
5. Report contradictory evidence instead of guessing.

Do not provide a definitive remaining-work list if this audit has not been completed.

### Drift Audit

Classify recent work before proposing another wave:

- `Aligned implementation`: still follows the controlling plan and constraints.
- `Partial completion`: completed one slice without completing the broader capability.
- `Validation follow-up`: proves behavior or resolves an environment gate without changing product direction.
- `Superseded historical backlog`: old work already completed or replaced.
- `Potential drift`: ownership, scope, product boundary, or sequencing conflicts with the controlling source.

Resolve or dispatch a correction for potential drift before extending it with downstream implementation.

## Apply Dependency Gates

Classify dependencies as hard prerequisites, soft dependencies, or independent work. When a hard contract, schema,
migration, renderer-bridge protocol, privacy rule, or external-input prerequisite is unresolved:

- propose only the prerequisite owner as the current executable wave;
- keep downstream work planned, not dispatched;
- do not claim the wave is parallelizable;
- require upstream execution and acceptance evidence before downstream implementation.

## Classify The Answer

Use these lanes:

- `Primary workstream`
- `Validation blocker / supporting task`
- `Future / release / operations`
- `Product or architecture decision`

Answer only the lane the user requested. Mention another lane only when it blocks the requested one. Do not let a
supporting task replace the primary workstream unless the user explicitly changes direction.

For release-readiness questions, also include active release-blocking items (`docs/release-checklist.md`,
`docs/m4-release-checklist.md`), unfinished constraints, explicit exclusions, external gates, and fresh runtime or
device evidence. Historical pilot or tooling evidence is not current release evidence.

## Output

State the active workstream, controlling source, current gate, evidence confidence, drift result, and next action.
Use concrete document names, dates, task states, and commit identifiers when available.

Use this compact shape:

```text
I am treating <workstream> as the active workstream.

Primary workstream:
- <state, evidence, next action>

Validation blocker / supporting task:
- <only when it blocks the requested work>

Future / release / operations:
- <only when explicitly requested>

Drift:
- none | <potential drift and correction>
```
