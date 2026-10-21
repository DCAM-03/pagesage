---
name: iam-web-engineering
description: Implement or review Axis IAM Portal and Admin React/TypeScript work. Use for routes, features, TanStack Query, API clients, browser authentication, secret handling, UI state, accessibility, tests, or browser E2E.
---

# IAM Web Engineering

Read `axis-iam-web/AGENTS.md`, the owning application's nearest `AGENTS.md`, active task, package manifest, and backend contract before editing. This skill owns implementation discipline; coordination and acceptance remain with `project-coordination`.

## Select References

| Work | Read |
| --- | --- |
| TypeScript, React, feature organization, state and component design | `references/react-typescript-architecture.md` |
| API DTOs, OIDC browser session, permissions, secret handling | `references/browser-auth-and-api.md` |
| Unit, integration, accessibility, responsive and live browser gates | `references/testing.md` |
| Visual design, interaction refinement, prototype parity, or design review | `references/design-workflow.md` and coordination-root `axis-iam-web/DESIGN.md` |

## Required Workflow

1. Confirm each writable application Git root and branch. The joint `axis-iam-web` directory is a coordination parent, not a shared Git repository.
2. Read backend handlers/DTOs or the accepted contract. Do not infer fields from UI mock data or another frontend.
3. Identify the owning feature and keep route component, feature UI, hooks, query keys, API adapter, tests, and mocks close to that owner.
4. Model server state with TanStack Query and local interaction state with React. Use global client state only for truly cross-route client-owned state.
5. Freeze loading, empty, error, forbidden, stale-conflict, deleted, and success states before implementation.
6. For authentication, authorization, redirects, tokens, or secrets, read the browser security reference and test the production login/router path.
7. Run focused named tests, `typecheck`, lint with zero new errors/warnings in changed code, production build, `git diff --check`, and the declared browser gate.
8. For authentication, authorization, Tenant boundaries, tokens, secrets, redirects, browser storage, or permission matching, run `python3 .codex/scripts/audit_high_risk_surfaces.py .` from the coordination root and classify its findings as review candidates rather than proof of defects.

## Non-Negotiable Boundaries

- Portal is Tenant Admin self-service; Admin is Platform governance. Similar screens do not share authority semantics.
- Backend JSON remains `snake_case`; conversion to frontend naming occurs only at a consistent API boundary.
- Never use `any` to suppress an unknown contract. Parse untrusted data from `unknown`.
- Effects synchronize external systems; they do not derive render state or perform ordinary server fetching.
- Do not persist access tokens, refresh tokens, authorization codes, PKCE verifiers, or plaintext client secrets unless an accepted security contract explicitly requires and threat-models it.
- One-time secrets appear only in the mutation result UI and are removed from memory on dismissal/navigation; they do not enter query cache, storage, URL, analytics, or logs.
- Mocks support focused tests but never establish runtime completion.
