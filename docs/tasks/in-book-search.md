# TASK-13：EPUB/PDF 书内搜索

## 目标

实现当前书籍内部搜索，让用户能在 EPUB 或 PDF 阅读器中查找关键词、查看结果片段，并跳转到对应章节或页码位置。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`。
- 不做：跨书全局搜索、复杂搜索语法、OCR。
- 约束：书内搜索应优先使用 renderer 可定位能力；搜索不可用时原因明确。

## 功能范围

- 阅读器内搜索入口。
- 搜索输入、清空、结果列表。
- EPUB 搜索。
- PDF 搜索。
- 搜索结果高亮和跳转。
- 当前结果前后导航。
- 文本层缺失降级。
- 搜索状态和错误提示。

## 实现任务

- [x] 在阅读器顶部工具栏提供书内搜索入口。
- [x] 建立 `InBookSearchController` 或纳入 `ReaderController` 的独立状态。
- [x] 输入关键词后 debounce 执行搜索。
- [x] EPUB renderer 支持 `search(query)`，返回章节、片段、locator。
- [x] PDF renderer 支持 `search(query)`，返回页码、片段、locator。
- [x] 搜索结果点击后调用 renderer goTo。
- [x] 支持上一条、下一条结果导航。
- [x] 当前结果在正文中临时高亮。
- [x] 清空搜索时清除临时高亮。
- [x] PDF 无原生文本层时保留识别提示；不阻止打开本地索引搜索，已入库 OCR 文本可搜索。
- [x] 搜索失败时提供重试。
- [x] 书内搜索结果可发起“保存为笔记”和“对片段提问”的后续入口。

## 涉及模块和文件

- `lib/features/reader/presentation/widgets/in_book_search_panel.dart`
- `lib/features/reader/application/reader_controller.dart`
- `lib/features/reader/application/in_book_search_controller.dart`
- `lib/renderers/common/renderer_event.dart`
- `lib/renderers/epub/epub_renderer_view.dart`
- `lib/renderers/pdf/pdf_canvas_view.dart`（搜索由 `searchQuery` 属性驱动，命中以 `RendererSearchResults` 事件回抛）
- `test/features/reader/in_book_search_test.dart`

## 数据与接口

- 渲染器搜索：宿主向 `PdfCanvasView` 传 `searchQuery`（上限 200 条命中），命中以 `RendererSearchResults` 事件回抛；EPUB 走 `RendererCommand.search`。
- `RendererEvent.searchResults` payload 包含：
  - query。
  - total。
  - results。
  - result locator。
  - snippet。
  - source title 或 page。
- 临时搜索高亮不写入 `annotations` 表。

## UI 与交互

- 移动端搜索面板可从顶部工具栏进入，使用底部抽屉或全屏搜索层。
- 桌面端通过顶部工具栏或 `Ctrl+F` 打开右侧常驻搜索面板，结果在右侧面板。
- `Ctrl+F` 聚焦书内搜索。
- Enter 跳到下一条，Shift+Enter 跳上一条。
- Esc 关闭搜索或取消选区。
- 无结果显示“未找到匹配内容”，不作为错误。

## 验收标准

- [x] EPUB 当前书内关键词可搜索。
- [x] PDF 有文本层时关键词可搜索。
- [x] 点击搜索结果能跳转到对应位置。
- [x] 当前结果有清晰高亮。
- [x] 清空或关闭搜索后临时高亮消失。
- [x] PDF 无文本层时说明原因。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 本轮已验证：`dart format lib test`、`flutter analyze`、`flutter test -r expanded`、`flutter build windows --debug`。
- 当前实现说明：阅读器搜索面板复用本地 SQLite FTS 索引，已按当前书籍过滤并返回 locator；搜索 query 会传给 EPUB/PDF renderer 做临时正文高亮，清空或关闭搜索时清除。EPUB renderer 会根据已解析章节返回章节标题、片段和 locator；PDF renderer 已提供原生 `search(query)`、清除高亮和文本层缺失提示。移动端使用底部搜索抽屉，桌面端使用右侧常驻搜索面板。
- 手动验证：EPUB 多章节搜索、PDF 多页搜索、无结果、PDF 无文本层、Windows `Ctrl+F`。

## 依赖与风险

- 依赖：TASK-05 reader core，TASK-06 EPUB renderer，TASK-07 PDF renderer。
- 风险：renderer 搜索和全局索引搜索结果定位可能不同，需要保持 locator 模型一致。
- 风险：大书搜索可能卡顿，需要 debounce 和搜索中状态。
