# Contract Sequencing

Use this reference when a change affects a locator format, renderer bridge message, Drift schema, export format,
package boundary, or another consumer-facing contract.

Perform the cross-surface inventory, edits, and parity validation directly using this reference; PageSage does not
install a separate contract-sync skill. This reference controls ownership and dispatch sequencing.

1. Locate the contract owner from `AGENTS.md`, `docs/05-technical-architecture.md`, `docs/06-data-model.md`, and
the existing source. Do not infer ownership from directory names alone.
2. Record the desired fields, error behavior, nullability, enum values, numeric and coordinate precision,
authorization/privacy behavior, and compatibility stance in the owning task or contract document.
3. Implement or verify the provider-side contract first when the contract is new or unresolved.
4. After the producer execution record exists, update consumers: domain models, repositories and DAOs,
application controllers, presentation widgets, test support and fixtures, and exported/document formats as applicable.
5. Validate the real producer path before treating a mock, `flutter analyze`, or a passing widget test as completion.
6. Record each consumer lane separately. A producer pass does not imply widget, repository, renderer, or
platform pass.

If the contract is already accepted and unchanged, consumers can proceed in parallel. State the accepted source and the compatibility assumption in each task record.
