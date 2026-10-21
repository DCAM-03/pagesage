# Contracts And Compatibility

## Public Surface

- Treat exported names, package entry points, constructor options, defaults, error identity, middleware behavior, storage semantics, and serialized types as public API.
- Add capability through cohesive options or methods. Avoid boolean parameter growth and catch-all configuration bags.
- Keep core packages independent of HTTP/framework adapters. React bindings consume JavaScript core; FastAPI/Django adapters consume Python core; router adapters consume Go core.
- Keep transport DTOs distinct from verified token/session context types.
- Do not export internal caches, key objects, mutable claim maps, or implementation-specific HTTP clients.
- Public errors are typed/classifiable, redact sensitive values, retain wrapped causes only through language-appropriate internal inspection, and distinguish authentication, authorization, configuration, transport, and verification failure.

## Compatibility

- Classify changes as additive, behavior-tightening, deprecated, or breaking.
- Security tightening may still be behavior-breaking; document accepted migration and avoid a silent fallback to legacy validation.
- New required claims need backend rollout and compatibility sequencing before SDK enforcement.
- Defaults must be deterministic across languages. Do not use first-match issuer/audience/client fallback when configuration is ambiguous.
- Preserve import paths and package exports. Test built artifacts, not only source aliases.
- Do not publish, tag, bump versions, or generate release notes without explicit authorization.

## Shared Vectors

Maintain shared language-neutral fixtures for:

- exact and wildcard permission matching;
- missing/malformed permissions;
- issuer, audience, `azp`/client, Application and Tenant binding;
- expiry, not-before, skew, wrong algorithm, unknown `kid`, malformed JWKS;
- SPA/WEB/NATIVE/M2M claim differences;
- revoked/deleted client and cross-Tenant denial where represented by runtime APIs;
- browser storage/reload/refresh/logout behavior when JavaScript is in scope.

Vectors contain synthetic non-secret keys/tokens and explicit expected error categories. A language adapter must not normalize a failing vector into anonymous success or empty permissions.

## API Clients

- Accept an injected base URL/transport where the established API permits testability; validate unsafe configuration at construction.
- Propagate context/cancellation and bounded timeouts.
- Retry only idempotent, explicitly retryable failures with bounded backoff and cancellation. Never automatically replay token exchange, secret rotation, or non-idempotent mutation.
- Preserve stable API status/error codes and redact bodies that may contain sensitive internals.
