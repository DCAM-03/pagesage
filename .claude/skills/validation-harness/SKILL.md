---
name: validation-harness
description: Define, run, and record the narrowest reproducible validation surface for non-trivial PageSage changes. Use before implementation, when choosing tests, when proving a fix or feature, when reviewing completion evidence, when runtime or device smoke is requested, or when deciding whether build-, mock-, tooling-, runtime-, or end-to-end evidence supports a completion claim.
---

# Validation Harness

Read `AGENTS.md`, the active task document under `docs/tasks/` when one exists, and
`docs/05-technical-architecture.md` for the owning layer. Discover commands and runtime topology from the project; do
not require the user to maintain them in a profile file.

PageSage has no `docs/PROJECT_PROFILE.md`. The project commands come from `AGENTS.md` (Verification) plus
`pubspec.yaml`; the task scope comes from `docs/tasks/<name>.md` and the controlling plan.

## Declare The Harness Before Editing

Record these facts before changing production code:

1. Behavior or contract being proved.
2. Narrowest command, script, manual flow, or reader scenario that exercises it.
3. Fixture, sample book, device, or external input required.
4. Expected pass signal and, for a defect, the expected pre-fix failure.
5. Meaningful negative cases for persistence, migration, privacy, permissions, lifecycle, and destructive behavior
   when applicable.
6. Where commands, results, and remaining gaps will be recorded.

Prefer the fastest closed loop that can falsify the intended behavior. Do not substitute `flutter analyze` or a broad
`flutter test` run for a focused behavioral check, but do not stop at a widget test when the completion claim crosses
the renderer, the database, or the real reader path.

For each new behavioral assertion, identify the defect it would reject. Isolate competing causes (one failing
timeout does not prove a renderer defect); require the intended status or error rather than any failure. Concurrency
proof needs observable ordering and resulting state, not just a started isolate. Reuse existing test support and add
only the missing assertions. A full mutation-testing run is not required. Before handoff, map the declared invariants
to actual assertions once; missing feasible coverage is implementation work, not an acceptance blocker to rediscover
in another session.

For a consumer or integration task, cite the dependency task's candidate and applicable PASS evidence, then prove
only this task's changed integration boundary. Do not repeat the dependency's full matrix unless the dependency
source, contract, fixture, or sample book changed, a concrete regression was observed, or the required boundary has
no valid evidence. A missing prerequisite for an unrelated scenario is not a new gate for this task.

## PageSage Evidence Lanes

| Lane | Surfaces | What it can establish |
| --- | --- | --- |
| Tooling | `dart format`, `flutter analyze`, unit/widget test, static scan, mock, fake repository | Local structure, isolated logic, widget composition |
| Runtime | `flutter test` against a real Drift database path, PDF/EPUB sample parsing, renderer contract test with a real file, D-Bus/desktop integration | Behavior on the owning runtime surface inside the test host |
| End to end | `flutter run -d windows` / Android device: import → open → read → save progress → reopen; real EPUB/PDF sample; on-device file picker and secure storage | Behavior across the real app, platform plugins, and user flows |

A widget test that pumps a renderer widget is tooling evidence unless it exercises the real renderer bridge with a
real book. A golden test proves rendering consistency, not reading correctness. A successful `flutter build` proves
packaging only.

## Keep Final Acceptance Focused

Declare a short named matrix in the canonical task document. For every entry, record the exact test file and
`test`/`testWidgets` name or the manual flow; the contract or invariant it proves; why it belongs to the changed
scope; and the expected signal. `dart format`, `flutter analyze`, `flutter build`, a static scan, or a mock may be
recorded as tooling evidence only, with its limited closure claim.

Acceptance independently reviews code, assertions, and execution evidence; it need not rerun every command. Reuse
reproducible PASS evidence when the relevant implementation, dependencies, contract, and fixture remain applicable.
Select independent replay for a material unproved boundary, suspect evidence, or a high-risk invariant whose runtime
result is decisive. State the defect or uncertainty a replay resolves. A new review turn, timestamp, unrelated file
change, or desire for a second green result is not an invalidation reason. After remediation, run changed checks and
actual affected dependents only. Review causal assertions before expensive device replay, rather than discovering
obvious proof gaps after running the same suite again.

Use this evidence decision before scheduling any replay:

| Current evidence | Action |
| --- | --- |
| Source, contract, fixture and entry point are unchanged and the prior PASS is reproducible | Reuse it and record why it remains valid |
| A changed diff row has a named focused check | Review the executor's post-change result first; replay only for a remaining material uncertainty |
| A required boundary has no decisive evidence, or a result is suspect/stale | Run one named replay and record the uncertainty it resolves |
| Record wording or formatting changes with no behavioral effect | Check the changed artifact only; retain applicable product evidence |

Repeated execution needs a concrete unresolved question, such as measured flakiness, a concurrency claim requiring
repetition, or a corrected environment. Bound it and record the reason; a later green run does not erase a failure.
Formatting of executable configuration, public contract documentation, and UI styling may affect product behavior;
classify their actual impact rather than exempting them by file type. When no blocking gap remains, return the result.

Do not use any of these as a final acceptance entry:

- a bare `flutter test` or `dart test` run;
- `flutter test test/` or another directory-scoped aggregate;
- a wildcard selector such as `--plain-name '*Pdf*'`; or
- full-repository or full-module aggregate tests.

The coordinator may allow an exception only in the task document, with a complete impact matrix and a specific
explanation of why named focused selectors cannot prove the required contract. Do not infer an exception from a slow
test suite, a convention, or a previous task.

If a selector unexpectedly expands, let the already-running process finish. Record the actual executed count and
result as exploratory evidence, then stop final acceptance. Replace it with a named selector before continuing. Do
not relabel the expanded result as focused evidence.

When a task removes a test, the execution record must map each deleted semantic invariant to a new named replacement
test. Migration prose, byte parity, file names, and annotation scans do not establish runtime or persistence
behavior. Require at least one semantic negative case whenever persistence, migration, privacy, deletion, or test
replacement/removal is in scope.

## Select Evidence Depth

When a contract cross-surface inventory exists, treat its authoritative source and affected-consumer list as
validation inputs. If a contract change lacks that inventory, report the missing sync requirement instead of
guessing the consumers. Use the `code-quality-audit` skill when the task declares a changed-file quality gate.

For renderer work, read `AGENTS.md` and `docs/10-pdf-renderer-migration.md` before declaring the harness. The manual
validation loop is fixed: open a real sample, navigate, receive location events, save progress, close, reopen at the
same location. A renderer change without that loop is `TOOLING_PASS` at most. Read
`references/runtime-smoke.md` before starting or reporting device or desktop smoke.

For UI placement, relocation, visibility, or container ownership, read `references/frontend-structure.md`. For Drift
schema changes, backup/restore, migration, and destructive data paths, read
`references/migration-and-destructive-data.md`.

## Close Affected Contracts Independently

A passing declared harness proves the selected behavior, not that the selected impact scope was complete. During
independent acceptance:

1. Inspect the actual diff and identify every changed external or cross-module contract, including Drift schema and
   migration behavior, locator format, renderer bridge messages, secure-storage keys, export formats, settings
   persistence, and removed compatibility surfaces.
2. Trace each contract through producers, consumers, official runtime entry points, test support, and documentation
   as applicable. Do not stop at files named in the task or changed by the execution session.
3. Record each relevant surface in the task's Contract Closure Matrix as `VERIFIED`, evidence-backed
   `NOT_AFFECTED`, or `BLOCKED`. The execution session may append evidence but may not approve its own disposition.
4. Use static dependency and caller tracing first. Group unchanged consumers or entry points with the same concrete
   no-impact reason, listing each path in the grouped row. Run only the smallest named runtime gates needed for
   unresolved affected boundaries; closure review does not authorize wildcard, directory-wide, repository-wide, or
   repeated aggregate tests.
5. Treat implementation status, checked acceptance criteria, and execution summaries as claims to verify against
   current code and official entry points.

Any `BLOCKED` production consumer or official runtime entry point prevents acceptance. A documentation-only
correction may repair the record or preserve unaffected evidence, but cannot by itself upgrade runtime evidence or
close a technical blocker.

## Record Both Axes

Every tracked execution and acceptance record must state:

| Axis | Values |
| --- | --- |
| Implementation State | `DESIGN_ONLY`, `CONTRACT_ONLY`, `STUB_ONLY`, `IMPLEMENTED` |
| Validation Evidence | `UNVERIFIED`, `TOOLING_PASS`, `RUNTIME_PASS`, `E2E_PASS`, `BLOCKED` |

Only real product behavior with `IMPLEMENTED + RUNTIME_PASS` or `IMPLEMENTED + E2E_PASS` may be described externally
as complete. A design, generated type, placeholder, mock-only flow, successful build, or timestamp proves only its
stated surface. Documentation-only work may be accepted as documentation without implying runtime behavior.

Move the two axes independently when evidence is invalidated. If implemented behavior still exists but a required
runtime gate fails, becomes stale, or is found incomplete, preserve `Implementation State: IMPLEMENTED`, set
`Validation Evidence: BLOCKED`, reopen the task, and name only the invalidated or missing closure rows. Do not reset
implementation to design/stub state or rerun unaffected gates without a separate impact reason.

When validation is blocked, record the missing environment, device, sample book, credential, decision, or external
approval and the exact next command or flow. Do not weaken the expected behavior to obtain a pass.

## Execute And Record

1. Capture the starting failure or baseline when feasible.
2. Implement only the declared task scope.
3. Re-run the same harness after the change.
4. Expand to runtime or end-to-end checks when the user-visible claim crosses those boundaries.
5. Record each lane independently; one lane passing does not imply another passed.
6. Append evidence to the canonical task's execution record. The execution session does not accept its own work.
7. During acceptance, independently inspect the diff, complete the Contract Closure Matrix, rerun or verify the
   smallest decisive harness, and confirm that the evidence depth matches the completion claim.

Before running Flutter/Dart commands, prefer the `dart` MCP tools when they are available (`analyze_files`,
`run_tests`, package queries); fall back to `Bash` only when the MCP is unavailable. Check for a leftover app instance
before a manual device or desktop run, and clean up the process afterwards.

## Output

Report the declared harness, commands or flows executed, observed results, both state axes, lane-specific gaps, and
the next reproducible action. Never report a stronger conclusion than the evidence supports.
