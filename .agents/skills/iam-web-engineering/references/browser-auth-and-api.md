# Browser Authentication And API Contracts

## API Contract

- Read the authoritative backend handler, request DTO, response DTO, and error mapper before changing frontend types.
- Record method/path, auth surface, permission, tenant semantics, pagination envelope, enum values, omission/nullability, optimistic-lock version, and delete/restore behavior.
- Keep MSW payloads byte-shape compatible with backend JSON. A mock must not invent defaults, accept fields the backend rejects, or omit backend errors.
- Centralize error decoding. Preserve status and stable error code/message without exposing raw response internals to components.
- Abort in-flight requests on cancellation through the established transport.

## Authorization Code And Session

- Use Authorization Code + PKCE for browser login. Generate verifier/challenge with CSPRNG and accepted method; bind callback to stored transaction state.
- Validate `state`; validate `nonce` when ID Token processing is in scope. Treat missing, duplicate, expired, or mismatched transaction data as authentication failure.
- Redirect targets are local allowlisted paths or accepted registered origins. Never navigate to arbitrary query-provided URLs.
- Keep bearer tokens out of URLs, error messages, analytics, and logs.
- The storage/rehydration contract is explicit. Default to memory when no accepted persistence contract exists. Do not silently fall back from memory to `localStorage`.
- Refresh is single-flight per session. Concurrent 401s must not rotate the same refresh token independently or replay a stale result.
- Logout clears in-memory session state and Query cache before/while invoking the accepted server revocation/end-session behavior. Cross-tab behavior is implemented only when explicitly contracted.
- Do not decode a JWT and treat its claims as verified authorization. Browser display hints do not replace server permission checks.

## Portal And Admin Permissions

- Portal requests use the current Tenant context and owner boundaries. A granted Tenant must not acquire owner-only Application management UI or API access.
- Admin exposes platform operations only after the server-derived permission model allows them. Hiding a button is not authorization.
- Handle 401 as session/authentication state, 403 as authenticated denial, and concealment 404 as the backend contract defines. Avoid global redirects that erase the distinction needed by the feature.

## One-Time Secrets

- Model create/rotate responses separately from ordinary Client DTOs so plaintext cannot become a reusable entity field.
- Do not place plaintext in TanStack Query cache, Zustand, local/session storage, URL/search params, toast history, telemetry, console output, or reusable fixtures.
- Keep plaintext in the narrowest component state, render it only after the successful mutation, and clear it on dismissal, navigation, replacement, logout, or unmount.
- Clipboard copy is an explicit user command with failure handling; never copy automatically.
- Subsequent GET/list responses and restored page state must prove the secret is absent.
