# PDF Canvas 渲染器施工计划：自研 PdfCanvasView 补齐到可替换 WebView

版本：0.2（经五轮复审；修订记录见 §12–§14）
日期：2026-10-20
状态：待执行
前置文档：`docs/10-pdf-renderer-migration.md`（技术决策）、`docs/02-feature-spec.md` §5、`docs/03-interaction-spec.md` §8、`docs/v1-experience-freeze.md`
适用范围：`lib/renderers/pdf/`、`lib/features/reader/`、`lib/features/ocr/`、平台资源与依赖

## 1. 结论

继续自研 `PdfCanvasView`，不引入 `dart_pdf_editor` 的 `PdfViewer`，不迁 Tauri。理由已在 `docs/10-pdf-renderer-migration.md` §3 论证；本计划只回答「还缺什么、按什么顺序补、每步怎么验收」。

需要说清楚的一点：**当前 868 行的 Canvas 渲染器只是可用的 Linux 阅读页，不是 WebView 渲染器的等价替代**。它现在能渲染、能翻页、能按页保存进度；但缩放模式实际未生效、选区契约与宿主不一致、搜索阻塞 UI 线程、没有大纲/链接/标注命中/OCR 接口/主题/缓存/worker。下面按可独立验证的切片补齐，Windows/Android 在切片全部通过前继续留在 WebView 上作为回归基线。

## 2. 现状盘点（代码事实）

### 2.1 已经能用的部分

| 能力 | 位置 | 说明 |
| --- | --- | --- |
| 页面渲染 | `pdf_canvas_renderer.dart:31` | 变换、图片两遍扫描、像素上限均已按迁移文档 §6 实现 |
| 文本提取 / 搜索匹配 | `PdfTextExtractor` + `PdfPageText.findAll` | CJK 选词规则在 `pdf_selection_controller.dart:123` |
| 单页阅读与翻页 | `pdf_canvas_view.dart` `PageView` | 每屏一页，底部自带 `_PdfCanvasPager` |
| 按页保存/恢复 | `_reportLocation` / `_initialPage` | `progress = (page-1)/(N-1)`，与 WebView 相同 |
| 标注/OCR 叠加绘制 | `_annotationBoxes` / `_ocrBoxes` | 仅绘制，不可命中/选中 |
| 搜索高亮 | `_searchHighlights` | 同步逐页扫描，无取消 |
| Linux 平台接入 | `reader_page.dart:6897` | `Platform.isLinux` 分支 |

### 2.2 已确认的缺陷（本次排查新增）

| # | 缺陷 | 影响 | 位置 |
| --- | --- | --- | --- |
| 1 | `custom` 缩放只改光栅密度，`FittedBox` 仍把页面缩回视口 | 四种缩放模式外观几乎无差别，用户无法放大 | `pdf_canvas_view.dart:371`、`:408` |
| 2 | 设置变化不会触发重渲染（只在 viewport 变化时 `_render`） | 切换缩放/纸色后页面不变 | `pdf_canvas_view.dart:389` |
| 3 | `sourceRect` 发的是 0..1 归一化值，宿主按全局像素使用 | 桌面端选区菜单出现在屏幕左上角 | `pdf_selection_controller.dart:175` vs `reader_page.dart:2392` |
| 4 | 拖选高亮把归一化 rect 直接当 widget 坐标绘制 | 选区高亮位置/尺寸错误 | `pdf_canvas_view.dart:599`、`:624` |
| 5 | `rasterScale: 1` 写进 locator.zoom | 进度里保存的缩放值错误 | `pdf_canvas_view.dart:549` |
| 6 | 旋转页按未旋转 `cropBox` 尺寸布局与归一化 | 90°/270° 页被拉伸，选区偏移 | `pdf_canvas_view.dart:451`、`pdf_selection_controller.dart:224`、`_annotationBoxes` |
| 7 | `jumpToken` 变化时只读 `focusLocator`，页码跳转不带 excerpt 时为空 | 页码跳转/大纲跳转对 Canvas 完全无效 | `pdf_canvas_view.dart:249` vs `reader_page.dart:2679` |
| 8 | 首次 `jumpToPage` 在控制器挂载前调用（`PageController()` 未传 `initialPage`，`_open()` 在 `initState` 触发时 build 仍是 spinner） | **确定性进度损坏**：首次打开永远停在第 1 页，却按已保存页码上报；用户一划动，`onPageChanged(1)` 就把进度覆盖成第 2 页 | `pdf_canvas_view.dart:70`、`:126-130` |
| 9 | 无 `RendererFailed`（只在本地显示错误文本） | 宿主重试/错误详情 UI 不触发 | `pdf_canvas_view.dart:146-148` |
| 10 | 能力标志硬编码 `textSelection: true, search: true` | 扫描版 PDF 仍提供划词/搜索入口 | `pdf_canvas_view.dart:137-140` |
| 11 | 底部自绘 `_PdfCanvasPager` | 与宿主工具栏重复，违反 F-01 单 chrome | `pdf_canvas_view.dart:304`（S2 删除） |
| 12 | 搜索在主 isolate 逐页跑，仅每 4 页 yield | 大文档搜索卡 UI，且不可取消 | `pdf_canvas_view.dart:202` |
| 13 | 无 `scrollOffset`、无 excerpt、无 zoom 恢复 | 长页恢复只能回到页首，书签没有摘录 | `_reportLocation` |
| 14 | 没有标注命中、链接、大纲、OCR 控制器注册、`exportPageImage`、`getVisiblePages` | 标注点击/OCR/大纲/外部链接全部缺失 | 全文件 |

另有分支卫生问题：`reader_page.dart` 在 `1155097` 中被整体 CRLF→LF，产生约 7.8k 行噪声 diff；仓库没有 `.gitattributes`。在这之上继续改会让每次评审无法看清真实改动，必须先处理。

## 3. 目标与非目标

### 3.1 本期目标（对齐 `docs/tasks/pdf-reader.md` 与 v1 冻结项）

- 连续滚动为默认阅读模式，单页/双页为可选模式。
- 四种缩放真实生效：适合宽度、适合页面、100%、自定义（含双指、Ctrl+滚轮、工具栏）。
- 位置恢复含页、页内偏移、缩放；退出重开落点稳定。
- 大纲解析与跳转；无大纲时页码目录回退（宿主已有 fallback）。
- 文本选择（桌面拖选、移动长按选词 + 手柄、跨页）、书内搜索与结果跳转。
- 标注叠加可点击；扫描版 PDF 如实降级并保留 OCR 入口；OCR 后可划词。
- 加密/损坏 PDF 走 `RendererFailed`，错误 UI 与重试可用。
- 主题纸色与夜间模式在 Canvas 上落地，移动端遵守 WebView 当年的滤镜禁用策略。
- 达标后切换 Windows/Android 到 Canvas，删除 WebView 渲染器与 PDF.js 资源。

### 3.2 非目标（明确不做）

- 不使用 `PdfViewer`、不做 PDF 编辑/表单填写/签名/打印。
- 不改变 OCR 产品范围（仍为「识别可见页」，不做全自动扫描件 OCR）。**OCR 文本不进书内搜索，也不进 FTS 全局搜索**——这是 `v1-experience-freeze.md` §5 策略 S-B 的冻结项（「整书 OCR / OCR 搜索 → 延后」），本期只在 S5 修正既有的能力误报（见 §4.7）。
- 不做 tile 化无限缩放、不做云端/账号/DRM。
- 不保留 WebView 作为长期回退（仅作为 S7 之前的回归基线）。

## 4. 关键设计决策

### 4.1 坐标契约（必须先定死）

- **widget 坐标**：逻辑像素，原点在页面绘制区域左上，y 向下。
- **page 坐标**：PDF 用户空间，点，y 向上。
- **`ReaderRect` 两套用途**，与 WebView 契约保持一致：
  - `selectionRects` / `locator.selectionRects`：0..1 归一化（持久化、跨缩放重绘）。
  - `sourceRect`（`RendererTextSelected`、`RendererAnnotationSelected`）：**全局逻辑像素**，宿主的 `_toOverlayLocalRect` 直接减 Overlay 原点。Canvas 需要像 `PdfRendererView._mapEventToFlutterCoords` 一样做一次 `localToGlobal` 偏移。
- 旋转、crop box 原点：**页面空间数据**（`PdfTextQuad`、`PdfDestination`、链接 `PdfAnnotation.rect`）一律走 `PdfPageGeometry`（`toViewRect` / `toPagePoint`），不再手写 y 翻转。显示尺寸用 `PdfPageRenderer.pageSize(page)`（已含 /Rotate），不要用 `cropBox.width/height`。
- **走 worker/replay 路径时禁止二次旋转**：`pdf_canvas_renderer.dart:56-68` 目前自己 `switch (page.rotation)` 在 canvas 上做旋转；而 `PdfPageRenderer.pictureFromCommands`（`renderer.dart:347`）内部会再调一次 `_applyPageTransform`。切换后必须传 `PdfPageRenderPlan(rotation: null)`，让库用页面自身的 /Rotate，**不要再传 `page.rotation`**，否则 90°/270° 页会转 720°。这是 S6 落地时最具体的雷，S1 起就要守住。
- **已持久化的归一化 rect 不走 `PdfPageGeometry`**：`locator.selectionRects` 与 OCR 块的比例是相对「旋转后的显示页框」归一化的（旧 bridge 用页面元素 clientWidth/Height），投影就是 `Rect(x*viewW, y*viewH, w*viewW, h*viewH)`。当前实现把它们先翻成页面空间再经 `toViewRect` 转回来，两次翻转在 0° 页相互抵消、看似正确，90°/270° 页会偏移。这一点在 S5 一并修正。

### 4.2 缩放

- 单一来源：`_layoutScale`（逻辑像素 / PDF 点）。
  - `actual` = 1.0；
  - `fitWidth` = `viewport.width / pageSize.width`；
  - `fitPage` = `min(viewport.width / pageSize.width, viewport.height / pageSize.height)`；
  - `custom` = `settings.pdfScale.clamp(0.5, 3.0)`。
- 光栅密度 = `_layoutScale * dpr`，受像素预算约束；布局直接按 `pageSize * _layoutScale` 摆放，**不再套 `FittedBox`**（迁移文档 §6.3 的二次缩放坑）。
- 捏合缩放：视口级 `ScaleGestureRecognizer`，捏合期间维护 transient scale，结束时通过宿主回调持久化为 `custom`；以捏合焦点为锚调整滚动位置，避免内容跳动。
- 桌面 `Ctrl + 滚轮`、`Ctrl +/-/0` 已有宿主入口（`_adjustReaderScale`、`_resetReaderScale`），Canvas 只需正确响应 settings 变化。
- 放大后：连续模式允许横向滚动；分页模式用 `InteractiveViewer`。缩放值上限 3.0，与旧 bridge 一致。
- **窄屏启发式需要显式决策（见 §10 待决 4）**：旧 bridge 的 `resolveZoomForPage`（`bridge.js:1010`）在 narrow viewport 且用户值 `≤ 1.25` 且 `widthScale < 1.2` 时会压到 `widthScale`；打开文档时若 `zoomMode === 'custom'` 且窄屏，直接改判 `fit-width`（`bridge.js:2877`）。这是为了避免 360px 手机上 600pt 页按 1.2× 铺开导致的横向混乱与"页面变形"。Canvas 若照上面简单 clamp，会在 Android 上复现该问题。S1 必须二选一：继承启发式，或在文档中明确放弃并承担回归。

### 4.3 连续滚动与虚拟化

- `ListView.builder` + `itemExtentBuilder`（Flutter 3.44 支持）：页高由 `pageSize * layoutScale + gap` 直接算出，滚动偏移可确定性计算，不需要测量。
- 只构建视口 ± `cacheExtent` 的页；渲染优先级：可见页 0、前后各 2 页 1、其余不渲染。滚出视口 `worker.cancel(pageIndex)`。
- `scrollOffset` 语义与旧 bridge 一致：`scrollY - pageTop`，clamp ≥ 0（`ReadingLocator._matchesPdf` 用 ±24 px 容差）。**且有模式条件**：`currentScrollOffset()`（`bridge.js:180-190`）在非连续模式下**一律返回 0**。Canvas 必须照此处理——单页/双页模式上报 0，否则与历史 locator 的 ±24 px 容差比较会失配、书签/进度判定漂移。
- 当前页判定：连续模式取 `scrollY + max(viewportHeight * 0.28, 48)` 所在页（`bridge.js:196`）；非虚拟回退分支历史上用 35%/96（`:213`），Canvas 统一按 28%/48 即可，但要写进测试断言。注意这是"视口高度的比例"，不是"页面高度的比例"。
- `ReaderMode.paged`：窄屏单页，宽屏双页（封面单独，2-3、4-5 对齐），默认 `fitPage`；`getVisiblePages` 返回整个跨页。
  注意语义来源：`settings.readerMode`（`ReaderMode { continuous, paged }`）是 EPUB 与 PDF **共用**的字段——PDF WebView 链路经 `web_renderer_helpers.dart:117` 传给 bridge，由 `preferredDisplayMode()`（`bridge.js:135`）映射为 `paged → 窄屏 single / 宽屏 double，否则 continuous`。Canvas 直接消费同一字段并复刻该映射，不新增设置项。

### 4.4 渲染与缓存

- 优先 `PdfRenderWorker.start(bytes)`：`record()` 在后台 isolate 完成内容流解析与解释，主线程只 `PdfPageRenderer.pictureFromCommands` 回放；返回 null 时回退本地 `PdfPageRenderer.renderPicture`。
- 这同时解决两件事：主 isolate 卡顿、对 `dart_pdf_editor/src/image_decoder.dart` 的 implementation import（当前 `pdf_canvas_renderer.dart:4`）。
- ~~页缓存：按 `(pageIndex, rasterScale 桶, pageColor)` 缓存 `ui.Picture`，LRU + 字节预算（桌面 256 MB / 移动 96 MB 起步）~~ —— 该方案已由下一条取代，见「缓存不要叠两层」。
- 文本提取同样走 `worker.extractText(pageIndex, priority:)`，搜索结果与选区共享缓存，避免重复解析。
- 打开时保留文档 bytes（worker 需要），关闭时 `worker.dispose()`。
- **缓存不要叠两层**：`PdfRenderWorker.start` 返回的 `PdfCachingRenderWorker` 自带 LRU（`render_worker.dart:1335`），默认 `budgetBytes = 72 MB`、`maxEntries = 64`、`maxRetainedCommands = 250000`，并通过全局变量 `pdfRenderWorkerCacheBudgetBytes` / `pdfRenderWorkerCacheMaxEntries` 可调，同时注册了 `PdfCacheRegistry` 以响应内存压力信号。若 Canvas 再自建一层按 `ui.Picture` 估字节的 LRU，两层各自淘汰，会出现"两边都以为对方持有"的重复渲染。S6 的缓存工作应优先调 worker 的全局参数；只有确有必要时再叠加一层，且必须写清两层各自的职责边界。

### 4.5 选区模型

- 选区状态从单页 `_CanvasPage` 上移到 `PdfCanvasView`：`anchor(page, point)` + `focus(page, point)`，支持跨页。
- 桌面：鼠标拖选；移动：长按选词（现有 CJK 规则保留），两端手柄可拖动扩展；手柄与菜单画在 Overlay，不进页面 CustomPaint。
- 提交事件时：`text` 为跨页拼接文本；`locator` 锚在起始页；`selectionRects` 为各页 0..1 矩形；`sourceRect` 取首个 quad 的全局像素。
- 空文本层：不静默返回，发 `RendererCapabilityChanged(textSelection:false, search:false, reason:…)`，宿主已有文案。

### 4.6 搜索

- 查询变化 → 生成 `searchGeneration`；结果每次写入前校验 generation，旧任务自动作废。
- 逐页 `worker.extractText`，命中上限 200（对齐旧 bridge）；命中 quads 存 `Map<int, List<PdfTextQuad>>` 供绘制与跳转闪烁。
- 结果列表与当前页高亮解耦：搜索结果事件立即回传，高亮按页渲染。

### 4.7 标注、OCR 与导出

- 标注：存储的归一化 rect 直接按显示页尺寸投影（见 §4.1）；点击命中按 z 逆序，发 `RendererAnnotationSelected(id, sourceRect: 全局像素)`。
- OCR 导出：新增平台无关接口 `PdfPageImageSource`，`activePdfRendererControllerProvider` 改为该接口类型；Canvas 用 `PdfPageExport.exportPage(page, format: jpeg, scale: layoutScale*dpr, jpegQuality: 86)` 实现；切换完成后删除 WebView 实现。
- **接口返回 `Uint8List?` 而不是数据载体类**：复核确认宿主只用 `.bytes`（`reader_page.dart:2788` 是 `return exported?.bytes`，`ocr_page_controller.dart:144-146` 也只把 bytes 往下传），而本地 `PdfPageExport` 的 `width/height/imageWidth/imageHeight` **四个字段从未被读取**。因此把接口定为 `Future<Uint8List?> exportPageImage({required int pageNumber, double quality})`，直接删除 `pdf_renderer_controller.dart:9` 那个类——既消除与 `dart_pdf_editor` 的 `PdfPageExport` 类型名冲突，又清掉死代码。这比"改名为 `PdfPageImageCapture`"更彻底，也少 4 处机械改动。
- OCR 层可参与选区：**不要合成 `PdfPageText`**。`PdfPageText` 与 `PdfExtractedRun` 构造器虽公开（`pdf_graphics/lib/src/text_extraction.dart:22/138`），但需要自行计算 `PdfMatrix` 变换。改为直接对 `ocrOverlayBlocks` 做矩形命中 + 文本拼接，与现有 `_ocrBoxes` 的数据形状一致，也避开矩阵计算。
- **OCR 搜索不在 v1 范围，且不得继承既有误报**：`docs/v1-experience-freeze.md` §5 策略 S-B 明写「整书 OCR / OCR 搜索 → 延后」，§4.2 也把「OCR 进 FTS 全局搜索」列入明确延后。实测 WebView 侧同样没有实现：`search()` 只读 `pdfPage.getTextContent()`（`bridge.js:2148`），从不读 `ocrLayers`。
  **但存在一个既有 bug 需要在本期修掉**：`reportCapability()`（`bridge.js:147-155`）因为 `nativeTextLayerAvailable || ocrTextLayerAvailable` 而把 `search: true` 报给宿主——扫描页 OCR 后 UI 显示"搜索可用"，实际搜不到。Canvas 不得复制这个行为：OCR 层存在但无原生文本层时，`search` 应如实报 `false`，`textSelection` 可为 `true`（选区基于 OCR 块矩形命中，不依赖搜索）。这与 `nativeTextLayer` / `ocrTextLayer` 的分开上报一致。
- 页面图片尺寸必须与屏幕几何一致（同一 `pageSize` 与缩放），否则 OCR 框会偏。
- **OCR overlay 的会话状态不在渲染器里**：`_restoredOcrPages`（`reader_page.dart:121`）、`_ocrOverlayToken`（`:111`）、`_ocrOverlayPage`/`_ocrOverlayBlocks`（`:112-113`）全部由宿主持有，经 `ReaderRendererHostConfig` 下发。Canvas 现在**已收到** `ocrOverlayPage` / `ocrOverlayBlocks`（`reader_page.dart:6904-6905`），只是没传 `ocrOverlayToken`。因此 S5 不需要"按已加载 OCR 页集合重建"——重建逻辑已在宿主；Canvas 只需补上 `ocrOverlayToken` 字段，并在 token 变化时只重绘对应页。
- **OCR 在 Linux 上没有可用的真实引擎（排期问题，非实现问题）**：`ocrEngineProvider` 只在 Android（mlkit）与 Windows（winrt）返回真实引擎，其余平台返回 `StubOcrEngine`——`supportsPdfPageOcr => false`，`recognize` 直接抛 `OcrUnavailableException`（`stub_ocr_engine.dart:11-24`）。而 Canvas 在 S7 之前只在 Linux 生效。因此 S5 阶段无法在开发平台上跑通真实识别。
  处理方式（见 S5 步骤）：S5 增加一个**仅测试用**的假 OCR 引擎（固定返回几条 span），在 Linux 上验证「导出图 → overlay 绘制 → 选区」整条管线；识别质量与真机行为留到 S7 之后的 Android/Windows 验证。这样 S5 仍可独立验收，且不会把"管线正确"与"模型准确"混为一谈。

#### 4.7.1 永久标注的跨行约束（F-02，P0 硬约束）

`docs/v1-experience-freeze.md` §3.3 的冻结决策原文：

> **永久标注硬约束：不得盖住未选中的下一行**（文本 PDF 与 OCR 页一律适用）。
> 扫描页允许「近似贴字」，但跨行误盖 = 缺陷，必须修，不是接受项。

这是 v1.0 的 P0 项（F-02），但**当前 Dart 侧完全没有实现**：全 `lib/` 搜索 `mergeSameLineRects` / `preventAdjacentBleed` / `snapRectsToLineBands` / `lineBands` / `cyRef` / `bandH` 均零命中。Canvas 只保留了简化版的高度塌缩（`pdf_canvas_view.dart:469` 的 `h > 0.055 → 0.022`），随后在 `_PicturePainter.paint`（`:679`）直接 `canvas.drawRect(box.rect, fill)` 整块填充。

WebView 侧的合规链路由四个函数组成，Canvas 必须移植或等价重写：

| 环节 | bridge 位置 | 作用 |
| --- | --- | --- |
| `mergeSameLineRects` | `bridge.js:1617` | 按 `cy` 聚类同一视觉行，取 top/height 的**中位数**（抗历史离群框），跨行不合并 |
| `lineBandsForPage` | `:1693` | 从 OCR span 或原生文本 span 的 client rect 求本页**行带**（归一化 y 区间，自上而下） |
| `snapRectsToLineBands` / `clampStripToBand` | `:1757` / `:1830` | 高亮条吸附到行带；条高不超过局部行距的 78%，底边不得越过下一行带 `top - 0.0012` |
| `preventAdjacentBleed` | `:1852` | 相邻框之间留 `seam = 0.0012`，必要时压缩，但保留至少 50% 原高 |

绘制阶段还有两道兜底（`bridge.js:1983-1998`）：

- 向下不得越过**下一条选中行**的 `y - 0.0009`；
- 下划线粗细按页高归一化到 1.5–2.6 CSS px（`uh = clamp(lineH * 0.08, 1.5/pageH, 2.6/pageH)`），高亮底边停在下划线上方。

Canvas 当前把下划线画成 `box.rect.height * 0.15`（`:672`），而 `box.rect.height` 本身可能已被坍缩到 0.022——粗细因此随内容漂移，不符合上述归一化规则。

**结论**：S5 的"标注投影改为直接乘归一化 rect"如果照字面执行，会让 F-02 从"WebView 满足、Canvas 未实现"退化为"三端都不满足"。F-02 链路必须作为 S5 的必做项，并纳入 DoD。

### 4.8 主题

- 纸色：`PdfPageRenderPlan(pageColor: preset.background)`，页面外边距用同一 preset 背景（当前写死白色）。
- 夜间/护眼：对页面 picture 施加 `ColorFilter`（`invert/hue-rotate`、`sepia` 近似矩阵），标注与 OCR 文本不过滤。移动端默认关闭滤镜（沿用旧 bridge 的 GPU 发热策略），只换纸色；桌面开启。差异写入文档。

### 4.9 失败处理

- `CosPasswordException` → 「此 PDF 需要密码（当前版本不支持输入密码）」；`CosParseException` → 「文件可能已损坏」；其他 → `RendererFailed`。
- 单页渲染失败只降级该页（占位 + `RendererNotice`），不整本黑屏，满足 F-04。

## 5. 施工顺序

原则：每个切片一个提交、独立可验收；Linux 是开发验证平台；WebView 代码在 S7 前保持可回退；每步完成都跑 `dart format .`、`flutter analyze`、`flutter test`。

| 切片 | 产出 | 依赖 | 估算 |
| --- | --- | --- | --- |
| S0 基线修整 | 契约/坐标/跳转/错误修正，分支卫生，分析输出清理 | — | 1–2 天 |
| S1 缩放系统 | 真实四模式 + 双指 + Ctrl 滚轮 + 坐标换算 + 窄屏启发式 | S0 | 3–4 天 |
| S2 连续滚动 | 虚拟化列表、scrollOffset、恢复、单页/双页 | S1 | 3–4 天 |
| S3 选区 | 长按选词、手柄、跨页、旋转页 | S1/S2 | 3–5 天 |
| S4 搜索/大纲/链接 | 后台搜索、outline、link 命中（含 url_launcher 平台影响） | S2 | 2–3 天 |
| S5 标注/OCR/导出 | 命中、OCR 接口抽象、导出图（含 PdfPageExport 改名） | S2 | 2–3 天 |
| S6 主题/性能/健壮性 | 纸色/夜间、worker 缓存、失败降级 | S1–S5 | 2–3 天 |
| S7 平台切换与删除 | 三端切换、删 WebView/资源/依赖、样本迁移、文档 | S0–S6 | 2–3 天 |
| S8 验证收口 | 自动化 + 三端手工矩阵 + 性能基线 | 全部 | 2–3 天 |

合计约 20–30 人日（单人、含自测；不含 Windows/Android 设备排队时间）。

> 本切片表与各切片步骤已于 2026-10-20 复审并修订，修订明细见 §12。

### S0 基线修整（1–2 天）

改动文件：`.gitattributes`（新增）、`lib/renderers/pdf/*`、`lib/features/reader/presentation/reader_page.dart`（仅必要处）、`tool/refresh_covers.dart`。

1. 新增 `.gitattributes`（`*.dart text eol=lf`），`git add --renormalize .` 单独提交，消掉 7.8k 行噪声；顺手修 `tool/refresh_covers.dart:63` 的 `BookFormat?` 传参错误（当前 `flutter analyze` 永远红）。同时把 `flutter analyze` 现有的 16 个 info/warning 分级处理，其中 `pdf_canvas_renderer.dart:4` 的 `implementation_imports` 与 `poc_pdf_canvas/lib/main.dart` 的 3 条在 S7 删除对应代码后自然消失，其余（`prefer_initializing_formals` ×5、`deprecated_member_use` ×5、`depend_on_referenced_packages` ×2、`unused_element_parameter` ×1）应在 S0 一并清掉，避免长期挂在分析输出里掩盖真问题。
2. 修契约类缺陷（**先不动布局结构**）：`sourceRect` 全局像素、拖选高亮用几何换算、locator.zoom 用实际缩放、`jumpToken` 读 `initialProgress.locator`、**首帧后跳页**、发 `RendererFailed`、能力检测。自绘 pager 暂留到 S2（此时尚无连续滚动，先保住翻页入口）。
   - 缺陷 8 是**确定性数据损坏**，不是"可能不生效"：`PageController()` 未传 `initialPage`（`:70`），`_open()` 在 `initState` 发起时 build 仍返回 spinner，`hasClients` 必为 false，`jumpToPage` 从不执行。结果首开停在第 1 页却按保存页码上报，用户一划动即把进度覆盖成第 2 页。修法二选一：给 `PageController` 传 `initialPage`（但此时页数未知），或在 `_readySent` 后的首帧 `addPostFrameCallback` 里 `jumpToPage`。选后者，与 S2 的恢复逻辑同一套。
   - 这一步刻意**不包含**缺陷 6（旋转页）与几何集中：两者与布局强耦合，而 S1 会重写布局。现在改一遍、S1 再改一遍是浪费。旋转页的正确性放到 S1/S3 用 90° 样本卡住。
   - 验收除选区菜单外，必须同时验标注点击菜单——`sourceRect` 从「页面局部像素」改「全局像素」会影响两条路径（选区与标注），只测选区会漏掉后者。
3. 能力检测：采样前 8 页 + 中间页（对齐 bridge `detectDocumentTextLayer`，`bridge.js:2914`），异步完成后再发 `RendererCapabilityChanged(textSelection, search, nativeTextLayer, ocrTextLayer, reason)`；在检测完成前按「可用」处理，避免入口闪烁。
4. 上报：`locator.zoom` 用 `_layoutScale`；`excerpt` 取视口顶部 `positionNear` 附近文本；`scrollOffset` 先恒 0（S2 接）。

验收：Linux 上打开 `chinese-embedded.pdf`，单击选字、拖选，选区菜单与标注点击菜单都出现在对应位置上方；页码跳转生效；扫描样本显示禁用原因；**恢复验证：在 80 页样本停到第 40 页退出，重开不做任何操作直接再退出，进度仍是第 40 页（缺陷 8 的回归点）**；`flutter analyze` 0 error。

### S1 缩放系统（3–4 天）

改动文件：`pdf_canvas_view.dart`（重写布局与手势）、`reader_page.dart`（新增 `onPdfZoomChanged` 回调并接 settings）、`reader_settings.dart`（必要时统一上下限）。

1. 去掉 `FittedBox`：页面槽位 = `pageSize * _layoutScale`，`CustomPaint` 直接以此尺寸绘制；光栅按 `_layoutScale * dpr` 渲染并受 64 MP 上限约束。
2. 集中几何：显示尺寸只用 `PdfPageRenderer.pageSize(page)`（含 /Rotate），所有 widget↔page 换算经过 `PdfPageGeometry`；顺带修缺陷 6（旋转页按未旋转 `cropBox` 布局）。用 90° 样本卡住，这是缺陷 6 的验收点。
3. `didUpdateWidget` 比较 `pdfZoomMode/pdfScale/themePreset/readerMode/pageMargin/reduceMotion`，变化时清空页缓存并重渲染。
4. 双指缩放：`RawGestureDetector` + `ScaleGestureRecognizer`，transient scale 期间只重算布局与可见页光栅，结束时回调宿主持久化（clamp 0.5–3.0）。以焦点为锚补偿滚动偏移。
5. 桌面 `Ctrl + 滚轮`：`Listener` 捕获 `PointerScrollEvent`，`HardwareKeyboard.instance.isControlPressed` 时调整并消费事件，避免同时滚动。
6. 窄屏缩放启发式：按 §10 待决 4 的结论实现（继承 bridge 行为或明确放弃），并在窄屏设备上验证 600pt 页 + `custom 1.2` 不出现横向混乱。
7. 双击：`fitWidth ↔ 2.0`（P2，可放到最后做）。
8. **守住 rotation 不二次翻转**：本切片若接入 `PdfPageRenderPlan`，传 `rotation: null`（见 §4.1）。

验收：四种模式逐一截图对比，确认无裁切/重影（迁移文档 §6.3）；90° 样本选区与标注贴合；放大 3× 后文字清晰、选区贴合；缩放值持久化后重开恢复；桌面滚轮不误滚；Android 窄屏 custom 缩放无横向混乱。

### S2 连续滚动与位置（3–4 天）

改动文件：`pdf_canvas_view.dart`、`reading_position.dart`（仅在必要时补 scrollOffset 语义注释）。

1. 用 `ListView.builder(itemExtentBuilder:)` 替换 `PageView`；页槽 = `pageSize.height * scale + gap`；横向放大时外层 `SingleChildScrollView`。
2. 位置：前缀和求 `pageTop`；连续模式 `scrollOffset = scrollY - pageTop`，**单页/双页模式恒为 0**（对齐 `bridge.js:180-190`）；`_currentPage` 用 `scrollY + max(viewport.height * 0.28, 48)` 判定；滚动停止 120 ms 后上报（保留现有节流）。窄屏节流 420 ms、桌面 120 ms，与 `bridge.js:296` 一致。
3. 恢复：首帧 `addPostFrameCallback` 后 `jumpTo(pageTop + scrollOffset)`；缩放变化时按「当前页 + 页内比例」重定位。
4. 单页/双页模式：直接消费共用的 `settings.readerMode` 字段，复刻 bridge `preferredDisplayMode()` 映射（`paged` → 窄屏 `single` / 宽屏 `double`；否则 `continuous`），窄屏永远不允许 double（跨页放不下）；双页跨页容器封面单独，2-3、4-5 对齐；切模式时保持当前页；双页默认 `fitPage`。`getVisiblePages` 返回整个跨页。不新增 `pdfDisplayMode` 之类的第二套显示模式字段——`reader_page.dart` 的工具栏、`ReaderRendererHostConfig` 传参、EPUB 链路都走 `readerMode`，新增字段会造成双份状态。
5. 键盘：方向键/PageUp/PageDown 翻页（与 EPUB 渲染器行为一致）。
6. 删除 `_PdfCanvasPager`，页码显示与跳转交给宿主（满足 F-01 单 chrome）。

验收：80 页样本从第 40 页滚到 41 页任意位置，退出重开误差 < 1 行；双页模式左右页正确；快速滚动不出现整页重渲染卡顿；单 chrome（F-01）。

### S3 选区（3–5 天）

改动文件：`pdf_canvas_view.dart`、`pdf_selection_controller.dart`（改为按页实例 + 共享选区会话）、`reader_page.dart`（仅在菜单锚点必要时调整）。

1. 选区状态上移；长按 350 ms 选词并显示手柄；手柄拖动扩展；桌面拖选；跨页时逐页裁剪 `selectionRects`。
2. 全部几何走 `PdfPageGeometry`；CJK 分词规则不变。
3. 选中后不重建整个 reader（宿主已有约定：`RendererTextSelected` 默认不 `setState`）；高亮用页面内 `Positioned`/CustomPaint，手柄与菜单走 Overlay。
4. 空文本层：长按/拖选无结果时发 `RendererNotice('此 PDF 没有可选择文本')`。宿主只过滤「没有文本层 / 没有可搜索文本」这两类持久能力文案（`reader_page.dart:1178`），这句会正常弹一次瞬时提示，符合交互规格 §8.3。
5. 旋转页验收：`selectionRects` 的归一化基准是**旋转后的显示页框**，因此 90° 样本的选区矩形必须用旋转后的 `pageSize` 反算，不能用 `cropBox` 原始宽高（缺陷 6 的选区侧验收点）。

验收：嵌入 CJK 样本单击选单字、拖选整行、跨页 3 行；90° 旋转样本选区贴合；菜单不遮字且可键盘关闭；移动端手柄可点中（触控热区 ≥ 44 px）。

### S4 搜索 / 大纲 / 链接（2–3 天）

改动文件：`pdf_canvas_view.dart`、`reader_page.dart`（链接确认对话框）、`pubspec.yaml`（`url_launcher` 直接依赖）。

1. 搜索改为 worker `extractText` + generation 取消；上限 200；命中 quads 按页缓存；当前结果滚动到页 + excerpt 闪烁（复用 `focusLocator` 绘制）。
2. 大纲：`PdfOutline.of(doc)` 递归展平为 `RendererOutlineItem(title, page: destination.pageIndex+1, level)`；`PdfDestination.top/left` 转成 `scrollOffset`，TOC 跳转落点更准。
3. 链接：`page.annotations.whereType<PdfLinkAnnotation>()`；GoTo 直接跳转；URI 弹确认后 `launchUrl(externalApplication)`。
   `url_launcher` 在 `pubspec.lock:1046` 标记为 `dependency: transitive`，来自 `dart_pdf_editor/pubspec.yaml:44` 的 `^6.3.0`；项目当前 `lib/` 内零使用。S4 要新增为**直接依赖**并调用 `launchUrl`，会注册平台插件。仓库实际只有 `android/`、`linux/`、`web/`、`windows/` 四个平台目录（无 `ios/`、`macos/`），需要复核的只是这四端：包体增量、AndroidManifest 是否需要 `QUERY_ALL_PACKAGES` 或 `<queries>`（打开第三方浏览器）、Windows/Linux 插件注册文件是否要重新生成。提交说明中除理由外应写明这四项影响面。
4. 链接命中与选区手势区分：单击命中链接，长按/拖选优先选区。

验收：搜索「嵌入」命中 **2 处**（`make_samples.dart` 源码中该词出现 2 次：标题与正文）并可跳转；有 outline 的样本层级/页码正确；无 outline 时宿主页码目录仍可用；外部链接确认后打开浏览器，取消不跳转。

### S5 标注 / OCR / 导出（2–3 天）

改动文件：`pdf_canvas_view.dart`、`lib/features/ocr/application/ocr_providers.dart`、`pdf_renderer_view.dart`（临时实现新接口）、`pdf_renderer_controller.dart`（临时）、`reader_page.dart`（如接口类型变化）。

1. **删除本地 `PdfPageExport` 类**（`pdf_renderer_controller.dart:9`，含构造 `:10`、返回类型 `:71`、构造调用 `:93`），新接口直接返回 `Uint8List?`。宿主只用 `.bytes`，四个尺寸字段从未被读取；删除后与 `dart_pdf_editor` 的同名类不再冲突，也不需要改名。同步更新 `reader_page.dart:2774-2789` 的回调（`exported?.bytes` 改为直接返回值）。
2. 标注投影改为按显示页尺寸直接乘归一化 rect（现实现经页面空间两次翻转，旋转页会错）；按 z 逆序命中；`RendererAnnotationSelected` 带全局 `sourceRect`。
3. **F-02 跨行链路移植（P0，见 §4.7.1）**：把 bridge 的 `mergeSameLineRects` / `lineBandsForPage` / `snapRectsToLineBands`（含 `clampStripToBand`）/ `preventAdjacentBleed` 四个函数移植为 Dart，绘制时按下一条选中行裁剪、下划线粗细按页高归一化。这是 S7 删除 WebView 后 F-02 仍能满足的唯一保证。
4. 定义 `PdfPageImageSource`（`Future<Uint8List?> exportPageImage({required int pageNumber, double quality})` + `getVisiblePages`），`activePdfRendererControllerProvider` 改类型；Canvas 与 WebView 各自实现，S7 删除后者。
5. Canvas `exportPageImage` 用 `PdfPageExport.exportPage`（此时无冲突）；`getVisiblePages` 在双页模式返回跨页两页。
6. OCR 块参与选区：**矩形命中 + 文本拼接，不合成 `PdfPageText`**（见 §4.7）。`ReaderRendererHostConfig` 补 `ocrOverlayToken` 字段，token 变化时只重绘对应页。
7. OCR 后的能力上报：OCR 层存在但无原生文本层时，`search` 报 `false`、`textSelection` 报 `true`（见 §4.7）。**不要**复制 WebView 把 `search` 报成 `true` 的既有误报。
8. **假 OCR 引擎（仅测试用）**：`StubOcrEngine` 在 Linux 上 `supportsPdfPageOcr => false` 且抛异常，S5 无法在开发平台跑真实识别。新增一个测试用引擎，固定返回若干 span，用于在 Linux 上验证「导出图 → overlay → 选区」管线；真实识别留给 S7 后的 Android/Windows 真机。
9. ~~状态恢复：按「已加载 OCR 页集合」重建~~ —— **本项取消**。`_restoredOcrPages` / `_ocrOverlayToken` / `_ocrOverlayPage` / `_ocrOverlayBlocks` 均由宿主持有（`reader_page.dart:111-121`），`_restoreOcrOverlaysForVisiblePages`（`:2895`）已经在做重建并通过 config 下发，Canvas 无需重复实现。S5 只需确认 Canvas 侧对下发的 overlay 有响应（当前已有 `ocrOverlayPage` / `ocrOverlayBlocks`，缺 token）。

验收（Linux，用假 OCR 引擎）：导出图 → overlay 绘制 → 在 OCR 块上划词，管线通过；**F-02：多行选中与 OCR 页高亮均不得越过下一条选中行，下划线粗细在 1.5–2.6 CSS px 等效范围内**；标注点击菜单位置正确；导出图与屏幕几何一致（OCR 框贴合文字）；OCR 后搜索入口如实禁用。真实识别质量、双页两侧识别留到 S7 后的 Android/Windows 真机验证（见 S8 手工矩阵）。

### S6 主题 / 性能 / 健壮性（2–3 天）

改动文件：`pdf_canvas_view.dart`、`pdf_canvas_renderer.dart`（可并入 view 的缓存层）、`reader_page.dart`（错误文案映射如需）。

1. 纸色 + 夜间的 `ColorFilter`（移动端禁用滤镜）；外边距背景跟随主题。
2. `PdfRenderWorker` 接入与回退；缓存优先调 worker 全局参数（`pdfRenderWorkerCacheBudgetBytes` / `pdfRenderWorkerCacheMaxEntries`），不自建第二层 LRU（见 §4.4）；预取相邻页（优先级 1），滚出 `cancel`。
3. 删除 `pdf_canvas_renderer.dart` 对 `src/image_decoder.dart` 的 implementation import（改走 worker/replay 后不再需要）。
4. 失败分级：打开失败/单页失败/密码/损坏；单页失败占位并 `RendererNotice`。
5. **replay 路径的 rotation 检查**：确认 `PdfPageRenderPlan(rotation: null)`，页面自身 /Rotate 由库处理，不再手传 `page.rotation`（见 §4.1）。这是 90°/270° 页的最终验收点。
6. 性能采样：80 页首开、连续滚动帧时间、3× 放大图片页、峰值内存；把数字写回本文档。

验收：夜间模式标注不被反色；80 页滚动无长时间掉帧；损坏样本出错误页可重试；无空白页（F-04）。

### S7 平台切换与删除（2–3 天）

改动文件：`reader_page.dart`、`pubspec.yaml`、平台生成文件、`docs/*`、`test/*`。

1. `_DefaultRendererHost` 的 PDF 分支统一走 `PdfCanvasView`；Windows/Android 先手工回归一轮再删代码。
2. 删除：`pdf_renderer_view.dart`、`pdf_renderer_controller.dart`、`pdf_renderer_server.dart`、`lib/renderers/common/renderer_command.dart`（唯一实现者是 WebView 控制器）、`lib/renderers/common/web_renderer_helpers.dart`（仅 PDF 链路使用）、`assets/renderer/pdf/*`（约 1.5 MB）、`flutter_inappwebview`、`test/renderers/pdf/pdf_renderer_server_test.dart`、`test/renderers/common/web_renderer_helpers_test.dart`。
3. `pubspec.yaml` 移除 `assets/renderer/pdf/`；按需加 `url_launcher`；重新生成 Windows/Linux 插件注册文件。
4. 文档：`10` 状态改「已实施」；`05` §11.4 与第 1 节技术选型表（该节自带 TODO：「迁移完成后需同步更新本节与第 1 节技术选型表」）、`02` §5、`tasks/pdf-reader.md` 勾选验收并修正顶部「PDF renderer 使用 PDF.js」的过期约束；`implementation-status.md`；`docs/licenses.md` 删除 `flutter_inappwebview` 条目、**补 `dart_pdf_editor` Apache-2.0**（`pdf_document / pdf_graphics / pdf_cos` 已在该文件第 22 行记录，无需重复添加）并重新生成 `docs/generated/third-party-licenses.md`；`v1-experience-freeze.md` F-01–F-04 复核；`lib/features/settings/presentation/settings_page.dart:1087` 的硬编码许可文案删掉 `flutter_inappwebview`、补 `dart_pdf_editor`。
   **另需对齐三处文档不一致**（第四轮复审发现）：
   - `03-interaction-spec.md` §8.1 的缩放预设与实现不符（见 §10 待决 1），按最终裁决更新。
   - `03-interaction-spec.md` §8.3 写「扫描版 OCR 是后续功能」，而 `v1-experience-freeze.md` §5 与 `tasks/pdf-ocr-optional.md` 都把手动识别可见页定为 v1 必做（策略 S-B）。以冻结文档为准，修正 §8.3 的表述，并让 `tasks/pdf-ocr-optional.md` 的 Phase 划分与之保持一致（Phase 2「范围 OCR + 搜索索引」中的搜索索引仍属延后，只保留范围识别）。
   - `docs/manual-samples.md` 的样本清单已是权威；`poc_pdf_canvas/README.md` 里重复的样本描述应删除或改为指向它。
5. `poc_pdf_canvas/` 的 7 个样本按**权威来源**处理，不要再从 `dist/` 取：
   - **权威生成器是 `tool/generate_manual_samples.dart`**（输出默认 `.codex-run/samples/`）。它生成 `standard-text.pdf`（3 页）、`large-text.pdf`（80 页）、`image-only.pdf`、`broken.pdf` 四个。
   - `poc_pdf_canvas/tool/make_samples.dart`（已 git 跟踪，需外部 CJK 字体路径参数）只生成 `chinese-embedded.pdf` 与 `vector.pdf`。
   - `chinese.pdf` 来源不明：`poc_pdf_canvas/README.md` 声称它与上述四个同来自 `dist/`，但 `find dist -name chinese.pdf` 无结果；实测那四个与 `dist/pagesage-0.1.0-preview-20260716/samples/` 下的文件**字节完全相同**（`broken` 48 B、`image-only` 609 B、`large-text` 33,554 B、`standard-text` 1,457 B）。因此 `dist/` 只是**构建产物里的副本**，不能作为权威来源；`chinese.pdf` 需单独确认是否还需要。
   - 迁移方案：`test/fixtures/pdf/` 只放自动化需要的最小集，由 `tool/generate_manual_samples.dart` 生成后提交（4 个文件合计约 36 KB，可入库）；`large-text` 80 页留给手工性能验证，不入库；`make_samples.dart` 移到 `tool/`，并补字体缺失时跳过的逻辑（否则新机器/CI 上会失败）。手工验收样本仍按 `docs/manual-samples.md` 走 `.codex-run/samples/`，与 `test/fixtures/` 分开。

验收：三端打开/滚动/选择/搜索/标注/OCR 全通过；`flutter analyze` 0；`flutter test` 全绿；包体减少；`flutter_inappwebview` 不再出现在 `pubspec.lock`。

### S8 验证收口（2–3 天）

自动化（新增于 `test/renderers/pdf/`）：

- `canvas_geometry_test.dart`：旋转 0/90/180/270 的 widget↔page 往返、crop box 非零原点。
- `canvas_zoom_test.dart`：四种模式解析、像素预算、缩放锚点。
- `canvas_locator_test.dart`：`scrollOffset` 往返、页内比例恢复、locator JSON 兼容。
- `canvas_selection_test.dart`：CJK 单字/标点/英文分词、跨页矩形、旋转页。
- `canvas_search_test.dart`：小样本 fixture（`standard-text.pdf`、`chinese-embedded.pdf`）命中与取消。

手工矩阵：

| 平台 | 样本 | 重点 |
| --- | --- | --- |
| Linux（必测） | `standard-text` / `large-text` / `chinese-embedded` / `image-only` / `broken` | 全功能 + 性能基线 |
| Windows | 同上 | 回归、Ctrl+滚轮、菜单锚点 |
| Android | 同上 + 真实设备 | 双指、长按手柄、OCR、滚动发热 |

每个未通过项按 `docs/manual-samples.md` 的格式记录平台/窗口/主题/结果。

## 6. 要完成的工作（Definition of Done）

逐条对应 `docs/tasks/pdf-reader.md` 未勾选项与 v1 冻结项：

- [ ] 常规 PDF 可打开并连续滚动（S2）
- [ ] 退出后恢复到对应页与页内位置（S2）
- [ ] 缩放与适合宽度无错位/裁切（S1）
- [ ] 页码跳转可靠（S0）
- [ ] 单页/双页模式可用（S2，共用 `ReaderSettings.readerMode`）
- [ ] outline 跳转 + 无 outline 页码回退（S4）
- [ ] 文本层检测如实上报，扫描件禁用划词/搜索并给出原因（S0）
- [ ] 桌面拖选、移动长按选词 + 手柄、跨页选择（S3）
- [ ] 书内搜索可取消、可跳转（S4）
- [ ] 标注显示与点击命中（S5）
- [ ] **F-02：永久标注不盖住未选中的下一行**（S5，含文本 PDF 与 OCR 页；S7 删除 WebView 后由 Canvas 独立满足）
- [ ] OCR 管线打通：导出图 → overlay → 划词（S5，Linux 用假引擎验管线；真实识别质量在 Android/Windows 真机验，S7/S8）
- [ ] OCR 后的能力上报如实：无原生文本层时 `search: false`、`textSelection: true`（S5）
- [ ] 加密/损坏 PDF 明确错误（S0/S6）
- [ ] 主题纸色与夜间模式（S6）
- [ ] 大文档滚动性能与内存基线（S6/S8）
- [ ] 三端回归通过（S7/S8）
- [ ] WebView 渲染器与 PDF.js 资源删除（S7）
- [ ] 文档、许可、任务清单同步（S7）
- [ ] 90°/270° 旋转页布局、选区、标注全部正确（S1/S3/S6，含 replay 路径 `rotation: null`）

## 7. 风险与应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 双指缩放与连续滚动争抢手势 | 缩放卡顿/误滚 | 连续模式用 ScaleGestureRecognizer + 偏移补偿；分页模式才用 InteractiveViewer |
| worker isolate 在部分平台/环境不可用 | 回退到主线程卡顿 | `record()` 返回 null 时的本地回退路径必须保留并测试 |
| 大页面 3× 光栅受 64 MP 上限 | 高倍下略模糊 | 记录为已知限制；tile 化留给后续里程碑 |
| 未嵌入字体的 CJK 走系统字体替换 | 字形与原 PDF 不完全一致 | 迁移文档 §6.5 已声明；在关于/设置保留说明，不视为回归 |
| 页缓存内存 | 移动端 OOM | 调 worker 的全局预算（`pdfRenderWorkerCacheBudgetBytes`）并在 `didHaveMemoryPressure` 里调 `PdfCacheRegistry.instance.handleMemoryPressure()`；注意 Flutter 的回调名是 `didHaveMemoryPressure`，不是 iOS 原生的 `didReceiveMemoryWarning` |
| 旋转页/非零 crop box | 选区与标注偏移 | 全部走 `PdfPageGeometry`，并用旋转样本做自动化断言 |
| 分支 CRLF 噪声 | 评审不可读、冲突放大 | S0 先用 `.gitattributes` 归一化，独立提交 |
| **F-02 随 WebView 一起被删** | 冻结的 P0 约束静默失效，且因为测试里没有对应断言，CI 也不会发现 | S5 就把 F-02 链路移植到 Canvas 并加断言（见 §4.7.1），不等到 S7；DoD 单列一条 |
| 删除 WebView 过早 | 平台回归无处回退 | S7 内先切后删，Windows/Android 手工通过后再删代码 |

## 8. 回退策略

- S0–S6 期间 Canvas 仅在 Linux 生效，Windows/Android 不受影响；任一平台出问题可只回退 `reader_page.dart` 的分支。
- S7 删除前保留一个 `poc/pdf-graphics-canvas` 分支提交点；删除后回归失败可 revert 该提交恢复 WebView 渲染器，不影响数据层。
- 数据层零迁移：locator 字段不变，`scrollOffset/zoom/excerpt` 本就存在于 schema。

## 9. 提交与验证约定

每个切片一个提交，提交信息写清楚「改了什么 + 如何验证」，例如 S1：

```text
Add real zoom modes to the canvas PDF renderer

Layout now uses PdfPageRenderer.pageSize scaled by the resolved mode
instead of relying on FittedBox; raster density follows layout scale so
fit-width/fit-page/actual/custom visually differ. Pinch and Ctrl+wheel
commit through the host as a custom scale.

Verified on Linux with standard-text.pdf and chinese-embedded.pdf:
all four modes, 3x zoom selection alignment, persisted scale restore.
```

每步固定验证：

```bash
dart format .
flutter analyze
flutter test
```

平台相关改动补：`flutter run -d linux` 与 `flutter build windows --debug`（有 Windows 环境时）。

## 10. 待决事项

1. 缩放上下限统一：阅读器工具栏当前 0.7–2.4（`reader_page.dart:1793` clamp、设置页滑块 `min: 0.7, max: 2.4, divisions: 17`，`:7225` 附近），旧 bridge 与双指建议 0.5–3.0。建议本期统一为 0.5–3.0，设置页滑块同步（divisions 相应调整）。
   **与规格的冲突需一并裁决**：`docs/03-interaction-spec.md` §8.1 列的是「适合宽度 / 适合页面 / 100% / 125% / 150%」四个离散预设，而当前实现是连续滑块，`reader_page.dart` 里搜不到任何 1.25 / 1.5 / 125 / 150。要么保留滑块并更新 §8.1，要么恢复四个预设并与四种 `PdfZoomMode` 的关系重新定义。这个问题必须在 S1 前定，否则 S1 做出来的缩放 UI 和规格对不上。
2. 双页模式是否在 v1 保留：旧 WebView 桌面端有，规格 `docs/02` §5.5 有；计划保留，但窄屏强制单页。实现方式是 Canvas 直接消费 EPUB/PDF 共用的 `settings.readerMode`，复刻 bridge `preferredDisplayMode()` 映射，不新增字段。
3. `poc_pdf_canvas/` 删除还是保留：建议删除应用、保留样本生成脚本（迁到 `tool/make_samples.dart`），自动化用小样本迁入 `test/fixtures/pdf/`。
4. **窄屏缩放启发式是否继承**：旧 bridge 在窄屏且用户值 ≤1.25 且 `widthScale < 1.2` 时压到 `widthScale`，打开时窄屏 `custom` 直接改判 `fit-width`（`bridge.js:2877`）。建议**继承**——该启发式正是为修复"360px 手机上 600pt 页按 1.2× 铺开导致横向混乱与页面变形"而存在，放弃它会在 Android 上重新引入这个已知回归。确认后写进 S1 步骤 6。

## 11. 参考

- `docs/10-pdf-renderer-migration.md`：决策、POC 结果、实现约束。
- `docs/tasks/pdf-reader.md`：功能范围与验收。
- `docs/v1-experience-freeze.md`：F-01–F-04。
- `lib/renderers/pdf/pdf_canvas_view.dart`、`pdf_canvas_renderer.dart`、`pdf_selection_controller.dart`：现状实现。
- `dart_pdf_editor` 5.1.1：`renderer.dart`（`renderPicture` / `pictureFromCommands`）、`render_worker.dart`、`page_geometry.dart`、`page_export.dart`、`ocr.dart`。
- `poc_pdf_canvas/README.md`：POC 验证结论与两个必须照抄的实现约束。
- `poc_pdf_canvas/tool/make_samples.dart`：CJK 嵌入样本生成脚本（仅 `chinese-embedded` / `vector`）。
- `tool/generate_manual_samples.dart`：**样本的权威生成器**（`standard-text` 3 页 / `large-text` 80 页 / `image-only` / `broken`），输出到 `.codex-run/samples/`。
- `docs/manual-samples.md`：手工验收样本的使用规则（不入资源包、不放 `assets/`）。

## 12. 复审修订记录（2026-10-20，前两轮）

本计划成文后按代码逐条复核，修订如下。原文中站得住的部分（14 个缺陷、CRLF 噪声、worker/geometry/export/outline API 可用性、`itemExtentBuilder` 可用性、1.5 MB 资源规模）未改动。**第一轮复审自身有 1 处误判（下表第 3 行）与 2 处不精确（第 1、2 行），已在第二轮复核中用代码证据推翻/修正**——这也是保留本表的原因：修订记录本身也需要被审计。

| # | 原文 | 修正 | 依据 |
| --- | --- | --- | --- |
| 1 | §4.7 直接让 Canvas 调 `PdfPageExport.exportPage` | 指出类型名冲突：`pdf_renderer_controller.dart:9` 已有同名 `final class PdfPageExport`。**第三轮进一步收紧**：宿主只用 `.bytes`，四个尺寸字段从未被读取，因此不必改名，直接删掉该类、接口返回 `Uint8List?` | 两个同名类并存时 Dart 不允许无前缀引用；`reader_page.dart:2788` |
| 2 | §5 S5「按已加载 OCR 页集合重建 OCR 状态」 | 取消该步骤。`_restoredOcrPages`/`_ocrOverlayToken`/`_ocrOverlayPage`/`_ocrOverlayBlocks` 全在宿主持有并经 config 下发，Canvas 只需补 `ocrOverlayToken` 字段 | `reader_page.dart:111-121`、`:6904-6905`、`_restoreOcrOverlaysForVisiblePages`（`:2895`） |
| 3 | §4.3/§5 S2 说改 `ReaderMode.paged`（第一轮曾误判 `ReaderMode` 只被 EPUB 使用，建议新增 `pdfDisplayMode`） | **第二轮复核推翻第一轮结论**：`settings.readerMode` 是 EPUB/PDF 共用字段，bridge 一直在消费（`web_renderer_helpers.dart:117` 传 `readerMode`，`preferredDisplayMode()` `bridge.js:135` 映射 `paged → 窄屏 single / 宽屏 double`）。结论回到原文：Canvas 直接消费 `readerMode` 并复刻映射，不新增字段，避免双份显示模式状态 | `bridge.js:135-144`、`web_renderer_helpers.dart:117`、`pdf_renderer_view.dart:90` |
| 4 | §4.2 `custom` = `pdfScale.clamp(0.5, 3.0)` | 补窄屏启发式（`≤1.25` 且 `widthScale < 1.2` 时压到 `widthScale`；打开时窄屏 custom 改判 fit-width），列为待决 4 并建议继承 | `bridge.js:1010` `resolveZoomForPage`、`bridge.js:2877` |
| 5 | §5 S4「`url_launcher` 已是传递依赖，写明理由即可」 | 收紧表述：确为 transitive（`pubspec.lock:1046`），但新增直接依赖会注册平台插件。**第三轮修正平台数**：仓库只有 `android/linux/web/windows` 四个平台目录，不是「五端」 | `dart_pdf_editor/pubspec.yaml:44`；`lib/` 当前零使用；`ls -d android ios linux macos windows web` |
| 6 | §4.4 自建 256/96 MB 页缓存 LRU | 改为优先调 worker 自带 LRU（默认 72 MB / 64 条 / 250000 commands，全局变量可调，已接内存压力信号），不叠第二层 | `render_worker.dart:1335` `PdfCachingRenderWorker`、`:64/:80/:95` 默认常量 |
| 7 | §4.4 未提 rotation 二次翻转风险 | 新增显式检查项：replay 路径必须 `PdfPageRenderPlan(rotation: null)`，禁止再传 `page.rotation`，否则 90°/270° 页转 720° | `pdf_canvas_renderer.dart:56-68` 手写旋转 + `renderer.dart:347` `pictureFromCommands` 内部 `_applyPageTransform` |
| 8 | §11 引用 `tool/make_samples.dart` | 改为 `poc_pdf_canvas/tool/make_samples.dart`；样本是 7 个而非 5 个；`test/fixtures/` 当前不存在，需新建 | `git ls-files poc_pdf_canvas`；目录不存在 |

另有两处补充：S0 的 `flutter analyze` 验收从「0 error」扩展到同时清理现有 16 个 info/warning（避免长期掩盖真问题）；§7 风险表之外在 S0 步骤 2 补了「`sourceRect` 改全局像素同时影响选区与标注两条路径，验收必须都测」。S0 施工顺序同步调整：先修契约类缺陷，几何集中与旋转页修正推迟到 S1，避免同一处改两遍。

## 13. 第三轮复审：会影响可执行性的问题（2026-10-20）

前两轮聚焦"文档与代码是否一致"，第三轮改为检验"照着做能不能跑通"。方向性结论仍然成立，但发现 5 个会影响排期或验收的问题。

> **部分条目已被第四、五轮修订**：第 2 行（"搜索覆盖 OCR 文本"）因超出冻结范围而作废，见 §14.1-2；第 5 行（样本来源）中"`chinese.pdf` 来自 `dist/`"的说法经字节比对不成立，见 §14.2-2。下表保留原样以维持审计链。

| # | 问题 | 影响 | 处理 |
| --- | --- | --- | --- |
| 1 | **S5 的 OCR 在 Linux 上无法执行**：`ocrEngineProvider` 只在 Android/Windows 返回真实引擎，其余为 `StubOcrEngine`（`supportsPdfPageOcr => false`，`recognize` 抛异常）；而 Canvas 在 S7 前只在 Linux 生效 | S5 验收「识别后能划词」在开发平台无路径，只能盲写 | 增加仅测试用的假 OCR 引擎验证管线；真实识别移到 S7 后真机。已写入 §4.7 与 S5 步骤 8 |
| 2 | **搜索未覆盖 OCR 文本**：S4 搜索走 `PdfTextExtractor.extract`，扫描页为空；S5 却在验收里要求"搜索到 OCR 文本"，步骤中无对应实现 | 验收项无法满足 | ~~S5 新增步骤 6：先取原生文本，为空回退 OCR 块文本。已写入 §4.7~~ **已作废**：该方向超出 `v1-experience-freeze.md` §5 的冻结范围，改按 §14.1-2 处理 |
| 3 | **缺陷 8 被低估为"可能不生效"，实为确定性进度损坏**：`PageController()` 无 `initialPage`，`_open()` 在 `initState` 时 build 仍是 spinner，`hasClients` 必为 false | 首开永远第 1 页却上报保存页码，一划动即覆盖进度 | §2.2 缺陷 8 改写定性；S0 增加"不开新操作重开后页码不变"的回归验收；修复方式定为首帧 `addPostFrameCallback` |
| 4 | **`PdfPageExport` 不必改名**：宿主只用 `.bytes`，`width/height/imageWidth/imageHeight` 四个字段从未被读取 | 改名方案留下死代码 | S5 步骤 1 改为直接删除该类，接口返回 `Uint8List?` |
| 5 | **样本来源写错**：`make_samples.dart` 只生成 2 个样本（`chinese-embedded`、`vector`），其余 4 个来自 `tool/generate_manual_samples.dart`，`chinese.pdf` 来自 `dist/` | S7 照着单一脚本找不齐样本 | ~~S7 步骤 5 重写为按来源分组，并补"字体缺失时跳过"的健壮性要求~~ 已按此重写；其中「`chinese.pdf` 来自 `dist/`」不成立，见 §14.2-2 |

另修正 5 处细节：

- **`scrollOffset` 有模式条件**：非连续模式一律为 0（`bridge.js:180-190`）。已写入 §4.3 与 S2 步骤 2。
- **当前页判定表述**：是 `scrollY + max(viewport.height * 0.28, 48)`，比例基准是视口高度而非页面高度。已写入 §4.3。
- **`url_launcher` 平台数是四端不是五端**：仓库只有 `android/linux/web/windows`。已改 S4 与 §12 第 5 行。
- **风险表回调名**：Flutter 用 `didHaveMemoryPressure`，库入口是 `PdfCacheRegistry.instance.handleMemoryPressure()`。已改 §7。
- **S4 搜索验收数字**：`make_samples.dart` 里「嵌入」出现 2 次，不是 3 处。已改。

### 尚未解决、需要人工确认的问题

- **双页模式与 `scrollOffset`**：非连续模式恒 0 之后，"双页内左侧页到底部"这类位置无法表达。旧 bridge 也是这个行为，属于既有一致性约束而非新缺陷；但若产品希望双页模式也恢复页内位置，需要额外设计，不在本计划范围内。
- **S5 假 OCR 引擎的实现位置**：放在 `test/` 还是 `lib/`（若放 `lib/` 需在 release 中排除）。建议放 `test/support/`，仅被 widget test 引用；但这意味着 Linux 上的"手工验证"要跑测试而非跑应用，验收方式与其它切片不同。
- **OCR 识别质量与排版的对应关系**：假引擎能验证管线，但无法验证"OCR 框是否与屏幕文字重合"这类几何正确性——那需要真实引擎输出。该验收实质上也推迟到 S7 之后。

## 14. 第四、五轮复审（2026-10-20）

第四轮换角度：不再比对"文档 vs 代码"，而是比对"计划 vs 它所引用的规范文档"，并追查原计划的遗漏项。第五轮审计第四轮的结论，**推翻了其中两条**。同样保留记录。

### 14.1 成立的发现（已写回正文）

| # | 问题 | 影响 | 落点 |
| --- | --- | --- | --- |
| 1 | **F-02 在 Dart 侧零实现**：`v1-experience-freeze.md` §3.3 把"永久标注不得盖住未选中的下一行"定为 P0 硬约束（文本 PDF 与 OCR 页一律适用），bridge 用 4 个函数实现，而 `lib/` 全库搜索 `mergeSameLineRects` / `preventAdjacentBleed` / `snapRectsToLineBands` / `lineBands` 均零命中。原计划 S7 删掉 WebView 会让这条 P0 约束**静默失效**，且 DoD 里没有对应条目 | 删除 WebView = 回归一个冻结的 P0 约束，且无人察觉 | 新增 §4.7.1（4 函数移植对照 + 绘制阶段兜底 + 下划线粗细归一化）；S5 步骤 3 与验收补 F-02；§6 DoD 补两条 |
| 2 | **OCR 搜索超出冻结范围**：`v1-experience-freeze.md` §5 策略 S-B 明写「整书 OCR / OCR 搜索 → 延后」，§4.2 也列「OCR 进 FTS 全局搜索」为延后项。第三轮把"搜索覆盖 OCR"写进 S5 验收，等于擅自扩范围 | 违反冻结文档的变更规则（§9 要求留变更记录） | §4.7 改为「OCR 搜索不在 v1 范围」；S5 验收改为搜索入口如实禁用 |
| 3 | **既有的能力误报会被继承**：`reportCapability()`（`bridge.js:147-155`）因 `nativeTextLayerAvailable \|\| ocrTextLayerAvailable` 而报 `search: true`，但 `search()` 只读 `getTextContent()`（`bridge.js:2148`），从不读 `ocrLayers` | Canvas 若照抄，会在纯扫描页给出无法工作的搜索入口 | §4.7 明确「不得继承」：无原生文本层时 `search: false`、`textSelection: true`；S5 步骤 7 与 DoD 各一条 |
| 4 | **S7 文档同步遗漏**：原计划只列 `02` §5、`03` §8 泛称，未覆盖 `03` §8.1 的缩放预设冲突、`03` §8.3「扫描版 OCR 是后续功能」与冻结文档的矛盾、`tasks/pdf-ocr-optional.md` 的 Phase 口径、`poc_pdf_canvas/README.md` 与 `docs/manual-samples.md` 的样本清单重复 | 迁移「完成」时文档仍自相矛盾 | S7 步骤 4 补三条对齐项；`03` §8.1 的裁决指向 §10 待决 1 |

### 14.2 被推翻的两条（第四轮的误判）

| # | 第四轮结论 | 第五轮审计 | 依据 |
| --- | --- | --- | --- |
| 1 | "计划要求搜索覆盖 OCR，与 WebView 实现冲突" | **不成立**：WebView 侧同样不搜 OCR 文本，不存在实现冲突。真问题是范围越界（见 14.1-2）与能力误报（见 14.1-3） | `bridge.js:2134` `search()` 的早退条件与 `:2148` 的唯一文本来源 |
| 2 | "计划把两套样本混为一谈，`poc_pdf_canvas/samples/` 与 `dist/` 是两套不同来源" | **不成立**：4 个文件逐字节相同（`broken` 48 B、`image-only` 609 B、`large-text` 33,554 B、`standard-text` 1,457 B），`poc_pdf_canvas/README.md` 也写明取自 `dist/`。真风险是 **`dist/` 是构建产物、不能充当权威**，且 `chinese.pdf` 在 `dist/` 中并不存在（POC README 的说法有误） | `cmp` 逐字节比对；`tool/generate_manual_samples.dart` 才是有权威性的生成器（产出 `standard-text` 3 页 / `large-text` 80 页 / `image-only` / `broken`） |

第四轮两次误判的共同原因：只读了计划文档与自己记忆中的代码印象，没有回到源头逐条验证。第五轮全部结论都附了可直接复核的路径与行号——**后续再要推翻本表任何一行，也应给出同等粒度的证据**。

## 15. S0 施工记录（2026-10-20）

按 §5 S0 完成，附带 3 个计划外发现。提交：`9236eb0`（换行归一）、`10f73e8`（分析基线）、`935cdb1`（宿主契约）、`e9901d9`（S0 行为测试）、本次（选区锚点与标注点击）。

### 15.1 与计划的偏差

| # | 计划 | 实际 | 原因 |
| --- | --- | --- | --- |
| 1 | 标注点击命中留到 S5（步骤 2） | **S0 已实现**：`_CanvasPage._emitAnnotationTap`，`_AnnotationBox` 带上 `annotationId`，tap 时按 z 逆序命中并发 `RendererAnnotationSelected`，`sourceRect` 为全局像素 | S0 验收要求"标注点击菜单出现在对应位置上方"，没有命中路径就无从验收；先做单层 rect 命中，S5 只补 F-02 的跨行合并与下划线粗细 |
| 2 | 拖选锚点未提及 | 改用 `DragStartBehavior.down` | 默认 `start` 把锚点记在越过 slop 的位置，按下点所在的首词会被吞掉；浏览器划词以按下点为锚 |

### 15.2 计划外发现（已修，各有回归测试）

| # | 现象 | 根因 | 覆盖 |
| --- | --- | --- | --- |
| A | 单击永远没有选区 | `_onDragEnd` 在 `_dragSelecting == false` 时直接 return，而 tap 路径从不设置该标志 | `pdf_canvas_view.dart` `_onDragEnd` |
| B | 沿单行水平拖选无结果 | 旧实现用矩形包含 + `textIn` + `indexOf`：水平拖选矩形高度为 0；重复文本总解析到第一处 | `PdfSelectionController.selectionBetween` 改为插入符到插入符（`positionNear`） |
| C | 选中高亮与标注被页面光栅盖住 | `_PicturePainter` 先画 overlay 后画 `drawPicture` | 绘制顺序改为：页面 → 高亮 → 标注 → OCR 文本 |

### 15.3 验证结果

- `flutter analyze`：4 条 info，全部落在 `poc_pdf_canvas/`（S7 删除该目录后消失）与 `pdf_canvas_renderer.dart` 的 `implementation_imports`（S6 处理）；仓库自身代码 0 error。
- `flutter test test/renderers/pdf/`：12 项通过，含：
  - 缺陷 8 回归：80 页样本停在第 40 页，用首次会话上报的 locator 重开，页码与上报值仍为 40；
  - `sourceRect` 全局像素、`zoom == 布局缩放`（1.5）、`selectionRects` 保持 0..1；
  - 扫描件能力如实上报为 `false` 且带原因，损坏文件发 `RendererFailed`。
- 视觉验证（临时 harness，已删）：在 `standard-text.pdf` 上鼠标拖选得到 `PageSage PDF sample page 1. Search`，`zoom = 1.0606 = 840/792`，`sourceRect` 落在首行上方；标注带与选区都贴合字形，点击标注命中 1 次、页外点击 0 次。
