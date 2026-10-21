# Architecture And Go

## Dependency Direction

Use the existing topology:

```text
cmd -> internal/<surface>/port -> service -> consumer contract -> adapter
                                      -> domain policy/value objects
ent schema + migrations -> persistence model
```

- Keep `cmd/<binary>` limited to process composition and startup.
- HTTP ports decode, authenticate, authorize, call use cases, and encode stable responses. They do not contain persistence queries or domain workflows.
- Services own transactions, policy orchestration, lifecycle transitions, and audit intent.
- Adapters translate external/Ent errors into domain errors and never define product policy.
- `internal/domain` remains transport- and ORM-free. Existing domain-owned store contracts may remain; new narrow contracts belong to the consuming capability when that avoids a broad central repository interface.
- Server read models under `internal/server/domain` remain intentionally narrower than Portal/Admin write models.
- Keep Portal and Admin handlers separate when actor, tenant, permission, disclosure, or audit semantics differ.

## Go Style

- Put `context.Context` first on I/O and use-case methods; never store contexts in structs.
- Return concrete implementations from constructors unless callers require substitution.
- Keep interfaces small and behavior-named. Avoid `Manager`, `Helper`, `Utils`, `Common`, and generic `Repository` packages.
- Wrap errors with operation context and `%w`. Handle/log at the terminal boundary; do not log and return the same error.
- Use `errors.Is`/`errors.As`; never branch on error strings.
- Preserve zero-value usefulness when practical. Validate required configuration explicitly at construction/startup.
- Prefer explicit domain types and state transitions over boolean combinations.
- Use table-driven tests where cases share one invariant; use named scenario tests when setup or security evidence differs.
- Use UUIDv7 through the repository's established helper. Do not introduce a second identifier generator.

## Ent And Persistence

- `ent.Schema` owns writable persistence; `ent.View` supplies compile-time read-only APIs where used. Ent Privacy is runtime policy, not compile-time isolation.
- Tenant Privacy is defense in depth. Services still establish the correct actor/tenant context and stores still scope owner-sensitive queries.
- Compose mixins according to entity semantics; do not add Tenant mixins to platform-global entities or Tenant itself merely for uniformity.
- Map not-found, uniqueness, check-constraint, optimistic-lock, and deleted-state errors deliberately.
- Use optimistic locking in the database predicate. A stale version is a conflict, never an unconditional retry.
- Keep transactions in the use-case boundary. Audit and state mutation that claim atomicity must commit or roll back together.
- Query only fields required by a read model when secret-bearing or internal fields exist.

## API And Errors

- Decode JSON strictly when the endpoint contract is strict; reject unknown fields and trailing JSON.
- Use separate create/update DTOs when writable fields differ. Do not expose `status`, `version`, type, ownership, or generated identifiers as writable by accident.
- Distinguish omitted, explicit null, empty, and zero where PATCH semantics require it.
- Keep the external error envelope stable. Map domain validation to 400, authentication to 401, permission to 403, tenant/owner concealment to the declared 404, conflict/stale version to 409, and unexpected errors to a generic 500.
- A 500 response contains no wrapped internal error text. Correlation identifiers may be returned only through the established envelope.
