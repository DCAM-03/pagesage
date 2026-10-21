---
name: workstream-triage
description: Anchor the active software-delivery workstream and reconcile plans, accepted decisions, task records, validation, and commit evidence. Use before answering status, remaining-work, next-wave, continue, prioritization, parallelization, schedule, or release-readiness requests, especially when supporting validation or operations work may have interrupted the primary workstream.
---

# Workstream Triage

Prevent scope drift and stale backlog from controlling the next action. Read only the evidence relevant to the user's requested workstream.

## Establish The Active Workstream

1. Read the root `docs/PROJECT_TASKS.md` and its `Active Workstream` fields.
2. Read linked active plans, accepted decisions, and the closest dated task records.
3. Read component task indexes when the requested scope names or affects those components.
4. Identify the workstream from explicit persisted state and the newest relevant evidence, not memory or an isolated backlog heading.
5. If the evidence is ambiguous, state `I am treating <name> as the active workstream` and explain the source. Do not silently broaden the scope or persist the assumption.

Treat these fields as the durable state when present:

- `Status`: `inactive`, `active`, `blocked`, or `completed`.
- `Name`: the primary capability, repair line, contract, or release objective.
- `Scope`: included components and explicit exclusions.
- `Source`: the controlling plan, decision, or task.
- `Current Gate`: the prerequisite or acceptance condition controlling the next action.
- `Supporting Blockers`: validation, credentials, infrastructure, or operations work that blocks progress without replacing the primary workstream.
- `Last Confirmed`: the date and evidence that last established this state.

Do not edit the index merely to answer a status question. Update it only when the user explicitly switches or closes a workstream, or when a coordination session activates an accepted plan/task transition. A supporting task, smoke check, credential rotation, cleanup, release tag, or deployment action never switches the primary workstream by itself.

## Build The Evidence Ledger

Reconcile four sources before claiming that a remaining-work list is complete:

| Evidence | Establishes |
| --- | --- |
| Active plan | Intended direction, stages, and sequencing candidates |
| Accepted decision | Authoritative product or architecture constraints and unfinished stages |
| Task index, task document, execution and acceptance records | Assigned scope and recorded delivery state |
| Commit, merge, worktree, and validation evidence | What changed, landed, and was actually verified |

Treat plan entries, roadmap bullets, priority lists, follow-ups, and tooling-only results as candidates, not current facts.

## Run Required Audits

### Decision Implementation Audit

Classify every relevant accepted decision as `fully implemented`, `partially implemented`, `implementation pending`, or `customer-gated`. Add unfinished stages to the dependency graph even when the active plan omitted them. When a plan conflicts with an accepted decision, report the conflict and treat the accepted decision as authoritative until superseded.

### Supersession Audit

For every candidate remaining item:

1. Search newer task, execution, acceptance, closed, merged, or validation records.
2. Verify referenced commit or merge evidence when available.
3. Classify the candidate as `active`, `blocked`, `completed`, `superseded`, or `uncertain`.
4. Exclude completed or superseded history from remaining work.
5. Report contradictory evidence instead of guessing.

Do not provide a definitive remaining-work list if this audit has not been completed.

### Drift Audit

Classify recent work before proposing another wave:

- `Aligned implementation`: still follows the controlling decision and workstream.
- `Partial completion`: completed one slice without completing the broader capability.
- `Validation follow-up`: proves behavior or resolves an external gate without changing product direction.
- `Superseded historical backlog`: old work already completed or replaced.
- `Potential drift`: ownership, scope, product boundary, or sequencing conflicts with the controlling source.

Resolve or dispatch a correction for potential drift before extending it with downstream implementation.

## Apply Dependency Gates

Classify dependencies as hard prerequisites, soft dependencies, or independent work. When a hard contract, schema, migration, security, ownership, or external-input prerequisite is unresolved:

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

Answer only the lane the user requested. Mention another lane only when it blocks the requested one. Do not let a supporting task replace the primary workstream unless the user explicitly changes direction.

For release-readiness questions, also include active release-blocking priority items, unfinished accepted decisions, explicit exclusions, external gates, and fresh runtime or end-to-end evidence. Historical pilot or tooling evidence is not current release evidence.

## Output

State the active workstream, controlling source, current gate, evidence confidence, drift result, and next action. Use concrete document names, dates, task states, and commit identifiers when available.

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
