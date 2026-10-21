---
name: code-quality-audit
description: Audit Dart/Flutter, Java, Kotlin, TypeScript, JavaScript, Go, and Python changes for over-defensive fallback, broad or silent exception handling, empty success masking, TypeScript any/default masking, first-match fallback selection, and test helpers that fabricate runtime resources. Use for changed-file quality checks, code review, focused hardening, regression gates, or classifying suspicious fallback and unnecessary-complexity patterns.
---

# Code Quality Audit

Read `references/defensive-fallback-discipline.md`, then use the scanner to collect review candidates. Inspect
source context and the applicable product contract before classifying a finding. The scanner is heuristic, not an
AST parser or defect classifier.

## Choose A Profile

| Target | Profile |
| --- | --- |
| PageSage Dart/Flutter (default for this repo) | `flutter-dart` |
| Java or Kotlin backend | `backend-java` |
| Go backend | `backend-go` with `--min-severity low` |
| Python backend | `backend-python` |
| Non-React TypeScript frontend | `frontend-typescript` |
| React frontend | `frontend-react` |
| JavaScript, Java, Go, or Python SDK | `sdk-js`, `sdk-java`, `sdk-go` with `--min-severity low`, or `sdk-python` |
| Mixed server SDKs | `sdk-server` |
| Test helpers that create runtime resources | `test-support` with `--min-severity low` |
| Low-confidence fallback names and empty results | `fallback-review` with `--min-severity low` |
| Deliberate repository-wide review | `all` |

For PageSage, `flutter-dart` covers unqualified `catch`, discarded (`_`) error parameters, missing
`catch`/return masking, `firstWhereOrNull` fallback selection, empty results, and `??` default masking. Prefer
`--min-severity low` for a focused hardening pass; the default medium hides the null-masking rules. Architecture and
state-management concerns belong to `AGENTS.md` and the docs, not to this scanner — it cannot see Riverpod scope,
layer direction, or widget-tree ownership.

## Changed-File Review

Run from the real Git repository root. `<skill>` is this skill directory.

```bash
python3 <skill>/scripts/scan_code_quality.py \
  --root . --profile flutter-dart --changed-since HEAD
```

`--changed-since` includes tracked changes relative to the revision and untracked files. Do not run it from a
directory that only contains nested repositories. `packages/` and `test/` are scanned like any other directory;
`build/`, `.dart_tool/`, `ephemeral/`, and `generated/` are skipped.

For a tracked task, use the profile and revision declared in the task. Record the command, relevant findings, and
each disposition in the execution record.

## Baseline And Gate

Use a baseline for repeated repository-wide hardening, not as a default requirement for feature work.

```bash
python3 <skill>/scripts/scan_code_quality.py \
  --root . --profile flutter-dart \
  --write-baseline docs/quality/flutter-dart-baseline.json --summary-only

python3 <skill>/scripts/scan_code_quality.py \
  --root . --profile flutter-dart \
  --baseline docs/quality/flutter-dart-baseline.json --only-new --fail-on high
```

`docs/quality/` is created only when a hardening workstream actually needs a baseline. Baseline comparison rejects
mismatched scanner version, scope, profile, rules, severity, or test configuration. `--max-findings` limits displayed
details only; it does not truncate baselines, summary counts, or failure decisions.

Use repeatable `--rule <rule-id>` for a narrower scan. Use `--include-tests` only when production rules should also
inspect test files.

## Review Workflow

1. Select the owner-specific profile and the narrowest relevant Git root.
2. Prefer changed-file mode for feature work; use a full scan only for a dedicated hardening workstream.
3. Inspect every HIGH finding and its contract. Sample and group MEDIUM findings.
4. Classify candidates as `real bug`, `documented fallback`, `migration compatibility`, `test-only acceptable`, or
   `false positive`.
5. Fix only confirmed defects within the declared task scope.
6. Keep `flutter analyze`, focused `flutter test`, and the runtime harness from `validation-harness` as the actual
   acceptance evidence.

## Guardrails

- Never treat scanner output or a zero-finding result as proof that code is correct.
- Never fix all hits mechanically; valid product fallbacks must remain explicit and tested.
- Never expand a feature task into repository-wide hardening without coordinating a separate workstream.
- Keep raw scan dumps out of the task index; record only status and links there.
- An empty `catch (_)` around a best-effort platform call may be legitimate — classify it against the documented
  product behavior rather than deleting the handler.
