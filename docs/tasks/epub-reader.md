# TASK-06：EPUB 渲染、目录、选词和书内能力

## 目标

实现 EPUB 可重排文本阅读体验，支持稳定打开、目录跳转、分页或滚动、样式注入、文本选择、书内搜索、书签、划线、笔记和 AI 的 renderer 事件基础。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`、`docs/05-technical-architecture.md`。
- 不做：PDF 能力、AI provider 请求、笔记页面业务。
- 约束：EPUB renderer 不直接写数据库；所有业务事件回传阅读器页面和 application 层。

## 功能范围

- EPUB 文件加载。
- Flutter-native EPUB 解析和渲染。
- Dart renderer 事件。
- href/chapter/progress 定位和恢复，CFI 可作为后续增强。
- TOC/目录解析和跳转。
- 分页和连续滚动。
- 字号、字体、行高、段距、页边距、主题。
- 文本选择菜单事件。
- 书内搜索命令和结果回传。
- 高亮注入和恢复渲染。
- renderer 错误回传。

## 实现任务

- [x] 建立 Flutter-native `EpubRendererView`，实现通用 renderer 事件接口。
- [x] `openBook` 支持本地应用库文件。
- [x] `goTo` 使用 chapter/progress 备用定位。
- [x] Dart renderer 回传 href、章节标题、百分比。
- [x] 基于 spine 章节解析基础目录。
- [x] 支持目录项点击跳转并更新当前章节高亮。
- [x] 支持分页和连续滚动模式切换。
- [x] 样式通过 Flutter 文本样式实时响应阅读设置。
- [x] 选中文本后回传 selected text、locator、excerpt。
- [x] 实现书内搜索，结果包含片段、locator、章节标题。
- [x] 支持从数据库标注恢复 EPUB 正文高亮。
- [x] 高亮点击或选中回传 annotation 相关事件。
- [x] EPUB 解析错误统一回传 renderError。

## 涉及模块和文件

- `lib/renderers/epub/epub_renderer_view.dart`
- `lib/renderers/epub/epub_document_loader.dart`
- `lib/renderers/epub/epub_document.dart`
- `lib/renderers/common/renderer_event.dart`
- `lib/features/reader/application/reader_controller.dart`
- `test/renderers/epub/`

## 数据与接口

- TOC item 需要包含 title、href、level、children。
- 搜索结果需要包含 query、snippet、locator、chapterTitle、sortOrder。
- 文本选择事件需要包含 selectedText、locator；sourceRect 可作为后续桌面菜单定位增强。
- annotation 渲染数据来自 `annotations` 表，不由 renderer 自行决定持久化。

## UI 与交互

- 移动端支持左右点击区域或滑动翻页，滚动模式下上下滚动。
- 桌面端支持鼠标滚轮、方向键、PageUp/PageDown、点击左右边缘。
- 目录面板展示层级，当前章节高亮。
- 阅读设置调整实时生效，位置尽量保持在当前段落附近。
- 代码块使用等宽字体并保持可读背景。

## 验收标准

- [x] 常规 EPUB 可以打开并阅读。
- [x] 修改字号、行高、主题后正文实时更新。
- [x] 关闭后能恢复到章节附近。
- [x] 目录项能跳转并高亮当前章节。
- [x] 选中文本能触发 Dart 事件。
- [x] 书内搜索结果能跳转。
- [x] 已保存高亮重启后仍显示。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 本轮已验证：`dart format lib/features/reader/presentation/reader_page.dart lib/renderers/epub/epub_renderer_view.dart`、`flutter analyze`、`flutter test -r expanded`、`flutter build windows --debug`。
- 当前实现说明：EPUB 阅读器使用 Flutter 原生渲染；阅读模式切换按钮已加入阅读器顶部工具栏，可在连续滚动和分页阅读之间切换。分页模式使用 `PageScrollPhysics` 做一屏一页吸附，支持 Left/Right、PageUp/PageDown 和左右边缘点击翻页；左右边缘翻页控件默认弱化显示，鼠标悬停时增强，降低阅读干扰。
- 手动样本：标准 EPUB、大型 EPUB、带图片 EPUB、含代码块 EPUB、目录层级 EPUB。
- 平台验证：Windows 和 Android 均需打开、跳转、选词、保存恢复；EPUB 不依赖 WebView。

## 依赖与风险

- 依赖：TASK-05 阅读器核心，TASK-08 阅读设置，TASK-11 高亮数据，TASK-13 书内搜索。
- 风险：不同 EPUB 的 spine、href 支持不一致，必须保留 chapter/progress 备用定位。
- 风险：Flutter-native 文本渲染对复杂 EPUB CSS 支持有限，需要通过样本库持续验证。
