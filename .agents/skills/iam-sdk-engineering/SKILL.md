---
name: iam-sdk-engineering
description: Implement or review Axis IAM Go, JavaScript, Python, and demo SDK work. Use for public APIs, JWT/JWKS verification, middleware, React bindings, browser sessions, permissions, compatibility, packaging, or shared vectors.
---

# IAM SDK Engineering

Read `sdk/AGENTS.md`, the language SDK's nearest `AGENTS.md`, the authoritative backend token/API contract, and the active task. SDK code is a public compatibility surface; coordination, versioning authorization, publishing, and acceptance remain outside this skill.

## Select References

| Work | Read |
| --- | --- |
| Public API, package boundaries, compatibility, errors, shared vectors | `references/contracts-and-compatibility.md` |
| JWT/JWKS, claims, middleware, browser sessions and storage | `references/token-and-session-security.md` |
| Go, TypeScript/React, Python implementation and test gates | `references/language-lanes.md` |

## Required Workflow

1. Confirm the actual SDK Git root. `sdk/` is a coordination parent; language SDKs may be independent repositories or design-only directories.
2. Identify the authoritative contract and every affected runtime: server middleware, browser core, React adapter, Python framework adapter, demo, and shared vector.
3. Freeze the public signature, defaults, errors, claim requirements, storage behavior, and compatibility impact before editing.
4. Keep protocol verification in a framework-neutral core. Adapters translate framework requests/responses without weakening verification.
5. Reuse shared contract vectors across languages. Language-specific tests may add cases but must not redefine wildcard, audience, tenant, or error semantics.
6. Prove package build/export behavior in addition to source tests. Run the exact language gate from the nearest `AGENTS.md`.
7. For JWT/JWKS, claims, permission matching, browser storage, refresh, logout, revocation, or secret handling, run `python3 .codex/scripts/audit_high_risk_surfaces.py .` from the coordination root and classify its findings as review candidates rather than proof of defects.

## Non-Negotiable Boundaries

- Verification is fail closed. Decoding is not verification.
- Issuer, resource audience, authorized party/client, Application and Tenant binding follow the accepted backend contract.
- Algorithm allowlists are configuration/contract, never token-header choice.
- Permission checks use exact accepted `resource:action` semantics and shared vectors.
- Framework adapters remain thin and do not fork security behavior.
- Browser storage, reload, refresh, logout, and revocation behavior is a public API contract, not an implementation detail.
- Never expose tokens, secrets, signing material, raw claims, or internal transport failures in logs/errors by default.
- Preserve compatibility unless the task explicitly defines a breaking release and migration path.
