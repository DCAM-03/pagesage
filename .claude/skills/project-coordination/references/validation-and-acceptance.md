# Validation And Acceptance

Use the installed `validation-harness` skill before implementation and when reviewing completion evidence. Treat its declared harness, implementation state, validation evidence, lane matrix, and blocked-gate rules as the validation source of truth; do not redefine them in this coordination reference.

When the task declares a quality audit, verify that the execution session ran the selected changed-file profile and classified each relevant finding. Scanner output is heuristic review input; it neither proves a defect nor replaces compiler, test, runtime, or end-to-end evidence.

The required independent acceptance session owns technical diff, assertion, contract and evidence review. Apply
`references/acceptance-loop.md` for convergence. Coordination verifies its terminal `ACCEPTED` result, candidate identity
and unresolved gates, then imports that result into task state; it does not repeat the technical acceptance or tests.
Use `assets/acceptance-record-template.md` once per coherent stage, preserving the execution/acceptance identities.
Tooling-only evidence, execution self-approval or an unresolved affected production boundary cannot establish product
completion. Require `IMPLEMENTED + RUNTIME_PASS` or `IMPLEMENTED + E2E_PASS`; commit/merge still needs authorization.

Use the focus and stop rule in `acceptance-loop.md`: prioritize accepted user outcomes and material risk, close all
required criteria, and separate optional improvements. The packet links existing evidence and records only the review
delta; do not copy the full execution record or reconstruct unchanged session metadata on each remediation.

After authorization, the coordination session must complete the merge/ref audit in `references/worktree-policy.md`.
The accepted worktree `HEAD` is not sufficient evidence: record the destination branch ref before and after merge,
verify ancestry against the accepted commit, confirm the merge worktree is clean, and preserve unrelated dirty source
checkout files. Record product-worktree cleanup separately from any app-managed detached worktree lifecycle.

The independent reviewer confirms UI target-container positive and excluded-sibling negative evidence. For
privileged runtime or migration changes, confirm evidence used the declared least-privileged runtime identity rather
than bootstrap/owner authority, and that fresh/upgrade paths plus the consumer-capability contract are reconciled.
Confirm migration-principal rejection occurred before the mutation entry point and preserved complete migration-history
and application-schema equality. Accept owner-backed fresh-install persistence only when the task proves the declared
empty-database, explicit-input, sole-caller, atomicity, trigger-exclusion, and ordinary-role-restoration boundaries.
