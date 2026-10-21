---
name: validation-harness
description: Define, run, and record the narrowest reproducible validation surface for non-trivial software changes. Use before implementation, when choosing tests, when proving a fix or feature, when reviewing completion evidence, when runtime or browser smoke is requested, or when deciding whether build-, mock-, tooling-, runtime-, or end-to-end evidence supports a completion claim.
---

# Validation Harness

Read `docs/PROJECT_PROFILE.md`, the nearest applicable `AGENTS.md`, and the active task document when one exists. Discover commands and runtime topology from the project; do not require the user to maintain them in the profile.

## Declare The Harness Before Editing

Record these facts before changing production code:

1. Behavior or contract being proved.
2. Narrowest command, script, request, or user flow that exercises it.
3. Fixture, account, seed data, service, browser, or external input required.
4. Expected pass signal and, for a defect, the expected pre-fix failure.
5. Meaningful negative cases for security, permissions, tenancy, validation, lifecycle, and destructive behavior when applicable.
6. Where commands, results, and remaining gaps will be recorded.

Prefer the fastest closed loop that can falsify the intended behavior. Do not substitute a broad build for a focused behavioral check, but do not stop at a narrow mock when the completion claim crosses a real boundary.

For each new behavioral assertion, identify the defect it would reject. Isolate competing causes (one expired deadline
does not prove another); require the intended status/error rather than any failure. Concurrency proof needs observable
admission/order and resulting state, not goroutine launch order or channel-read order. Reuse existing test support and
add only the missing assertions. A full mutation-testing run is not required. Before handoff, map the declared
invariants to actual assertions once; missing feasible coverage is implementation work, not an acceptance blocker to
rediscover in another session.

For a consumer or integration task, cite the dependency task's candidate and applicable PASS evidence, then prove
only this task's changed integration boundary. Do not repeat the dependency's full product, authentication or account
lifecycle matrix unless the dependency source/contract/fixture changed, a concrete regression was observed, or the
required boundary has no valid evidence. A missing prerequisite for an unrelated scenario is not a new gate for this
task.

## Keep Final Acceptance Focused

Declare a short named matrix in the canonical task document. For every entry, record the exact test file, test class or test name, or browser scenario; the contract or invariant it proves; why it belongs to the changed scope; and the expected signal. A broad compile, typecheck, build, static scan, or mock may be recorded as tooling evidence only, with its limited closure claim.

Acceptance independently reviews code, assertions and execution evidence; it need not rerun every command. Reuse
reproducible PASS evidence when the relevant implementation, dependencies, contract and fixture remain applicable.
Select independent replay for a material unproved boundary, suspect evidence, or a high-risk invariant whose runtime
result is decisive. State the defect or uncertainty a replay resolves. A new review turn, timestamp, unrelated file
change or desire for a second green result is not an invalidation reason. After remediation, run changed checks and
actual affected dependents only. Review causal assertions before expensive runtime replay, rather than discovering
obvious proof gaps after running the same suite again.

Use this evidence decision before scheduling any replay:

| Current evidence | Action |
| --- | --- |
| Source, contract, fixture and official entry point are unchanged and the prior PASS is reproducible | Reuse it and record why it remains valid |
| A changed diff row has a named focused check | Review the executor's post-change result first; replay only for a remaining material uncertainty |
| A required boundary has no decisive evidence, or a result is suspect/stale | Run one named replay and record the uncertainty it resolves |
| Record wording or formatting changes with no behavioral effect | Check the changed artifact only; retain applicable product evidence |

Repeated execution needs a concrete unresolved question, such as measured flakiness, a concurrency claim requiring
repetition, or a corrected environment. Bound it and record the reason; a later green run does not erase a failure.
Formatting of executable configuration, public contract documentation, and UI styling may affect product behavior;
classify their actual impact rather than exempting them by file type. When no blocking gap remains, return the result.

Do not use any of these as a final acceptance entry:

- wildcard selectors such as `--tests '*Delivery*'`;
- `pnpm test`, no-argument Vitest, or another unscoped frontend test command;
- module tests with no exact selector; or
- full-repository or full-module aggregate tests.

The coordinator may allow an exception only in the task document, with a complete impact matrix and a specific explanation of why named focused selectors cannot prove the required contract. Do not infer an exception from a slow test suite, a convention, or a previous task.

If a selector unexpectedly expands, let the already-running process finish. Record the actual executed count and result as exploratory evidence, then stop final acceptance. Replace it with a named selector before continuing. Do not relabel the expanded result as focused evidence.

When a task removes a test, the execution record must map each deleted semantic invariant to a new named replacement test. Migration prose, byte parity, file names, and annotation scans do not establish runtime or security behavior. Require at least one semantic negative case whenever runtime, security, migration, or test replacement/removal is in scope.

## Select Evidence Depth

| Evidence depth | Typical surfaces | What it can establish |
| --- | --- | --- |
| Tooling | formatter, linter, compiler, typecheck, unit test, static scan, fake server, mock | Local structure or isolated behavior |
| Runtime | integration test, real process, real database path, actual package consumer, live endpoint | Behavior on the owning runtime surface |
| End to end | cross-service request, browser user flow, SDK against a real API, external integration | Behavior across all required consumer boundaries |

When an `api-contract-sync` ledger exists, treat its authoritative source and affected-consumer list as validation inputs. If a contract change lacks that inventory, report the missing sync requirement instead of guessing the consumers. Use the installed `code-quality-audit` skill when the task declares a changed-file quality gate.

For combined Portal/Admin and backend work, read
`docs/guides/local-integration-runtime.md` before starting live smoke. Bind every integrated result to the fixed
environment's service candidates, source/OpenAPI/schema fingerprints, configuration source, data volume and fixture
identity. A component PASS or a healthy port cannot establish integrated completion; a fixed-environment PASS may be
reused while those bindings remain unchanged.

## Close Affected Contracts Independently

A passing declared harness proves the selected behavior, not that the selected impact scope was complete. During
independent acceptance (coordination imports the result rather than repeating this review):

1. Inspect the actual diff and identify every changed external or cross-module contract, including API/DTO shapes, persistence and authorization behavior, configuration, UI placement, SDK/package exports, generated artifacts, deployment inputs, error semantics, and removed compatibility surfaces.
2. Trace each contract through producers, consumers, official runtime/build/deployment entry points, mocks, generated artifacts, and public documentation as applicable. Do not stop at files named in the task or changed by the execution session.
3. Record each relevant surface in the task's Contract Closure Matrix as `VERIFIED`, evidence-backed `NOT_AFFECTED`, or `BLOCKED`. The execution session may append evidence but may not approve its own disposition.
4. Use static dependency and caller tracing first. Group unchanged consumers or entry points with the same concrete no-impact reason, listing each path in the grouped row. Run only the smallest named runtime gates needed for unresolved affected boundaries; closure review does not authorize wildcard, module-wide, repository-wide, or repeated aggregate tests.
5. Treat implementation status, checked acceptance criteria, and execution summaries as claims to verify against current code and official entry points.

Any `BLOCKED` production consumer or official runtime/build/deployment entry point prevents acceptance. A documentation-only correction may repair the record or preserve unaffected evidence, but cannot by itself upgrade runtime evidence or close a technical blocker.

## Record Both Axes

Every tracked execution and acceptance record must state:

| Axis | Values |
| --- | --- |
| Implementation State | `DESIGN_ONLY`, `CONTRACT_ONLY`, `STUB_ONLY`, `IMPLEMENTED` |
| Validation Evidence | `UNVERIFIED`, `TOOLING_PASS`, `RUNTIME_PASS`, `E2E_PASS`, `BLOCKED` |

Only real product behavior with `IMPLEMENTED + RUNTIME_PASS` or `IMPLEMENTED + E2E_PASS` may be described externally as complete. A design, generated type, placeholder, mock-only flow, successful build, or timestamp proves only its stated surface. Documentation-only work may be accepted as documentation without implying runtime behavior.

Move the two axes independently when evidence is invalidated. If implemented behavior still exists but a required
runtime gate fails, becomes stale, or is found incomplete, preserve `Implementation State: IMPLEMENTED`, set
`Validation Evidence: BLOCKED`, reopen the task, and name only the invalidated or missing closure rows. Do not reset
implementation to design/stub state or rerun unaffected gates without a separate impact reason.

When validation is blocked, record the missing environment, credential, account, service, decision, or external approval and the exact next command or flow. Do not weaken the expected behavior to obtain a pass.

## Execute And Record

1. Capture the starting failure or baseline when feasible.
2. Implement only the declared task scope.
3. Re-run the same harness after the change.
4. Expand to runtime or end-to-end checks when the user-visible claim crosses those boundaries.
5. Record each component or consumer lane independently; one lane passing does not imply another passed.
6. Append evidence to the canonical task's execution record. The execution session does not accept its own work.
7. During acceptance, independently inspect the diff, complete the Contract Closure Matrix, rerun or verify the smallest decisive harness, and confirm that the evidence depth matches the completion claim.

For live service, SDK, browser, or external-integration smoke, read `references/runtime-smoke.md` before running or reporting the harness.

For UI placement, relocation, visibility, or container ownership, read `references/frontend-structure.md`. For
migrations, database permissions, row-level security, or separate bootstrap/runtime identities, read
`references/privileged-runtime.md`.

## Output

Report the declared harness, commands or flows executed, observed results, both state axes, lane-specific gaps, and the next reproducible action. Never report a stronger conclusion than the evidence supports.
