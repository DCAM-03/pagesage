# Simple Code And Explicit Fallback Discipline

Prefer direct, explicit control flow over speculative fallback, broad defensive wrapping, or clever abstraction.
Apply this discipline across reader, database, renderer bridge, AI, and test-support code. Apply it more strictly at
persistence, privacy, secure-storage, and file-deletion boundaries.

## Core Rules

- Keep the main path visible and short. Add an abstraction only when it removes real duplication or complexity.
- Treat missing required context as an error. Do not invent a plausible value merely to keep execution moving.
- Avoid branches for states that the product, compatibility policy, or tests do not support.
- Do not silently swallow parse, storage, network, assertion, or contract failures unless a documented degraded mode
  requires it.
- Prefer explicit error translation, typed result states, and precise exceptions over `null`, success-like empty
  values, or broad catch-and-default behavior.
- Fail closed at trust boundaries: corrupt book file, unreadable database, missing secure-storage key, invalid
  locator, failed import copy, and failed deletion.

## Allowed Fallbacks

A fallback is justified only when all of these are true:

1. It is part of a documented product or compatibility contract.
2. It preserves a safe user-visible or caller-visible behavior.
3. It exposes enough diagnostics to investigate the degraded path.
4. Tests cover both the primary path and the fallback path.

Examples include a documented locator fallback when a CFI no longer resolves, an explicit missing-translation
policy, a supported renderer-capability no-op, or a best-effort platform call whose failure is already surfaced in
the UI.

## Suspicious Patterns

- Selecting the first related record after an identifier or context mismatch, such as falling back to the first book
  when a stored ID no longer exists.
- Returning a success-like empty value after a read, decode, storage, or domain failure.
- Catching broad exceptions and continuing with default business behavior without diagnostics.
- Masking malformed persisted or API data with a default value or an enum `orElse`.
- Persisting API keys or secrets anywhere except secure storage.
- Copying provider or widget state into local state and adding effects only to keep them synchronized.
- Using `??` with a plausible default to avoid modeling an absent or error state.
- Returning an empty list or `null` after a real failure.
- Letting test helpers create runtime resources through paths unavailable in production, then using those tests as
  runtime evidence.

## Implementation Guidance

- Give public methods one clear meaning; split lookup and default-selection behavior when their contracts differ.
- Put a justified degraded path in a named helper and state the product reason.
- Catch only errors that can be translated, diagnosed, or retried meaningfully; otherwise rethrow or return the real
  error.
- Keep compatibility fallbacks linked to a task or decision and cover the compatibility boundary with a test.
- Derive values during build/render when possible; use effects to synchronize with external systems, not to derive
  state.
- Narrow nullable and sealed types explicitly instead of defaulting early.
- Use precise Dart exception types around platform and database boundaries and keep error mapping near the boundary.
- Never log API keys, selected book text, or full AI context, even inside an allowed degraded path.

## Review Questions

- Does this change add first-match selection, defaulting, broad catch, empty success, or silent no-op behavior?
- Is that behavior part of a documented contract rather than a convenience?
- Does a negative test prove invalid context fails safely?
- Would a caller be surprised by the value chosen by the fallback?
- Can an operator or developer diagnose when the fallback runs?
- Can the same behavior be expressed with a shorter main path and an explicit error branch?

Scanner findings answer none of these questions by themselves. They identify places where a reviewer should ask them.
