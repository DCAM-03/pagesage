# Code Organization And Language Style Rule

Use this rule for Go, TypeScript, React, SDK, provider, directory-layout, package-boundary, and code-organization work.

## General Organization

- Treat repository structure as an ownership and dependency tool, not a template-compliance exercise.
- Preserve a working structure unless concrete evidence shows poor cohesion, import cycles, unclear ownership, duplicated contracts, or slow feature delivery.
- Prefer incremental moves made with the feature being changed. Do not perform repository-wide directory rewrites without a dedicated task, import map, compatibility plan, and passing before/after gates.
- Keep code local until it has at least two real consumers or represents a stable cross-surface contract. Shared folders are not dumping grounds.
- Name packages and folders after product capabilities or precise technical responsibilities. Avoid catch-all `common`, `misc`, `helpers`, `utils`, `types`, or `interfaces` packages when a narrower owner exists.
- Enforce one-way dependencies and prevent feature-to-feature imports through app composition or an explicit shared contract.

## Go

- Keep multi-binary entry points under `cmd/<binary>` and non-public server implementation under `internal`.
- Keep `main` packages thin: configuration, dependency assembly, lifecycle, and process startup only.
- Preserve the backend dependency direction `port -> service -> domain`, with adapters implementing consumer-owned domain interfaces.
- Define interfaces where they are consumed; return concrete implementation types unless abstraction is part of the public contract.
- Pass `context.Context` first for request-scoped or I/O work; never store it in long-lived structs.
- Wrap errors with operational context and `%w`; inspect with `errors.Is`/`errors.As`; log or return an error, normally not both.
- Keep package names short, lower-case, and specific. Avoid stutter and generic package names.
- Use `gofmt`, `go test -race`, and `go vet`; add static/security lint gates only when the repository config actually supports them.
- Do not extract a bounded-context package if the move creates cycles or splits a cohesive transaction. Record the intended boundary and migrate when a real feature can prove it.

## TypeScript

- Keep `strict` enabled. Prefer type-aware ESLint rules where repository performance permits.
- Treat network, storage, environment, and parsed JSON as `unknown` until validated or narrowed. Do not spread unchecked `any` through application code.
- Allow `any` only in a narrow compatibility/test boundary with an inline reason and lint suppression; prefer a specific type, generic, or `unknown` first.
- Avoid unsafe `as` and non-null `!` assertions. Use runtime validation, type guards, or an explicit invariant; document unavoidable assertions.
- Use discriminated unions for state variants and string unions for closed API values unless generated contracts require another representation.
- Keep transport DTOs at the API boundary. Convert `snake_case` to domain naming once, or preserve it consistently; do not mix both shapes implicitly.
- Export the smallest public surface. Avoid broad barrel files that hide ownership or create cycles.

## React

- Keep components and hooks pure; do not mutate props/state or perform side effects during render.
- Keep state minimal and normalized. Derive values during render instead of duplicating them in state.
- Use effects only to synchronize with external systems. Use event handlers for user actions and TanStack Query for server data.
- Follow the Rules of Hooks. Do not conditionally call hooks or hide hooks inside ordinary functions.
- Use TanStack Query for server state and Zustand only for genuinely cross-route client state. Do not mirror query data into Zustand.
- Use React Hook Form's registered/uncontrolled model for native inputs and `Controller` only when a component requires controlled integration.
- Do not add `useMemo`/`useCallback` by default; use them for measured work or required identity stability.
- Co-locate feature-specific API calls, schemas, hooks, components, and tests. Promote code to shared only after the ownership is stable.
- Preserve accessibility semantics, keyboard behavior, focus management, and loading/error/empty/forbidden states.

## IAM Repository Direction

- Backend: keep `cmd`, `internal`, `ent`, and `migrations`; reduce growth of flat packages gradually by extracting coherent capabilities, not by duplicating every Clean Architecture layer per entity.
- Portal/Admin: keep independent Vite applications and route ownership; new substantial capabilities should be feature-cohesive, while `components/ui`, API transport, configuration, and test infrastructure remain shared technical layers.
- SDK JS: `packages/core` stays framework-neutral; `packages/react` may depend on core, never the reverse; examples consume public exports only.
- SDK Go: keep the root package as the public API, router adapters under `middleware`, optional clients under precise subpackages, and examples outside the library surface.
- Terraform Provider: keep `internal/client`, `internal/provider`, `internal/resource`, and `internal/datasource`; resources do not implement ad hoc HTTP clients.

See `.codex/guidance/code-organization.md` for the evidence, current assessment, and migration sequence.
