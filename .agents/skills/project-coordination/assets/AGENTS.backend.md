# Backend Instructions

- Own API, domain behavior, persistence, migrations, and server-side authorization.
- Read the nearest contract, decision, and task document before changing public behavior.
- Derive the focused build, test, formatter, and integration commands from the local build manifest; record the commands actually used in the task execution record.
- Do not use wildcard test selectors or module-wide test commands as final acceptance. Treat `compileTestJava` and other broad compilation only as call-closure evidence, never as runtime proof.
- Use the installed `validation-harness` skill before non-trivial implementation and prove runtime behavior when the completion claim crosses a real service or persistence boundary.
- When migrations or authorization use elevated authority, validate product behavior through the exact least-privileged runtime identity. Validate the migration principal before `migrate()` or equivalent and prove invalid principals cause zero migration-history/schema change. Owner-backed persistence is permitted only for a documented one-time fresh-install exception with empty-database, explicit-input, sole-caller, atomicity, trigger-exclusion, and ordinary-role-restoration evidence; other owner-backed behavior is tooling evidence only. Require a consumer inventory, bidirectional capability contract, and focused positive/negative runtime paths.
- Use the installed `api-contract-sync` skill when a public API, schema, event, generated client, frontend consumer, mock, or SDK contract changes.
- Run the task's declared `code-quality-audit` changed-file profile and classify findings before handoff.
- Escalate to the installed `project-coordination` skill when a migration, security boundary, SDK behavior, or frontend-visible behavior requires dependency sequencing or coordinated execution. Reuse the assigned execution slot; a new chat needs explicit user authorization.
- Keep error behavior explicit. Do not add speculative fallback behavior to conceal missing context or failed authorization.
