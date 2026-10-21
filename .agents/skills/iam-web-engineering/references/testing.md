# Frontend Testing

## Evidence Layers

| Risk | Evidence |
| --- | --- |
| Pure mapping/schema | Named unit tests with valid and invalid DTOs |
| Hook/query behavior | RenderHook/component test with real QueryClient and MSW contract payloads |
| Form/lifecycle UX | User-event test covering validation, loading, 409, forbidden, success, and secret clearing |
| Routing/auth guards | Application router test, not an isolated component prop |
| Browser auth/permissions | Live backend plus production frontend router and real Authorization Code + PKCE identity |
| Responsive/accessibility | Playwright desktop/mobile screenshots plus keyboard/focus assertions |

## Test Rules

- Query by role, name, label, and visible state. Avoid implementation selectors unless no semantic surface exists.
- Use `userEvent` for interaction. Assert observable behavior rather than hook internals.
- MSW handlers reproduce backend status, envelope, omission, and pagination. Add negative handlers for 400, 401, 403, 404, 409, and sanitized 500 when relevant.
- Use a fresh QueryClient per test and disable/reduce retry deterministically. Assert cache behavior explicitly for secrets and scoped keys.
- Keep time, crypto, and random behavior deterministic without replacing the production validation path.
- A component test with injected claims does not prove production OIDC middleware or browser callback behavior.

## Live Browser Matrix

For privileged ApplicationClient work, include as applicable:

- Portal owner Tenant with manage permission.
- Portal owner Tenant with read-only permission.
- Granted and unrelated Tenant denial/concealment.
- Admin read-only and Admin manage identities.
- SPA, WEB, NATIVE, and M2M configuration visibility and permitted actions.
- Create/rotate one-time secret, subsequent non-disclosure, revoke, delete, restore, stale update, and logout/session expiry.
- Desktop and mobile viewport checks with no overlap, clipping, inaccessible dialog content, or hidden primary actions.

Record exact URL, backend revision, frontend revision, identity/permission fixture, browser, viewport, named scenarios, and screenshots. A dev server starting successfully is not E2E evidence.
