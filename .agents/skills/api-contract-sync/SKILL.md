---
name: api-contract-sync
description: Reconcile API, schema, or event contracts across the authoritative source and every backend, frontend, mock, generated-client, documentation, and SDK consumer. Use when endpoints, DTOs, schemas, fields, enums, errors, pagination, authentication, behavior semantics, generated types, mocks, or public SDK signatures change or drift across components.
---

# API Contract Sync

Read `docs/PROJECT_PROFILE.md`, the nearest applicable `AGENTS.md`, the active task, and only the contract sources and consumers relevant to the requested change.

## Establish Authority

Identify the authoritative contract before editing. It may be accepted design documentation, OpenAPI or another schema, backend controller and DTO code, an event schema, database contract, or a task-specific decision. Do not assume the backend implementation is authoritative when an accepted contract says otherwise. Report conflicts instead of silently choosing one source.

If the contract is unresolved, use `project-coordination` to create or dispatch only the prerequisite decision or owning-component task. Do not make downstream consumers guess.

## Build The Contract Ledger

Record every applicable surface:

- operation name, route or topic, method, and version;
- path, query, header, body, and event inputs;
- response or event fields, optional/nullable semantics, enum values, dates, and numeric precision;
- status codes, error identifiers, error shape, and retry/idempotency behavior;
- pagination, sorting, filtering, lifecycle transitions, and soft-delete visibility;
- authentication, authorization, tenant or ownership boundaries, and secret/token handling;
- frontend types, forms, clients, hooks, caches, and user-visible state;
- mocks, fixtures, generated clients, SDK methods, examples, and compatibility guarantees.

Read `references/contract-checklist.md` for the detailed cross-surface audit.

## Synchronize

1. Declare the contract validation harness with the installed `validation-harness` skill before editing.
2. Capture the current authoritative source and list every affected consumer.
3. Change the owning contract surface first, unless the task explicitly follows a schema-first or compatibility-first sequence.
4. Update all affected consumers. Preserve protocol-mandated naming and do not invent envelopes, defaults, nullability, or compatibility aliases.
5. Update mocks and fixtures to model real success and failure behavior. Do not let mocks define a different product contract.
6. Update generated artifacts through their generator and record before/after scope. Do not hand-edit generated output unless project instructions explicitly require it.
7. Add shared behavior vectors when several implementations must agree, especially for permissions, lifecycle, boundary, serialization, retry, or token semantics.
8. Run focused checks for every changed consumer, then exercise the real owning runtime path for strict writes or behavior claims.
9. Record lane-specific evidence and unresolved compatibility or rollout risks in the canonical task.

## Compatibility And Sequencing

- Treat removals, renames, stricter validation, narrowed enums, changed defaults, and altered error semantics as compatibility risks even when code compiles.
- Sequence additive producer support before consumer adoption, then remove compatibility paths only after consumers and rollout evidence permit it.
- For multi-repository delivery, require accepted upstream contract evidence before dispatching dependent implementation.
- Do not claim parity from type generation, static scans, or mock tests alone when behavior is observable at runtime.

## Output

Report the authoritative source, affected consumers, contract deltas, compatibility classification, changed surfaces, validation matrix, and remaining rollout gates. Separate confirmed parity from unverified or blocked lanes.
