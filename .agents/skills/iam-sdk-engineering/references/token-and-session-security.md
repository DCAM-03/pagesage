# Token And Session Security

## JWT/JWKS Verification

- Require configured canonical issuer and intended resource audience. Do not accept a token solely because its signature validates.
- Validate `exp` and `nbf` with an injectable clock and bounded skew; validate `iat` where the accepted policy requires it.
- Allow only explicitly configured algorithms and key types. Reject `none`, symmetric/asymmetric confusion, unsupported curves, duplicate/ambiguous keys, and unusable JWKs.
- Select keys by `kid` and compatible algorithm/use. Unknown `kid` may cause one bounded refresh; prevent concurrent refresh stampedes.
- Define cache TTL, stale-key behavior, HTTP timeout, maximum response size, and failure policy. Network/JWKS failure remains authentication failure unless a still-valid cached key is explicitly allowed.
- Validate `azp` when multi-audience or client-bound semantics require it. Validate `application_id` and `tenant_id` against expected context when configured; never trust request-provided expected values without caller ownership.
- Return an immutable/minimal verified context rather than the original mutable claims object.

## Middleware And Authorization

- Extract bearer credentials strictly. Reject multiple/conflicting authorization values and malformed schemes.
- Attach verified context only after complete verification. Downstream permission checks consume that context.
- Authentication failure maps to 401 and an appropriate challenge; authenticated permission denial maps to 403. Avoid account/tenant enumeration details.
- Permission wildcard behavior follows shared vectors exactly. No substring, prefix-without-boundary, case folding, or empty-permission fallback.
- Framework adapters preserve cancellation and the framework's response lifecycle without swallowing downstream errors.

## Browser Session Contract

- Authorization Code + PKCE transaction data includes verifier, state, nonce when applicable, redirect target, creation time, and single-use status.
- Use CSPRNG and accepted base64url encoding. Validate callback once and erase transaction material after success or terminal failure.
- Default token storage is memory unless the public API explicitly selects another implementation. Do not silently rehydrate from local/session storage.
- Storage adapters document XSS, persistence, origin, and cross-tab tradeoffs. Mark token-bearing values sensitive and never include them in debug serialization.
- Refresh is single-flight, rotation-aware, cancellable, and cannot let an older response overwrite a newer session.
- Reload behavior is deterministic: either unauthenticated, rehydrated through an explicit adapter, or restored through a server session contract.
- Logout clears local state even when remote revoke/end-session fails, while returning a classifiable remote failure when the API contract requires it.
- React providers/hooks do not copy tokens into context values exposed to arbitrary components; expose authenticated state and commands at the narrowest useful level.
