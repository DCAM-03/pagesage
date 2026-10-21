# Simple Code And Explicit Fallback Discipline

Prefer direct, explicit control flow over speculative fallback, broad defensive wrapping, or clever abstraction. Apply this discipline across backend, frontend, SDK, test support, migration, and tooling code. Apply it more strictly at authentication, authorization, ownership, billing, migration, and other trust boundaries.

## Core Rules

- Keep the main path visible and short. Add an abstraction only when it removes real duplication or complexity.
- Treat missing required context as an error. Do not invent a plausible value merely to keep execution moving.
- Avoid branches for states that the product, compatibility policy, or tests do not support.
- Do not silently swallow parse, storage, network, assertion, or contract failures unless a documented degraded mode requires it.
- Prefer explicit error translation, typed result states, and precise exceptions over `null`, success-like empty objects, or broad catch-and-default behavior.
- Fail closed at trust boundaries. Do not guess a client, tenant, workspace, account, role, permission, redirect, provider, policy, resource, or owner after invalid or mismatched input.

## Allowed Fallbacks

A fallback is justified only when all of these are true:

1. It is part of a documented product or compatibility contract.
2. It preserves a safe user-visible or caller-visible behavior.
3. It exposes enough diagnostics to investigate the degraded path.
4. Tests cover both the primary path and the fallback path.

Examples include a documented configuration-inheritance chain, an explicit opt-in persistence fallback when browser storage is unavailable, a supported missing-translation policy, or runtime feature detection with a documented no-op capability.

## Suspicious Patterns

- Selecting the first related record after an identifier or context mismatch.
- Returning a success-like empty value after an HTTP, decode, storage, or domain failure.
- Catching broad exceptions and continuing with default business behavior without diagnostics.
- Masking malformed stored or API data with a DTO or UI default.
- Persisting browser tokens or permission data by default for convenience.
- Copying server or prop state into React local state and adding effects only to keep them synchronized.
- Using TypeScript `any`, optional/default objects, or arrays to avoid modeling absent or error states.
- Returning a Go or Python zero-value success after a real failure.
- Letting test helpers create runtime resources through paths unavailable in production, then using those tests as runtime evidence.

## Implementation Guidance

- Give public methods one clear meaning; split lookup and default-selection behavior when their contracts differ.
- Put a justified degraded path in a named helper and state the product reason.
- Catch only errors that can be translated, diagnosed, or retried meaningfully; otherwise rethrow or return the real error.
- Keep compatibility fallbacks linked to a task or decision and cover the compatibility boundary with a test.
- Derive React values during render when possible; use effects to synchronize with external systems.
- Narrow TypeScript `unknown` and unions explicitly instead of using `any`.
- Use precise Java/Kotlin exceptions and keep API error mapping near the boundary.
- Return real Go/Python errors unless the public contract defines a degraded result.

## Review Questions

- Does this change add first-match selection, defaulting, broad catch, `any`, empty success, or silent no-op behavior?
- Is that behavior part of a documented contract rather than a convenience?
- Does a negative test prove invalid context fails safely?
- Would a caller be surprised by the value chosen by the fallback?
- Can an operator or developer diagnose when the fallback runs?
- Can the same behavior be expressed with a shorter main path and an explicit error branch?

Scanner findings answer none of these questions by themselves. They identify places where a reviewer should ask them.
