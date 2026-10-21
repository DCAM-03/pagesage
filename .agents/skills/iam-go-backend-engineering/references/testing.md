# Backend Testing

## Match Evidence To Risk

| Change | Minimum focused evidence |
| --- | --- |
| Pure domain invariant | Named unit/table test with invalid boundaries |
| Service transition | Service test covering success, stale state, deleted parent, nil actor, and audit/transaction result |
| Ent store/query | Real PostgreSQL fixture including constraint/error translation |
| HTTP DTO/error mapping | `httptest` handler test for strict decoding and stable envelope |
| Auth/permission/tenancy | Production router, real signed JWT, real service/store/PostgreSQL path |
| OIDC/token behavior | Production OIDC HTTP flow with real code/token or client-credentials exchange and official verifier |
| Migration | Fresh, historical forward, replay, invalid legacy data, raw SQL bypass, and rollback fixtures |

## Test Construction

- Name the invariant and scenario; avoid one giant lifecycle test that hides the failed contract.
- Use the real production router for middleware claims. Handler-direct tests remain useful only for handler-local behavior.
- Use deterministic key pairs, clocks, IDs, and fixtures. Do not weaken validation to simplify tests.
- Assert both positive output and forbidden disclosure. Secret tests inspect subsequent reads, lists, errors, logs/records where available, and serialized payloads.
- For 500 redaction, trigger a real lower-layer failure and assert exact external status/envelope plus absence of SQL, Ent, driver, table, ciphertext, plaintext, and token details.
- Cross-Tenant tests distinguish owner Tenant, granted Tenant, unrelated Tenant, Admin read, and Admin write permissions.
- Token matrices cover SPA, WEB, NATIVE, M2M, refresh, revoke/logout, CORS, wrong client, wrong audience, stale/revoked secret, replay, and deleted relationships as applicable.
- Race tests are required for shared caches, token/JWKS paths, mutable stores, and all focused packages changed by non-trivial work.

## Completion

Focused evidence comes first. Repository-wide race tests and vet detect collateral regressions but do not replace named runtime fixtures. Record exact commands, test names, runtime dependencies, and counts in the task execution record.
