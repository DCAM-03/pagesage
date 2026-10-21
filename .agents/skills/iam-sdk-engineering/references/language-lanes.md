# Language Lanes

## Go SDK

- Keep the stable public package at the module root; adapters live in specifically named subpackages.
- Use consumer-owned narrow interfaces, first-parameter contexts, `%w`, `errors.Is/As`, and immutable verified context values.
- Use `net/http` compatibility unless the public contract deliberately introduces another transport.
- Tests include table/vector tests, `httptest` JWKS rotation/failure, middleware integration, race detection, examples, `go vet`, and `go build`.

## JavaScript And React SDK

- Keep strict TypeScript and `noUncheckedIndexedAccess`. Parse untrusted data from `unknown`; localize unavoidable assertions.
- Core has no React dependency and must remain usable in browser/server contexts declared by package exports.
- React bindings are thin, SSR-safe, and React 18/19 compatible where promised. Effects synchronize subscriptions/session lifecycle and clean up correctly.
- Define ESM/CJS/browser/Node exports explicitly and test consumers against built package output.
- Use a real lint implementation. A script that prints `no lint configured` is not a quality gate.
- Tests cover vectors, storage/rehydration, concurrent refresh, unmount/cancellation, SSR import, package exports, bundle budget, and demo integration when affected.

## Python SDK

- Do not claim an implementation gate until `pyproject.toml`, source package, tests, and build metadata exist in an owned Git repository.
- Use Python 3.12+, complete type hints, strict type checking, Ruff formatting/linting, and explicit async/sync APIs.
- Keep core independent of FastAPI and Django. Framework packages adapt verified context and exceptions without duplicating JWT logic.
- Use immutable dataclasses or equivalent typed models for verified context and classifiable exception types.
- Tests cover shared vectors, HTTP/JWKS behavior, async cancellation, FastAPI/Django integration, wheel/sdist build, and typed public imports.

## Completion Across Lanes

A language implementation reaches runtime evidence only when its real middleware/client/session path passes named tests. Cross-language completion requires the same accepted vectors in every declared language and at least one real backend/demo lane when interoperability is in scope.
