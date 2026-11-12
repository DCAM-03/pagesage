# TASK-07：PDF 渲染、页码、缩放、文本层和异常

## 目标

实现 PDF 固定版式阅读体验，支持打开、滚动、页码恢复、缩放、适合宽度、页码跳转、outline、文本选择、书内搜索和文本层缺失提示。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：DRM 绕过、手写批注。
- 约束：PDF renderer 使用 `pdf_graphics` + Flutter Canvas（2026-10-21 起；原 PDF.js + WebView 已删除，见 `docs/10-pdf-renderer-migration.md`）；业务数据由 Dart 保存。

## 功能范围

- 本地 PDF 打开（页面解释、缓存与 worker 预取）。
- 页码、scroll offset、zoom 回传。
- 连续滚动、单页、双页模式。
- 适合宽度、适合页面、固定缩放比例。
- 页码跳转。
- PDF outline 解析和跳转。
- 文本选择事件。
- 书内搜索。
- 文本层缺失和扫描版提示。
- 加密 PDF、损坏 PDF 的错误处理。

## 实现任务

- [x] ~~确认 `assets/renderer/pdf/` 资源随包发布~~ — 资源已随 S7 删除。
- [x] 建立渲染器控制接口，PDF 分支统一使用 `PdfCanvasView`。
- [x] 本地文件直接由 Dart 读取解释，不再经本地 HTTP 服务暴露给 JS。
- [x] 回传当前页、总页数、scroll offset、zoom、progress。
- [x] 打开时按 locator 恢复页码、滚动和缩放。
- [x] 支持连续滚动默认模式。
- [x] 支持单页模式和桌面/平板双页模式。
- [x] 缩放工具支持适合宽度、适合页面、100%、125%、150%。
- [x] 实现 `Ctrl+G` 或页码点击跳转入口。
- [x] 解析 PDF outline，不能解析时退化为页码目录。
- [x] 检测文本层是否可用，不可用时禁用划词和搜索相关能力。
- [x] 实现 PDF 书内搜索，结果包含页码和片段。
- [x] 加密 PDF 提示输入密码能力可预留，未实现时给出明确提示。
- [x] renderer 错误统一回传 renderError。

## 涉及模块和文件

- `lib/renderers/pdf/pdf_canvas_view.dart`
- `lib/renderers/pdf/pdf_canvas_renderer.dart`
- `lib/renderers/pdf/pdf_page_tint.dart`
- `lib/renderers/pdf/pdf_annotation_lines.dart`
- `lib/renderers/pdf/pdf_outline.dart`
- `lib/renderers/pdf/pdf_links.dart`
- `lib/renderers/common/renderer_event.dart`
- `lib/features/reader/application/reader_controller.dart`
- `test/renderers/pdf/`

## 数据与接口

- PDF locator 必须包含 `page`、`scrollOffset`、`zoom`、`progress`。
- 搜索结果必须包含 `page`、`snippet`、`locator`、`sortOrder`。
- 文本选择事件需要包含 selectedText、page、locator、selection rectangle 可用时保存。
- 文本层缺失状态需要暴露给 reader UI。

## UI 与交互

- 移动端支持双指缩放，双击适合宽度可后续增强。
- 桌面端支持 `Ctrl + 鼠标滚轮` 缩放。
- 页码点击后显示输入框，Enter 跳转，Esc 取消。
- 缩放控件不能遮挡页面内容。
- 扫描版或文本层缺失时提示“此 PDF 没有可选择文本”，阅读仍可继续。

## 验收标准

- [ ] 常规 PDF 可以打开并滚动。
- [ ] 退出后能恢复到对应页附近。
- [ ] 缩放和适合宽度不会造成明显错位。
- [ ] 页码跳转可靠。
- [x] outline 可用时能跳转，不可用时有页码替代。
- [x] 文本层缺失时搜索和划词能力被禁用且原因明确。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 本轮已验证（2026-10-21，S7）：`dart format .`、`flutter analyze`（0 error / 0 warning，仅 3 条 `poc_pdf_canvas/` info）、`flutter test`（327 通过 / 2 跳过）。
- 当前实现说明：PDF 由 `pdf_graphics` 在 Flutter Canvas 上直接绘制，无 WebView、无本地 loopback HTTP 服务。已支持连续滚动与单页/双页分页、页码跳转、0.5–3.0 连续缩放与四种缩放模式、桌面 `Ctrl + 鼠标滚轮`、locator 恢复（像素 `scrollOffset` + 页内比例 `pageOffsetFraction`）、文本选区（含 CJK 与旋转页）、书内搜索高亮、outline 与内部/外部链接、永久标注高亮（含 F-02 跨行裁剪、旋转页投影与夜间色板）、主题纸色与夜间滤镜，以及加密/损坏/单页失败的分级错误提示。
- 目录选中规则（2026-11-09）：同一页常同时包含章标题和多个小节标题，不能再按“页码相等”把整条分支都点亮。连续滚动时渲染器在 location locator 中回传页内比例 `pageOffsetFraction`；目录选取最后一个位置不晚于当前阅读位置的大纲项。没有页内比例时，只选当前页顶端（`offsetFraction <= 0.01`）的第一个条目；如果当前页没有顶端条目，则保留最后一个页码小于当前页的条目。桌面与移动目录共用同一规则，`RendererOutlineItem.offsetFraction` 只参与选中，不改变跳转目标。
- 页内选中证据（2026-11-09）：`reader_panels_test.dart` 覆盖桌面与移动同页三标题只亮一个、仅按页顶与跨页保留；`pdf_canvas_view_test.dart` 覆盖连续滚动上报非零页内比例。聚焦 51 项、全仓 697 项通过（2 skipped）；本地安装产物一致（`libapp.so` SHA256 `58f7ec77…`），安装后已重启实例。Windows / Android 与真实大 PDF 视检仍未执行。
- 手动样本：标准 PDF、大 PDF、扫描版 PDF、损坏 PDF、带 outline 与链接 PDF。
- 平台验证：**Linux 自动化已覆盖；Windows/Android 手工回归待 S8 执行。**

## 依赖与风险

- 依赖：TASK-05 阅读器核心，TASK-08 阅读设置，TASK-13 书内搜索。
- 风险：着色器/位图缓存占用内存，超大页（A0、高 DPI 扫描件）需在真机观察峰值内存。
- 风险：PDF 文本层缺失会影响搜索、划词和 AI，需要在 UI 中明确降级。
