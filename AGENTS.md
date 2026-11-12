# PageSage Agent Guide

## Project Context

PageSage is a local-first, cross-platform intelligent reader for EPUB, PDF, and Markdown. The first implementation target is Flutter for Android and Windows, and the Flutter project now lives at the repository root.

Primary product constraints:

- Local-first by default: books, notes, annotations, progress, and search data stay on device.
- AI requests must make their context range explicit. Never upload a whole book automatically.
- The MVP is the reading loop: import EPUB/PDF, open, read, save progress, reopen at the saved location.
- Markdown reading was added by explicit request (2026-11-05, `docs/tasks/markdown-reading.md`): a single `.md` file is a book, and a folder of Markdown files is also one book (P2, read in place — see the exception below). Its reading, progress, and search behavior follow the EPUB path rather than getting its own reader.
- Read-in-place exception: a folder book is a view over the folder the writer keeps, so it is **not** copied into the library. PageSage never writes to that folder, and removing the book never deletes it. Every other import still copies into the library directory.
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

## Project Skills

当前仓库的工作流正文统一维护在 `.agents/skills/`，按本次任务选择，不要求每次加载全部 skill。
`.claude/skills/` 中的同名入口只链接共享正文，不维护第二套流程或资源副本。

| 任务 | Skill |
| --- | --- |
| 剩余工作、下一步、继续既有任务 | [workstream-triage](.agents/skills/workstream-triage/SKILL.md) |
| Dart/Flutter 功能实现、修复、编码规范 | [pagesage-dart-engineering](.agents/skills/pagesage-dart-engineering/SKILL.md) |
| 多阶段交付、任务拆分、已授权的协作和交接 | [project-coordination](.agents/skills/project-coordination/SKILL.md) |
| 选择验证、证明修复、检查构建安装证据 | [validation-harness](.agents/skills/validation-harness/SKILL.md) |
| 领域模型、Drift、定位、渲染事件或导出契约变更 | [api-contract-sync](.agents/skills/api-contract-sync/SKILL.md) |
| Dart 变更质量审查、异步和资源泄漏检查 | [code-quality-audit](.agents/skills/code-quality-audit/SKILL.md) |
| 目录、模块归属和依赖方向审查 | [review-code-organization](.agents/skills/review-code-organization/SKILL.md) |

先读取所选 skill 的 `SKILL.md`，再按其路由读取相关 reference。状态依据沿用
`docs/implementation-status.md`、`docs/tasks/` 与相关设计文档；不要求创建
`PROJECT_TASKS.md`、`PROJECT_PROFILE.md` 或迁移历史任务格式。

项目仅保留适用于 PageSage 的 skill、参考与任务模板，不放入其他项目的专属工作流。
不强制三角色会话、模型降档或自动提交；本项目不因引入工作流而取得创建会话、
委派、提交、推送、修改全局配置等额外授权。

## Architecture Rules

- Use Flutter and Dart. Prefer Riverpod for state management, go_router for navigation, Drift over raw SQLite access, and SQLite FTS5 for search.
- Keep dependencies flowing through the intended layers: Presentation -> Application -> Domain; Data and Renderer depend on Domain contracts, not UI.
- UI must not call DAOs directly. Controllers/use cases coordinate repositories and services.
- WebView renderers must not write business data. EPUB/PDF JS bridges emit events; Dart persists progress, bookmarks, annotations, and settings.
- Represent reading positions with stable locator objects: EPUB CFI plus href/chapter/progress fallback, PDF page plus scroll/zoom.
- Use UUID string primary keys, Unix milliseconds for timestamps, and JSON text only for structured locator/settings values that need flexible schema.
- Every released schema change needs a Drift migration. Do not clear user data as a migration shortcut.
- File import must copy books into the app library directory. Removing a book from PageSage must not delete the user's original file path. The one exception is a Markdown folder book, which is read in place (see Project Context) and is never copied or deleted.
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
- `dart format <changed Dart files>`; use `dart format .` only for an intentional repository-wide formatting pass.
- `flutter analyze`
- `flutter test <named test files> --concurrency=4`; choose affected behavior and dependents first. Use the full suite for an explicit full regression or release gate.
- `flutter doctor -v` for environment checks.
- After every app-affecting change, immediately rebuild and reinstall the local Linux build with `bash tool/install_linux.sh`; do not wait for a separate reminder. Do not launch a new window, and leave any already-running PageSage instance alone while telling the user to restart it.
- For platform changes, manually verify at least Windows plus one Android target when available.

For renderer work, add focused manual validation with real EPUB/PDF samples: open, navigate, receive location events, save progress, close, and reopen at the same location.

Tests and builds run silently in the existing tool session, with bounded logs and no new terminal or app window.
Use offscreen widget captures for layout checks; do not start desktop `integration_test` or a visible app without
explicit user authorization. Record unavailable real-window or platform checks as unverified. Skills/docs-only
changes do not require rebuilding the app; the reinstall rule still applies to every app-affecting change.

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
- 完成汇报聚焦本轮结果和影响交付的未决问题；已解决内容不作例行提醒。用户追问或出现新证据时按需说明相关变化。批注中引用的旧回复用于定位评论，不自动成为新增待办。
- Keep implementation changes scoped to the current milestone. For now, prefer M0 and M1 work unless the user asks otherwise.
- Do not overwrite `docs/` when running Flutter scaffolding. If using `flutter create .`, inspect generated file conflicts first.
- Prefer small, verifiable slices: one feature path, its data model, and its tests/manual checks.
- Do not introduce large packages without explaining why they are needed and how they affect Android and Windows.
