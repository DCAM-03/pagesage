# Contract Closure

Use this reference during task creation and independent acceptance. A focused harness proves selected behavior; contract closure proves that selection covered every affected production surface.

## Build The Matrix

1. Inspect the actual diff and current repository state. Identify changed external and cross-module contracts rather than relying on the task's expected file list.
2. Trace each contract through its producers, consumers, official runtime/build/packaging entry points, test support, generated artifacts, and documentation as applicable.
3. Record planned evidence and implementation evidence separately. Initialize coordinator disposition as `BLOCKED`. A
   grouped row is allowed when several unchanged consumers or official entry points share the same concrete no-impact
   reason; list every grouped path in that row so coverage remains auditable without repeating the same inspection.
4. Execution supplies row evidence; independent acceptance reviews its scope and sufficiency. Coordination imports
   that review after file handoff and sets disposition without performing a second full technical review:
   - `VERIFIED`: direct static or runtime evidence proves the surface follows the changed contract.
   - `NOT_AFFECTED`: a concrete code, dependency, or ownership reason proves the surface is outside the change.
   - `BLOCKED`: evidence is missing or contradictory, or an official consumer still follows the old contract.

Any `BLOCKED` production consumer or official runtime/build/packaging entry point prevents acceptance and merge.

## Trace Typical Paths

- Locator or bridge message: renderer JS -> Dart bridge -> domain locator -> persisted progress -> reopen.
- Database: Drift schema -> migration -> repositories/DAOs -> backup/restore -> reader reopen.
- UI structure: route -> owning widget and target container -> excluded siblings and the other viewport -> rendered screen.
- Export or share: producer -> file format -> consumer import -> documentation.
- Configuration: declaration/default -> validation -> startup path -> settings UI -> persisted value.
- Retirement: removed implementation -> callers/routes/schema residue -> semantic negative runtime behavior -> docs/search indexes.

## Keep Closure Focused

Use static dependency, caller, ownership, and artifact tracing first. Then run only the smallest named runtime or E2E gate needed for an unresolved affected boundary. Do not use closure review to authorize wildcard selectors, full-module or full-repository suites, or repeated aggregate testing. If no affected boundary remains unresolved, close the matrix without another runtime pass.

Reuse evidence only when the relevant implementation and contract are unchanged and the matrix records why it remains valid. Documentation-only remediation may correct records, but cannot upgrade runtime evidence, clear a technical blocker, or replace the affected technical gate.

If later review invalidates evidence, append the reason and reset only the affected matrix rows to `BLOCKED`. Preserve
unaffected `VERIFIED` or `NOT_AFFECTED` rows with their evidence. Keep implementation state independent: existing real
behavior may remain `IMPLEMENTED` while validation becomes `BLOCKED` until the named rows close again.
