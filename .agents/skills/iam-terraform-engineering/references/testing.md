# Terraform Provider Testing

## Test Layers

| Surface | Evidence |
| --- | --- |
| Model conversion/validators | Unit tests for null, unknown, known, invalid and normalized values |
| API client | `httptest` for auth, redaction, status mapping, timeout, retry and ambiguous mutation |
| Resource protocol | Framework protocol/unit tests for plan/state and diagnostics |
| Runtime lifecycle | `resource.Test` against a real IAM backend and PostgreSQL fixture |

## Acceptance Matrix

For every managed resource, cover as applicable:

- minimal and complete Create followed by Read convergence;
- Update of every mutable field and replacement of every immutable field;
- import with `ImportStateVerify` and no creation-only secret;
- refresh after out-of-band update and deletion;
- owner/granted/unrelated Tenant behavior and permission denial;
- stale optimistic-lock conflict without silent overwrite;
- one-time secret creation/rotation non-disclosure and state behavior;
- interrupted/partial Create recovery without duplicate remote objects;
- soft delete, restore model if supported, and final destroy;
- data source lookup ambiguity and not-found behavior;
- prior schema-state upgrade and plan convergence;
- destroy ordering for dependent resources.

## Test Rules

- Use `TF_ACC=1` only for named acceptance tests and record the exact backend revision/configuration.
- Provider factories and protocol version match the pinned framework/testing versions.
- Generate unique deterministic-enough names per test and register cleanup for remote residue.
- Never weaken authorization or use Admin credentials for a Portal-scoped acceptance path merely to make setup pass.
- Assert diagnostics do not include tokens, secrets, SQL, transport bodies, or internal server errors.
- Avoid sleeps for consistency; poll a named observable condition with deadline and cancellation when the backend is eventually consistent.
- Verify state values after every step, not only remote API existence.

Provider compilation or schema presence is `TOOLING_PASS` at most. Runtime completion requires real plan/apply/refresh/import/destroy evidence against the accepted backend contract.
