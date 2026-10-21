# TASK-08：阅读设置、主题、字体和外观

## 目标

实现全局和书内阅读设置，让用户能调整字号、字体、行高、段距、页边距、背景、文字色、主题、阅读模式和 PDF 缩放偏好，并持久化到本地。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`、`docs/06-data-model.md`。
- 不做：自定义字体导入、复杂翻页动画。
- 约束：设置变更实时生效；敏感设置不进入普通日志。

## 功能范围

- 全局阅读默认设置。
- 单本书设置覆盖策略。
- 应用主题：跟随系统、亮色、暗色。
- 阅读主题：白昼、纸张、夜间、护眼、高对比。
- EPUB 文本选项。
- PDF 缩放和布局偏好。
- 设置页和阅读器设置面板。
- 设置持久化和恢复。

## 实现任务

- [x] 定义 `ReaderSettings` domain model。
- [x] 在 `app_settings` 中保存非敏感设置。
- [x] 设计全局默认和单书覆盖的合并规则。
- [x] 阅读器设置面板支持字号、字体、行高、段距、页边距、主题、阅读模式。
- [x] 设置页支持默认字号、默认字体、默认行高、默认阅读模式。
- [x] 外观设置支持应用主题和阅读主题。
- [x] EPUB 设置实时应用。
- [x] PDF 设置通过 renderer command 应用缩放和布局。
- [x] 设置变更后 debounce 保存。
- [x] 高对比主题满足可读性要求。
- [x] 支持减少动画偏好。

## 涉及模块和文件

- `lib/domain/books/reader_settings.dart`
- `lib/domain/books/settings_repository.dart`
- `lib/core/database/drift_settings_repository.dart`
- `lib/features/settings/application/settings_providers.dart`
- `lib/features/settings/presentation/`
- `lib/features/reader/presentation/widgets/reader_settings_panel.dart`
- `lib/app/theme/app_theme.dart`
- `lib/app/theme/reader_theme.dart`
- `lib/renderers/epub/epub_renderer_view.dart`
- `lib/renderers/pdf/pdf_page_tint.dart`
- `test/domain/books/`
- `test/features/settings/`

## 数据与接口

- `app_settings` 示例 key：
  - `theme.mode`
  - `reader.defaultFontSize`
  - `reader.defaultLineHeight`
  - `reader.defaultTheme`
  - `reader.defaultMode`
  - `reader.restoreProgressOnOpen`
- 单书设置如需支持，应使用独立 key 或后续表结构，不能污染全局默认。
- Renderer command 需要区分 text options 和 theme options。

## UI 与交互

- 字号、行高、页边距使用 slider 或 stepper。
- 阅读模式使用 segmented control。
- 主题使用色块 swatch。
- 字体使用下拉菜单。
- 移动端设置面板使用底部抽屉。
- 桌面端设置面板可放在右侧上下文面板。
- 调整设置时当前位置尽量保持在当前段落或页面附近。

## 验收标准

- [x] 设置变更立即影响当前阅读器。
- [x] 重启后全局设置保持。
- [x] 新打开书籍使用默认阅读设置。
- [x] 高对比主题文字可读。
- [x] EPUB 字号和行高变化不会重置到开头。
- [x] PDF 缩放设置不会永久遮挡页面内容。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- Widget 测试：设置表单、主题色块、slider 边界。
- 手动验证：EPUB 字号/主题、PDF 缩放、Android 底部抽屉、Windows 右侧面板。

## 依赖与风险

- 依赖：TASK-02 设置存储，TASK-05 阅读器核心，TASK-06/TASK-07 renderer command。
- 风险：主题颜色若只按单一色系扩展，会违背 UI 规范并影响可读性。
- 风险：EPUB 样式注入可能被书籍内联样式覆盖，需要 CSS 优先级策略。
