# Code Organization Guidance

## Evidence Baseline

- Go's official module-layout guide recommends `internal` for non-public implementation, `cmd` as a useful convention for mixed or multi-command repositories, and notes that server repositories vary rather than following one universal template: <https://go.dev/doc/modules/layout>.
- Go Code Review Comments recommends consumer-owned interfaces, concrete implementation returns, first-parameter contexts, specific package names, and useful test failures: <https://go.dev/wiki/CodeReviewComments>.
- Uber's Go style guide reinforces handling an error once, dependency injection over mutable globals, and using functional options only for genuinely extensible public constructors: <https://github.com/uber-go/guide/blob/master/style.md>.
- TypeScript `strict` enables the strict type-checking family; `unknown` is safer than `any` because it requires narrowing: <https://www.typescriptlang.org/tsconfig/strict.html> and <https://www.typescriptlang.org/docs/handbook/2/functions.html#unknown>.
- React requires pure components/hooks, recommends minimal non-duplicated state, and treats Effects as synchronization with external systems rather than a default data-flow mechanism: <https://react.dev/reference/rules/components-and-hooks-must-be-pure>, <https://react.dev/learn/choosing-the-state-structure>, and <https://react.dev/learn/you-might-not-need-an-effect>.
- Community feature-first references favor co-locating feature API/UI/model code and one-way dependencies, but explicitly recommend incremental adoption only when the current structure causes problems: <https://github.com/alan2207/bulletproof-react/blob/master/docs/project-structure.md> and <https://feature-sliced.design/docs/get-started/overview>.

There is no single official React or TypeScript application directory tree. Use the sources above as principles, then optimize for this workspace's ownership and product boundaries.

## Current Assessment

### Backend

Keep:

- `cmd/iam-server`, `cmd/iam-portal`, `cmd/iam-admin`, and `cmd/iam-cli` correctly represent multiple commands.
- `internal/` correctly protects non-public server implementation.
- root `ent/` is generated ownership, while `migrations/` is explicit database history.
- Portal and Admin ports remain separate because their authorization and tenancy boundaries differ.

Watch:

- `internal/domain`, `internal/adapter/entstore`, and the larger `*/service` and `*/port` packages are becoming broad ownership areas.
- A global extraction by entity would create churn and can introduce cycles around Tenant, Application, Grant, audit, and transactions.

Direction:

- Keep the current top-level tree.
- For a new or heavily changed capability, first identify one cohesive domain contract and its consumers.
- Extract a capability package only when it reduces a real flat-package problem and keeps import direction acyclic.
- Keep Portal/Admin handlers in their owning ports; share a service only when behavior is intentionally identical.
- Do not add generic `util`, `common`, `types`, `interfaces`, or `repository` packages.

### Portal And Admin

Keep:

- Two independent Vite applications match separate deployment and product ownership.
- `routes/<capability>` already provides useful route ownership.
- `components/ui`, API transport, stores, test setup, and i18n are valid technical shared areas.

Watch:

- Large global `api`, `hooks`, and `components` folders make feature ownership less visible.
- Moving immediately to a complete Feature-Sliced Design tree would be expensive and unnecessary.

Incremental target:

```text
src/
  app/                 # router, providers, bootstrap, global styles
  routes/              # route entry/composition and route-local UI
  features/<feature>/  # reusable business action: api, model/schema, hooks, ui, tests
  shared/
    api/                # transport client, shared envelopes, generated/raw DTO contracts
    ui/                 # design-system primitives only
    lib/                # domain-neutral utilities
    config/
    test/
```

Adoption rules:

1. Do not move unchanged files merely to match this tree.
2. Keep route-only code under its route.
3. Move a reusable business action to `features` only when at least two routes need it or it has a stable standalone contract.
4. Move code to `shared` only when it is domain-neutral or a deliberate shared transport/design-system contract.
5. Compose features in routes/app; avoid direct cross-feature imports.
6. Add import-boundary linting only after the target paths exist and the current code can pass incrementally.

### SDKs And Provider

- SDK Go's root package is appropriately small and public; `middleware`, `pkg/authz`, and `examples` are reasonable. Avoid mirroring backend internals.
- SDK JS is already a package workspace. `packages/core` must stay React-free and `packages/react` must consume only core public contracts.
- Terraform Provider's current split into `internal/client`, `provider`, `resource`, and `datasource` is better than the older flat-provider documentation and should remain.

## Review Method

For any proposed structure change:

1. Record the current dependency and ownership problem.
2. List affected imports, public exports, tests, build aliases, mocks, and generated files.
3. Classify each path as `keep`, `move-with-feature`, `extract-after-second-consumer`, or `remove`.
4. Prefer a narrow migration that leaves compatibility imports only when consumers cannot move atomically.
5. Run the owning repository's complete gate; directory movement alone is `TOOLING_ONLY` unless real behavior was also exercised.
