---
name: code-quality-audit
description: Audit Java, Kotlin, TypeScript, JavaScript, Go, and Python changes for over-defensive fallback, broad or silent exception handling, empty success masking, unsafe browser token storage, TypeScript any/default masking, first-match fallback selection, React derived-state effects, and test helpers that fabricate runtime resources. Use for changed-file quality checks, code review, focused hardening, regression gates, or classifying suspicious fallback and unnecessary-complexity patterns.
---

# Code Quality Audit

Read `references/defensive-fallback-discipline.md`, then use the scanner to collect review candidates. Inspect source context and the applicable product contract before classifying a finding. The scanner is heuristic, not an AST parser or defect classifier.

## Choose A Profile

| Target | Profile |
| --- | --- |
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

## Changed-File Review

Run from each real Git repository root. Replace `<skill>` with the installed skill path when needed.

```bash
python3 <skill>/scripts/scan_code_quality.py \
  --root . --profile backend-java --changed-since HEAD
```

`--changed-since` includes tracked changes relative to the revision and untracked files. Do not run it from a coordination directory that only contains nested repositories.

For a tracked task, use the profile and revision declared in the task. Record the command, relevant findings, and each disposition in the execution record.

## Baseline And Gate

Use a baseline for repeated repository-wide hardening, not as a default requirement for feature work.

```bash
python3 <skill>/scripts/scan_code_quality.py \
  --root . --profile backend-java \
  --write-baseline docs/quality/backend-java-baseline.json --summary-only

python3 <skill>/scripts/scan_code_quality.py \
  --root . --profile backend-java \
  --baseline docs/quality/backend-java-baseline.json --only-new --fail-on high
```

Baseline comparison rejects mismatched scanner version, scope, profile, rules, severity, or test configuration. `--max-findings` limits displayed details only; it does not truncate baselines, summary counts, or failure decisions.

Use repeatable `--rule <rule-id>` for a narrower scan. Use `--include-tests` only when production rules should also inspect test files.

## Review Workflow

1. Select the owner-specific profile and the narrowest relevant Git root.
2. Prefer changed-file mode for feature work; use a full scan only for a dedicated hardening workstream.
3. Inspect every HIGH finding and its contract. Sample and group MEDIUM findings.
4. Classify candidates as `real bug`, `documented fallback`, `migration compatibility`, `test-only acceptable`, or `false positive`.
5. Fix only confirmed defects within the declared task scope.
6. Keep compiler, linter, focused tests, and runtime harnesses as the actual acceptance evidence.

## Guardrails

- Never treat scanner output or a zero-finding result as proof that code is correct.
- Never fix all hits mechanically; valid product fallbacks must remain explicit and tested.
- Never expand a feature task into repository-wide hardening without coordinating a separate workstream.
- Keep raw scan dumps out of `docs/PROJECT_TASKS.md`; record only status and links there.
