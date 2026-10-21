# Contract Checklist

Use only the sections relevant to the changed operation or schema.

## Structure

- Route, method, version, content type, and transport match.
- Path, query, header, and body parameter names and encoding match.
- Required, optional, absent, empty, and explicit `null` remain distinct when the protocol distinguishes them.
- Enum spelling and case, timestamp format and timezone, identifiers, precision, and collection ordering match.
- Success envelope, pagination, cursor, sorting, filtering, and empty-result behavior match.
- Status codes, machine-readable error identifiers, error payloads, and validation details match.

## Behavior

- Permission success and denial behavior agree across implementations.
- Tenant, account, project, or other ownership boundaries use the product's actual model.
- Missing, forbidden, deleted, expired, disabled, conflict, and duplicate states map consistently.
- Retry, idempotency, concurrency, optimistic locking, and lifecycle transitions are explicit where relevant.
- Defaults and fallback behavior come from an accepted contract, not consumer guesses.

## Consumers

- Frontend request builders send the exact accepted payload.
- Frontend response types, forms, hooks, caches, and error handling reflect the real contract.
- Mocks and fixtures include representative success and failure behavior without becoming the authority.
- Generated clients are regenerated from the pinned source and reviewed for unexpected scope.
- Public SDK signatures, serialization, examples, and shared vectors remain compatible.
- Documentation examples use public identifiers and supported security boundaries.

## Security

- Authentication mechanism, scopes, audiences, roles, and permission semantics match.
- Browser and server-only capabilities remain separated.
- Secrets and privileged tokens are never moved into browser defaults, examples, logs, or fixtures.
- Negative cases exercise the real authorization and ownership path, not only static annotations or privileged shortcuts.

## Evidence

- Focused checks run for each changed producer and consumer.
- Strict writes exercise the real receiving endpoint with the exact emitted payload.
- Behavior parity uses shared vectors or runtime paths when multiple implementations must agree.
- Each untested consumer or external rollout gate is explicitly marked `UNVERIFIED` or `BLOCKED`.
