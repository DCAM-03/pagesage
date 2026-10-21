---
name: iam-terraform-engineering
description: Implement or review Axis IAM Terraform Provider work. Use for Plugin Framework schemas, resources, data sources, state, import, lifecycle, secrets, API retries, state upgrades, examples, or acceptance tests.
---

# IAM Terraform Engineering

Read the Provider's nearest `AGENTS.md`, current backend Open API contract, active task, and module versions before editing. This skill supplies Terraform implementation discipline; repository ownership, release, and acceptance remain coordinated separately.

## Select References

| Work | Read |
| --- | --- |
| Schema, state values, CRUD/import, secrets, retries, package ownership | `references/state-and-lifecycle.md` |
| Unit, protocol, acceptance, import, drift, upgrade and destroy gates | `references/testing.md` |

## Required Workflow

1. Confirm whether `terraform-provider-iam` is an owned Git repository. Do not create branches, commits, releases, or claim repository-level completion when ownership is absent.
2. Read the authoritative Portal Open API DTOs and lifecycle semantics before defining schema. Do not derive Provider behavior from examples or mocks.
3. Freeze Terraform state identity, import ID, null/unknown/known transitions, ForceNew/replacement semantics, sensitive/write-only behavior, timeouts, and partial-failure recovery.
4. Keep HTTP/auth/retry/error decoding in `internal/client`; resources own Terraform lifecycle mapping, and provider owns configuration/registration.
5. Implement focused unit/protocol tests, then real acceptance tests for CRUD, import, refresh, drift, conflict, destroy, and secret behavior.
6. Run `gofmt`, focused race tests, `go test ./... -race -count=1`, `go vet ./...`, `go build .`, generated-doc checks when configured, and `git diff --check`.
7. For authentication, Tenant ownership, secret/state handling, import identity, retries, delete/recovery, or resource parity, run `python3 .codex/scripts/audit_high_risk_surfaces.py .` from the coordination root and classify its findings as review candidates rather than proof of defects.

## Non-Negotiable Boundaries

- Use `types.*` or framework typed values in models; preserve null and unknown rather than coercing them to Go zero values.
- `Sensitive` redacts CLI display but does not remove a value from Terraform state. One-time plaintext secrets require an explicit state/security design.
- A 409 is not an unconditional retry. Re-read/replan or return diagnostics according to idempotency and optimistic-lock semantics.
- A 404 removes state only when authoritative Read proves the managed object is gone; authorization concealment and transient routing failures must not silently destroy state.
- Mutations with one-time outputs are not blindly replayed after ambiguous network failure.
- Import must succeed without access to creation-only secrets and converge on the same stable identity.
