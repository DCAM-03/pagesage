# Privileged Runtime And Migration Validation

Use this reference when bootstrap or migration authority differs from the runtime identity, or when work changes
database grants, row-level security, policies, views, functions, schema baselines, or service DataSources.

## Separate Authorities

- Use owner or bootstrap credentials only for schema creation, migrations, and fixtures.
- Allow owner-backed persistence for a one-time fresh-install bootstrap only as an explicit documented exception. Require
  a verified empty database, explicit bootstrap input, one atomic transaction, a bounded installation-only context,
  and a complete production-caller inventory proving the installer is the sole caller. Prohibit HTTP or scheduler
  triggers and normal-runtime fallback. Restore ordinary-role routing immediately after success or failure; do not
  broaden an ordinary runtime role merely to make installation records possible.
- Exercise claimed product behavior through the exact least-privileged runtime identity and connection path used by
  the owning service or worker.
- Assert runtime identity and relevant privilege attributes. Fail startup or readiness when the actual identity is an
  owner, superuser, bypass role, unexpected principal, or inherits prohibited authority.
- Classify owner-backed repository, application-context, HTTP, and integration checks as fixture or tooling evidence,
  not proof of runtime authorization.

## Define The Contract

Inventory production consumers before changing grants or policies. Include ORM repositories and inherited writes,
native queries, direct database access, controllers/services, scheduled jobs, workers, views, functions, and sequence
use as applicable.

Maintain a structured capability contract mapping runtime identity, object, exact operation, policy requirement,
object type, and production consumer or explicit infrastructure reason. Validate both directions: fail when a consumer
requires an undeclared capability and when the catalog grants an unused or undeclared capability.

Do not repair denied access with blanket grants, owner runtime, authorization-bypass roles, broad definer functions,
or application filters that replace the database boundary.

## Required Evidence

Select a bounded named matrix from the consumer inventory; do not run every endpoint. When applicable, include:

1. fresh installation through the production migration path;
2. upgrade from the immediately supported previous schema state;
3. exact runtime-identity assertions;
4. structured catalog validation for privileges, memberships, views, policies, and row-level security;
5. named positive business paths under real runtime identities;
6. symmetric forbidden-operation or foreign-scope negatives with before/after state equality; and
7. transaction commit, rollback, and pooled-connection reuse when connection-local authorization context is used.

For Flyway or another automatic migration runner, validate the actual migration principal before invoking the
mutation entry point such as `migrate()`. A startup or readiness check after migration is too late. Add a named
semantic negative test that supplies every prohibited principal class relevant to the project, rejects it before the
runner executes, and proves complete before/after equality for migration history and the application schema. A thrown
exception without the zero-mutation assertion is insufficient.

For the fresh-install owner bootstrap exception, prove the empty-database gate, explicit-input gate, sole production
caller, atomic success and rollback, absence of alternate runtime triggers, and ordinary-role routing after both
success and failure. Treat any owner-backed product behavior outside that bounded installation context as a blocker.

Keep applied migrations immutable. Use forward migrations for deployed databases. Compare fresh and upgrade paths
semantically rather than using dump text or byte parity. Redact failure evidence so it contains no credentials,
tokens, row values, hashes, or query parameters. Schema replay, dump/restore, compilation, static analysis, and text
scans remain supporting evidence and cannot replace least-privileged runtime behavior.
