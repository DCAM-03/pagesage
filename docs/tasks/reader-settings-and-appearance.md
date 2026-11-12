# TASK-08：阅读设置、主题、字体和外观

## 目标

通过设置页和书内面板调整共用的全局阅读设置，包括字号、字体、行高、段距、页边距、背景、文字色、主题、阅读模式和 PDF 缩放偏好，并持久化到本地。当前没有单书覆盖。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`、`docs/06-data-model.md`。
- 不做：自定义字体导入、复杂翻页动画。
- 约束：设置变更实时生效；敏感设置不进入普通日志。

## 功能范围

- 全局阅读默认设置。
- 单本书设置覆盖策略留待后续，本轮不新增存储。
- 应用主题：跟随系统、亮色、暗色。
- 阅读主题：白昼、纸张、夜间、护眼、高对比。
- EPUB 文本选项。
- PDF 缩放和布局偏好。
- 设置页和阅读器设置面板。
- 设置持久化和恢复。

## 实现任务

- [x] 定义 `ReaderSettings` domain model。
- [x] 在 `app_settings` 中保存非敏感设置。
- [ ] 单书覆盖及合并规则（后续；当前两个入口共用全局设置）。
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
- `lib/features/reader/presentation/reader_settings_sheet.dart`
- `lib/features/settings/presentation/reader_font_picker.dart`
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
- 两个入口复用字体选择器：系统默认、内置字体和已安装的自定义字体名称；不导入字体文件。
- 移动端设置面板使用底部抽屉。
- 桌面端设置面板可放在右侧上下文面板。
- 桌面右侧工具页签（搜索、笔记、AI）与开合、宽度一并持久化；重开阅读器恢复最后使用的工具（2026-11-09）。
- 调整设置时当前位置尽量保持在当前段落或页面附近。

## 验收标准

- [x] 设置变更立即影响当前阅读器。
- [x] 重启后全局设置保持。
- [x] 新打开书籍使用默认阅读设置。
- [x] 高对比主题文字可读。
- [x] EPUB 字号和行高变化不会重置到开头。
- [x] PDF 缩放设置不会永久遮挡页面内容。

## 测试与验证

- `dart format <本次修改的 Dart 文件>`
- `flutter analyze`
- `flutter test`
- Widget 测试：设置表单、主题色块、slider 边界。
- 手动验证：EPUB 字号/主题、PDF 缩放、Android 底部抽屉、Windows 右侧面板。

## 依赖与风险

- 依赖：TASK-02 设置存储，TASK-05 阅读器核心，TASK-06/TASK-07 renderer command。
- 风险：主题颜色若只按单一色系扩展，会违背 UI 规范并影响可读性。
- 风险：EPUB 样式注入可能被书籍内联样式覆盖，需要 CSS 优先级策略。

## 2026-11-10：阅读设置入口一致性

### 实施前基线与验收

- 当前基线：设置页只有字体文本框，阅读器只有内置字体选项；两处共用 `readerSettingsControllerProvider`，但“新建阅读会话”“单独切换”文案与实际全局保存不符。设置分类入口只显示静态说明。
- 待证明：两个入口均支持系统/内置/已安装的自定义字体，旧字体名称打开不被覆盖；自定义草稿明确应用，空值恢复系统字体；设置保存后另一入口和分类摘要读取同一值。
- 布局：桌面 900/1440px、窄屏 390px 及阅读面板 360/420px，包含长字体名和 1.5/2 倍文字；不启动真实窗口。
- 精确验证：新增 `test/features/settings/reader_settings_test.dart`，结合 `test/features/reader/reader_panels_test.dart`、`test/features/settings/ai_settings_card_test.dart`、`test/features/settings/settings_image_cache_test.dart`、`test/domain/books/reader_fonts_test.dart`、`test/domain/books/reader_settings_test.dart` 和 `test/widget_test.dart`。
- 证据：`/tmp/pagesage-reading-settings-*.log`，离屏图片保存于 `build/workbench-captures/reading-settings-*.png`；完成后静默构建安装并核对完整 bundle。真实窗口、真实书籍及 Windows/Android 本轮未验收。

### 实现与验证结果

- 两个入口复用 `ReaderFontPicker`，保留系统、霞鹜文楷、Atkinson 和旧自定义字体值。自定义名称通过“应用字体”或键盘完成提交，去除首尾空白；空值恢复系统默认；未应用的字体草稿不随其他阅读控件保存而丢失，重复选择当前字体不触发保存。
- 明确两处修改同一份全局设置，对当前及后续打开的书籍生效；文本字体和排版用于 EPUB/Markdown，PDF 保留文档字体。没有新增单书覆盖、字体文件导入、依赖或数据库结构。
- 桌面分类栏和窄屏分类列表响应已保存的字号、模式、主题和字体；加载与读取失败不伪装成默认配置。长字体名在桌面截断时可通过 tooltip 查看。
- 反例：新增内置字体选择用例在修改前失败，修改后通过，基线见 `/tmp/pagesage-reading-settings-baseline.log`。图片检查另发现 390px/2 倍文字的字体说明被固定行数截断，改为自然换行的独立说明后检查通过。
- 回归：`flutter test test/features/settings test/features/reader test/domain/books/reader_fonts_test.dart test/domain/books/reader_settings_test.dart test/widget_test.dart --concurrency=4 --reporter expanded` 最终 153 项通过；`flutter analyze` 无问题。原 PDF 页面测试仍会输出已有的 Drift 多实例调试警告，未改变相关实现或屏蔽警告。
- 离屏：`flutter test test/features/settings/reader_settings_test.dart --dart-define=CAPTURE_READER_WORKBENCH=true --concurrency=1 --reporter expanded` 13 项通过，生成 12 张图片；最终检查 7 张，包含 1440px 浅/暗色、900px/1.5 倍、390px/2 倍分类及字体区、360px/1.5 倍和 420px/2 倍面板。捕获主题仅为测试 chip 标签装载中文字体，不改应用字体配置。
- 最终日志：`/tmp/pagesage-reading-settings-{regression,analyze,visual}.log`；本次候选源文件校验存于 `/tmp/pagesage-reading-settings-source.sha256`。真实应用窗口、真实书籍及其他平台仍未验收，离屏结果不替代这些证据。
- 安装：`CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 成功，源文件校验通过，release bundle 与 `$HOME/.local/opt/pagesage` 完整目录一致；两侧 `libapp.so` SHA256 均为 `0b710022e4620a3f8b1e432f89751f51e1f73ef11514ccbbbba8634e599ad168`。构建日志位于 `/tmp/pagesage-reading-settings-install.log`；未启动、关闭或重启应用窗口。
