# Terraform State And Lifecycle

## Package Ownership

- `main.go` serves the plugin only.
- `internal/provider` owns provider schema, Configure, resource/data source registration, and client injection.
- `internal/client` owns authentication, cancellation, transport, stable API error decoding, bounded retry, and redaction.
- `internal/resource/<identity>` owns one Terraform resource's schema/model/CRUD/import/state upgrade behavior.
- `internal/datasource/<identity>` owns read-only lookup behavior.
- Avoid shared `utils`, `common`, generic models, or resource logic in the API client.

## Schema And Values

- Classify each attribute as required, optional, computed, optional+computed, sensitive, replacement-triggering, or write-only according to real lifecycle.
- Preserve framework null/unknown/known states. Conversion helpers return diagnostics rather than guessing zero values.
- Use validators for lexical/domain constraints and plan modifiers only when they express stable lifecycle behavior.
- Apply semantic equality for normalized URLs, sets, timestamps, or unordered values only when the backend contract guarantees equivalence.
- Do not store server defaults in plan as user intent. Read must converge state without producing inconsistent final plans.
- Schema descriptions explain behavior and security consequences, not implementation details.

## CRUD And Identity

- Create sends only known configured fields, records stable remote identity as soon as it exists, then reads canonical state.
- When Create succeeds remotely but the response is lost, recover through an idempotency key or a documented lookup strategy; never create a second secret-bearing object blindly.
- Read distinguishes authoritative not-found, permission/concealment, transient failure, and decoding failure.
- Update uses current version/ETag where supported. Stale conflict returns actionable diagnostics or performs a bounded read/replan path; it never overwrites newer state silently.
- Delete is idempotent for confirmed absence and respects soft-delete semantics. Remove Terraform state only after the declared remote outcome.
- Restore is a distinct lifecycle only when the backend and Terraform model can represent it predictably.
- Import IDs are stable, documented, unambiguous, and parsed strictly. Composite IDs include every ownership dimension needed to prevent cross-Tenant lookup.

## Secrets

- Assume every ordinary sensitive attribute remains in state and plan files.
- Prefer write-only/ephemeral framework capabilities when supported by the pinned Terraform/Framework versions; otherwise document and explicitly accept state exposure before implementation.
- Creation-only secret output cannot be reconstructed by Read or Import. Separate secret rotation from ordinary drift when necessary.
- Mark diagnostics, debug logs, request dumps, examples, and test output against plaintext/ciphertext leakage.
- Rotation/revocation is never an automatic Read side effect.

## API And Retry

- M2M authentication uses the accepted Client Credentials contract and intended resource audience.
- Bound request timeouts and honor Terraform cancellation.
- Retry only explicit transient failures and idempotent operations with bounded exponential backoff/jitter.
- Do not retry 400/401/403, validation conflict, stale version, secret rotation, or ambiguous non-idempotent create without an idempotency/recovery contract.
- Redact tokens, client secrets, Authorization headers, response bodies with sensitive fields, and internal server details from diagnostics.

## Schema Evolution

- Increment schema version only with a defined state migration.
- State upgraders preserve identity and distinguish missing historical data from user-configured empty values.
- Test prior serialized state through upgrade and current Read/plan convergence.
- Breaking resource identity changes require a documented import/state migration path, not only release notes.
