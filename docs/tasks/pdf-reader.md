# TASK-07：PDF 渲染、页码、缩放、文本层和异常

## 目标

实现 PDF 固定版式阅读体验，支持打开、滚动、页码恢复、缩放、适合宽度、页码跳转、outline、文本选择、书内搜索和文本层缺失提示。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：扫描版 PDF OCR、DRM 绕过、手写批注。
- 约束：PDF renderer 使用 PDF.js；业务数据由 Dart 保存。

## 功能范围

- PDF.js 静态资源管理。
- 本地 PDF 打开。
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

- [x] 确认 `assets/renderer/pdf/` 资源随包发布。
- [x] 建立 `PdfRendererController`，实现通用 renderer 接口。
- [x] 本地文件通过安全的本地访问方式提供给 PDF.js。
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

- `lib/renderers/pdf/pdf_renderer_view.dart`
- `lib/renderers/pdf/pdf_renderer_server.dart`
- `lib/renderers/common/renderer_command.dart`
- `lib/renderers/common/renderer_event.dart`
- `assets/renderer/pdf/viewer.html`
- `assets/renderer/pdf/bridge.js`
- `assets/renderer/pdf/viewer.css`
- `assets/renderer/pdf/pdf.min.js`
- `assets/renderer/pdf/pdf.worker.min.js`
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
- 本轮已验证：`node --check assets/renderer/pdf/bridge.js`、`dart format lib test`、`flutter analyze`、`flutter test -r expanded`、`flutter build windows --debug`。
- 当前实现说明：PDF 使用本地 loopback HTTP 服务提供 PDF.js viewer 与书籍文件；已支持多页 canvas 渲染、连续滚动默认模式、单页显示、桌面/平板双页显示、页码按钮、缩放加减、适合宽度、适合页面、100%/125%/150% 缩放预设、桌面 `Ctrl + 鼠标滚轮` 缩放、locator 恢复、文本层状态事件、renderer `search(query)`、`goTo` 命令、PDF outline 解析、无 outline 时页码目录替代，以及加密/损坏 PDF 的明确错误提示。
- 手动样本：标准 PDF、大 PDF、扫描版 PDF、损坏 PDF、带 outline PDF、无 outline PDF。
- 平台验证：Windows 和 Android 打开、滚动、缩放、页码恢复。

## 依赖与风险

- 依赖：TASK-05 阅读器核心，TASK-08 阅读设置，TASK-13 书内搜索。
- 风险：PDF.js 本地文件访问和 worker 加载在不同平台存在差异。
- 风险：PDF 文本层缺失会影响搜索、划词和 AI，需要在 UI 中明确降级。
