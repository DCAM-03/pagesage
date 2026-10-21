# Identity Security And Migrations

## Protocol And Claim Closure

Treat token production and every official verifier as one contract:

- Validate issuer exactly against configured canonical issuer behavior.
- Access Token `aud` names the resource server/Application resource audience.
- ID Token `aud` names the OIDC client; multi-audience ID Tokens require correct `azp` handling.
- Bind public `client_id`, Application, owner/granted Tenant, and resource audience through persisted relationships, not request-provided claims.
- Preserve and validate `application_id` and `tenant_id` only where the accepted contract requires them.
- Pin allowed signing algorithms. Never infer trust from token headers alone.
- Unknown `kid` may trigger one bounded JWKS refresh; cache failure, malformed keys, unsupported algorithms, and signature failure remain fail closed.
- Define clock source and bounded skew for `exp`, `nbf`, `iat`, authorization code expiry, refresh expiry, and revocation tests.
- Do not let Access Token and ID Token audience depend on renderer call order or a shared mutable audience getter.

## Client Types And Secrets

- SPA and NATIVE are public clients: no client secret, Authorization Code + PKCE, exact redirect validation.
- WEB uses Authorization Code + PKCE and confidential authentication where the accepted contract requires it.
- M2M uses Client Credentials, no browser redirects, no PKCE, and userless subject/claims according to contract.
- Enforce PKCE method and verifier constraints server-side. Validate `state`/`nonce` lifecycle where owned by the server.
- Hash or encrypt secrets only through the established primitive. Creation/rotation may return plaintext exactly once; reads, lists, logs, audit payloads, and later errors never do.
- Rotation, revocation, restore, and delete are explicit state transitions with optimistic locking. Lost-commit or post-write response failure must not mint and return an untracked replacement secret.
- CORS and redirect allowlists derive from the resolved ApplicationClient, not legacy Application fallback fields.

## Authorization, Tenancy, And Audit

- Authenticate before authorization; authorize before mutation.
- Portal requests operate through owner-Tenant boundaries. A Tenant grant does not confer Application ownership.
- Admin bypasses Tenant self-service scope only through explicit platform permissions; it does not bypass validation, audit, or secret disclosure rules.
- Nil/missing actor, missing permission, malformed claims, deleted parent resources, and ambiguous ownership fail closed.
- Security-sensitive lifecycle mutations record actor, target, tenant/application/client identifiers, action, outcome, and correlation metadata without secrets.
- Test seams that inject claims do not prove production JWT middleware behavior.

## Migration Discipline

- Applied SQL migrations are immutable. Add a monotonically ordered forward migration and update migration documentation.
- Define fresh database, historical upgrade, and idempotent replay behavior.
- Validate data before tightening constraints. Record deterministic policy for deleted, unmatched, duplicate, reused, or ambiguous legacy rows; never guess ownership or client identity.
- Preserve all earlier aggregate constraints when replacing a check constraint. Tests must attempt raw SQL bypasses after every forward step.
- Run migration and bootstrap under the declared migration principal. Validate that principal before the first DDL/DML mutation and prove rejection causes zero database changes.
- Runtime identities remain least privilege and cannot create/alter schema or perform owner-only bootstrap.
- Multi-step backfills and constraint changes use transactions where PostgreSQL permits; failure fixtures prove rollback rather than partial state.
- `auto_migrate` must exercise the same ordered history as production, followed by Ent alignment only when explicitly designed.
