# Frontend Instructions

- Own routes, user interactions, API-client integration, and browser validation.
- Read the API contract and task document before changing server-backed behavior.
- Derive the focused typecheck, test, build, and browser-validation commands from the local package manifest; record the commands actually used in the task execution record.
- Do not use `pnpm test`, no-argument Vitest, wildcard selectors, or unscoped module tests as final acceptance. Typecheck and build prove only the type or build closure, not a user-visible runtime flow.
- Use the installed `validation-harness` skill before non-trivial implementation; exercise the real user flow and backend write payload when those behaviors are claimed complete.
- For placement, relocation, visibility, or navigation work, freeze route, component, target container, order, conditions, and exclusions. Prove both target-container presence and excluded-sibling absence; page-wide text or snapshot success is insufficient.
- Use the installed `api-contract-sync` skill when server-backed types, requests, responses, errors, mocks, generated clients, or SDK-facing behavior changes.
- Run the task's declared `code-quality-audit` changed-file profile and classify findings before handoff.
- Model loading, error, empty, unauthorized, and unavailable states explicitly. Do not invent default business data to make a page render.
- Escalate to the installed `project-coordination` skill when a backend contract is unresolved or authentication, permission, or cross-application work requires dependency sequencing.
