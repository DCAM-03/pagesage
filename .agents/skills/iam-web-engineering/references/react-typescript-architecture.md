# React And TypeScript Architecture

## Ownership And Imports

- Keep route entry files thin: route params, loader boundary when used, feature composition, and page-level error handling.
- Put feature-specific components, hooks, schemas, query keys, and tests under the owning route/feature. Promote to `shared` only after a stable second consumer with identical semantics exists.
- Shared UI primitives contain presentation and accessibility behavior, not IAM product policy or API calls.
- API transport owns base URL, credentials/token attachment, JSON decoding, and normalized external errors. Feature adapters own endpoint DTO mapping.
- Avoid catch-all `utils`, `helpers`, `common`, `types`, or giant shared hook directories.
- Keep Portal and Admin source independent. Cross-application sharing requires an explicit package/contract task, not relative imports across Git roots.

## TypeScript

- Keep strict mode enabled. Do not loosen compiler options for one feature.
- Treat network responses, storage, postMessage, URL parameters, and decoded JWT payloads as `unknown` until validated.
- Prefer discriminated unions for lifecycle and request states over optional-property combinations.
- Keep assertions local and justified by an invariant the compiler cannot express. Do not double-cast through `unknown`.
- Use `satisfies` for checked configuration and fixture shapes without widening literals.
- Preserve absence semantics: omitted, `null`, empty string, and zero are not interchangeable.
- Keep generated/backend DTOs separate from view models when naming, dates, enums, or optionality differ.

## React

- Components and hooks are pure. Never mutate inputs, Query cache objects, or module globals during render.
- Compute derived values during render or with `useMemo` only for expensive referentially stable computation, not as a default.
- Use Effects only for subscriptions, timers, browser APIs, focus, and other external synchronization. Include cleanup and complete dependencies.
- Avoid copying Query data into local state. For editable forms, initialize an explicit draft at a documented transition and handle upstream version changes.
- Keep event handlers responsible for user commands. Do not encode a click workflow as a state flag watched by an Effect.
- Use Error Boundaries for render failures and explicit inline states for recoverable request failures.

## Server And Form State

- Define query keys in the owning feature and include every scope dimension: tenant, application, client, filters, page, and sort.
- Cancel or invalidate only affected queries. Never update unrelated caches to make a screen appear current.
- Mutations handle 409 separately from validation and transport failures. Do not automatically overwrite stale versions.
- Use React Hook Form and schema validation where established. Server remains authoritative; client validation improves feedback but cannot expand accepted input.
- Reset forms and secret/result state deliberately after successful transitions.

## UI Quality

- Use semantic elements, labels, descriptions, table headers, dialogs, and live regions before adding ARIA.
- Every interaction must work by keyboard with visible focus. Dialog open/close restores focus appropriately.
- Use established icon and component libraries. Icon-only controls require accessible names and tooltips when meaning is not universal.
- Keep compact operational layouts; avoid nested cards, decorative sections, or oversized headings in management surfaces.
- Define stable dimensions for tables, toolbars, dialogs, and repeated controls so loading and error content do not shift the layout.
- Dynamic branding styles may use narrowly scoped inline custom properties; ordinary styling follows the established Tailwind/component system.
