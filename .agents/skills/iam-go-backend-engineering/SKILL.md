---
name: iam-go-backend-engineering
description: Implement or review Axis IAM Go backend work in axis-iam. Use for Go architecture, chi/fx services, ent schemas and stores, OIDC/OAuth token behavior, migrations, tenancy, authorization, security, API handlers, or backend tests.
---

# IAM Go Backend Engineering

Read the nearest `AGENTS.md`, active task, affected source, and current manifests before editing. This skill supplies backend engineering depth; `project-coordination` owns task creation, dispatch, acceptance, commit, and merge.

## Select References

| Work | Read |
| --- | --- |
| Packages, interfaces, service boundaries, errors, ent ownership | `references/architecture-and-go.md` |
| OIDC/OAuth, claims, secrets, tenancy, migrations, HTTP security | `references/identity-security-and-migrations.md` |
| Unit, PostgreSQL, production-router, migration, race gates | `references/testing.md` |

## Required Workflow

1. Confirm the exact Git root with `git rev-parse --show-toplevel`; it must be the authorized `axis-iam` checkout. Treat every task path as relative to that root.
2. Trace the production call path before choosing an edit location: router/port -> service -> consumer interface -> adapter/ent or OIDC storage.
3. Freeze the behavioral contract and negative cases before implementation. For public JSON, record method, path, request/response fields, omission/nullability, status, error envelope, permission, tenant scope, and lifecycle semantics.
4. Keep domain policy out of handlers and persistence details out of services. Add an abstraction only when it creates a real dependency boundary or stable second consumer.
5. For auth, tenancy, secret, token, migration, or permission work, read the security reference and use fail-closed behavior. Do not add compatibility fallback without an explicit migration contract.
6. Use the smallest named test that proves each changed invariant, then run the owning repository's required aggregate gates after focused evidence passes.
7. Run `gofmt` on changed Go files, regenerate Ent only when schemas changed, inspect generated drift, run focused `-race` tests, full `go test ./... -race -count=1`, `go vet ./...`, and `git diff --check` unless the task narrows or expands the declared gate.
8. For authentication, authorization, tenancy, token, secret, migration, audit, impersonation, recovery, or FIPS changes, run `python3 .codex/scripts/audit_high_risk_surfaces.py .` from the coordination root and classify its findings as review candidates rather than proof of defects.

## Non-Negotiable Boundaries

- Preserve Tenant as a first-class boundary. Application ownership and Tenant grants are distinct.
- Preserve three service identities: public protocol server, Tenant Portal, and Platform Admin. Shared behavior does not imply shared authorization.
- Runtime services never acquire migration-owner privileges. Automatic migration validates its principal before mutation.
- Public `client_id` and internal record UUID are different identifiers. Never silently accept one where the other is required.
- Access Token resource audience is independent from ID Token client audience.
- Never return or log plaintext secrets, ciphertext, SQL, driver, key material, tokens, or internal error details.
- Do not manually edit generated Ent files. Do not edit an applied migration; add an immutable forward migration.
- A mock, handler-only test, DTO, generated schema, or broad compile does not prove runtime behavior.
