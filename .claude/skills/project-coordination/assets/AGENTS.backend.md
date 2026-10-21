# Data And Domain Instructions

- Own the domain model, Drift persistence, repositories, migrations, and application-layer use cases.
- Read the controlling docs (`docs/05-technical-architecture.md`, `docs/06-data-model.md`), the decision, and the task document before changing persisted behavior.
- Derive the focused analyze, test, and integration commands from `AGENTS.md` and `pubspec.yaml`; record the commands actually used in the task execution record.
- Do not use bare `flutter test` or directory-wide test commands as final acceptance. Treat `flutter analyze` and a successful build only as tooling evidence, never as runtime proof.
- Use the `validation-harness` skill before non-trivial implementation and prove runtime behavior when the completion claim crosses a real database, file, or renderer boundary.
- Migrations are additive and forward-only. Never edit a released migration or clear user data as a migration shortcut. Prove fresh install and upgrade from the supported previous schema, plus a semantic negative case.
- Import copies books into the library directory; removing a book must never delete the user's original file path.
- Store API keys only in secure storage. Never log API keys, AI request payloads, selected book text, or full AI context by default.
- Run the task's declared `code-quality-audit` changed-file profile (`flutter-dart` by default) and classify findings before handoff.
- Escalate to the `project-coordination` skill when a migration, privacy boundary, renderer-bridge behavior, or user-visible behavior requires dependency sequencing or coordinated execution. Reuse the assigned execution slot; delegation needs explicit user authorization.
- Keep error behavior explicit. Do not add speculative fallback behavior to conceal missing context or failed persistence.
