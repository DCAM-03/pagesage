---
name: review-code-organization
description: Audit and improve Go, TypeScript, React, SDK, and Terraform project organization without template-driven rewrites. Use when evaluating directory structure, package boundaries, feature colocation, shared folders, import direction, coding standards, architecture drift, or a proposed repository refactor in the Go IAM workspace.
---

# Review Code Organization

Read `references/code-organization-and-style.md` and `references/code-organization.md` before making recommendations or edits.

## Workflow

1. Confirm the real repository and read the closest `AGENTS.md` and local language rules.
2. Inventory the actual tree with generated, dependency, build-output, and report directories excluded.
3. Inspect imports and representative files; do not infer architecture from folder names alone.
4. Identify concrete problems: unclear owner, low cohesion, cycles, duplicated contracts, accidental public API, cross-feature imports, or catch-all shared folders.
5. Classify findings as:
   - `keep`: structure is appropriate;
   - `guard`: structure is appropriate but needs an import/ownership rule;
   - `move-with-feature`: migrate only while changing that capability;
   - `dedicated-refactor`: broad move needs its own task and compatibility plan.
6. Propose the smallest target tree that resolves the observed problem. Do not prescribe full FSD, Clean Architecture, or a popular Go layout by default.
7. If editing, preserve behavior and public exports, use the owning repository's branch workflow, and run typecheck/test/build/lint gates.
8. Report residual risks and whether the result is documentation/tooling-only or runtime-proven.

## Language Checks

- Go: verify `cmd`/`internal` ownership, consumer-owned interfaces, package names, context/error behavior, generated-code boundaries, and acyclic imports.
- TypeScript: verify strictness, `unknown` at untrusted boundaries, assertion/`any` containment, DTO conversion, and minimal exports.
- React: verify feature colocation, pure render, minimal state, Effect usage, query/store ownership, form integration, accessibility, and test placement.
- SDK/provider: protect public compatibility and keep examples/tests outside runtime package ownership.

## Output

Lead with evidence-based findings. Separate immediate rule fixes from optional future migration. Include an explicit `do not move now` list whenever the current structure is already reasonable.
