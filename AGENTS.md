# PageSage Agent Guide

## Project Context

PageSage is a local-first, cross-platform intelligent reader for EPUB and PDF. The first implementation target is Flutter for Android and Windows, and the Flutter project now lives at the repository root.

Primary product constraints:

- Local-first by default: books, notes, annotations, progress, and search data stay on device.
- AI is user-triggered only. Never upload a whole book automatically, and always make the AI context range explicit.
- The MVP is the reading loop: import EPUB/PDF, open, read, save progress, reopen at the saved location.
- MOBI/AZW support and Calibre `ebook-convert` integration are deferred. Do not implement or document them as part of the current milestone unless the roadmap is explicitly changed.
- Do not add cloud sync, accounts, DRM bypass, scanned-PDF OCR, online bookstores, or collaboration features unless the roadmap is intentionally changed.

## Source Of Truth

Read the project docs before changing behavior:

- `docs/00-overview.md` for project scope and decisions.
- `docs/01-product-requirements.md` for MVP, privacy, platform, and business rules.
- `docs/02-feature-spec.md` for feature flows and acceptance criteria.
- `docs/03-interaction-spec.md` for mobile and desktop interaction patterns.
- `docs/04-ui-design-system.md` for visual design and accessibility rules.
- `docs/05-technical-architecture.md` for layers, modules, renderer bridge, AI abstraction, and tests.
- `docs/06-data-model.md` for Drift/SQLite schema, locators, migrations, and deletion rules.
- `docs/07-roadmap.md` for milestone order and Definition of Done.
- `docs/assets-plan.md` for image asset policy.

If implementation and docs disagree, pause and update the relevant doc or call out the mismatch before expanding the behavior.

## Architecture Rules

- Use Flutter and Dart. Prefer Riverpod for state management, go_router for navigation, Drift over raw SQLite access, and SQLite FTS5 for search.
- Keep dependencies flowing through the intended layers: Presentation -> Application -> Domain; Data and Renderer depend on Domain contracts, not UI.
- UI must not call DAOs directly. Controllers/use cases coordinate repositories and services.
- WebView renderers must not write business data. EPUB/PDF JS bridges emit events; Dart persists progress, bookmarks, annotations, and settings.
- Represent reading positions with stable locator objects: EPUB CFI plus href/chapter/progress fallback, PDF page plus scroll/zoom.
- Use UUID string primary keys, Unix milliseconds for timestamps, and JSON text only for structured locator/settings values that need flexible schema.
- Every released schema change needs a Drift migration. Do not clear user data as a migration shortcut.
- File import must copy books into the app library directory. Removing a book from PageSage must not delete the user's original file path.
- Store API keys only in secure storage. Never log API keys, AI request payloads, selected book text, or full AI context by default.

## UI And UX Rules

- Build the product experience, not a marketing page. PageSage should feel like a quiet, durable reading and knowledge tool.
- Favor dense but readable operational UI on desktop, and touch-first single-column flows on mobile.
- Use common controls: icon buttons for tools, menus for option sets, sliders/inputs for numeric reader settings, tabs for side panels, and confirmations for destructive actions.
- Do not use large decorative gradients, gradient orbs, oversized rounded cards, nested cards, or illustration-heavy layouts in core app screens.
- Keep reader content primary. Toolbars on mobile should hide during reading and never permanently cover text.
- All icon-only buttons need semantic labels and tooltips where the icon is not obvious.
- Preserve accessibility: WCAG AA contrast, keyboard navigation on desktop, visible focus, screen-reader labels, and non-color-only status indicators.

## Verification

- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter doctor -v` for environment checks.
- For platform changes, manually verify at least Windows plus one Android target when available.

For renderer work, add focused manual validation with real EPUB/PDF samples: open, navigate, receive location events, save progress, close, and reopen at the same location.

## MCP Usage

Project MCPs are declared for both Codex and Claude Code:

| Tool | Config |
| --- | --- |
| Codex | `.codex/config.toml` |
| Claude Code | `.mcp.json` (+ approval in `.claude/settings.json`) |

Servers:

- `openaiDeveloperDocs`: use for current OpenAI/Codex/API guidance before changing AI provider behavior or Codex/Claude project configuration.
- `dart`: use for Dart/Flutter analysis, package lookup, formatting, tests, device/app inspection, and dependency work.

MCP tools may require a new agent session after installation or configuration changes. For Claude Code, unapproved project servers show as pending until workspace trust / `/mcp` approval.

## Collaboration Rules

- Keep documentation in Chinese unless a file already uses English for a specific purpose. Code identifiers should remain English.
- Keep implementation changes scoped to the current milestone. For now, prefer M0 and M1 work unless the user asks otherwise.
- Do not overwrite `docs/` when running Flutter scaffolding. If using `flutter create .`, inspect generated file conflicts first.
- Prefer small, verifiable slices: one feature path, its data model, and its tests/manual checks.
- Do not introduce large packages without explaining why they are needed and how they affect Android and Windows.
