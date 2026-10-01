# PDF 渲染迁移决策：WebView/PDF.js → pdf_graphics

版本：0.1
日期：2026-10-01
状态：技术决策已验证，迁移待实施
适用范围：`lib/renderers/pdf/`、Linux 平台支持

## 1. 决策摘要

**将 PDF 渲染从「PDF.js + `flutter_inappwebview` WebView」迁移到「`pdf_graphics` 5.1.1 + Flutter Canvas 直接渲染」，保留 Flutter 技术栈，不重写项目。**

决策依据是一次可复现的 POC（`poc_pdf_canvas/`，分支 `poc/pdf-graphics-canvas`），已在 Fedora 44 + Flutter 3.44.2 上验证渲染、文本选区、搜索、缩放四项能力。

## 2. 为什么现在做

技术债清单里，PDF 渲染是唯一的**阻塞性**项：

| 事实 | 来源 |
| --- | --- |
| `flutter_inappwebview` 最后稳定版为 6.1.5（2024-10-08），此后仅 beta，仓库最后 push 2026-02-10 | pub.dev API + 仓库 |
| 整个 PDF 链路押在该插件上 | `lib/renderers/pdf/` |
| 该插件**没有 Linux 平台实现**，Linux 上运行直接断言失败 | `flutter run -d linux` 实测：`InAppWebViewPlatform.instance != null` |
| `flutter_inappwebview_linux` 是独立 beta 包，依赖 WPE WebKit（面向嵌入式系统的 WebKit port，Fedora 官方仓库不提供） | pub.dev 包描述原文 |

结论：**现有 PDF 方案在 Linux 上不可用，且无法通过补依赖解决。** 这决定了迁移是必需而非可选。

## 3. 为什么是「换渲染器」而不是「换技术栈」

考虑过迁移到 Tauri（Linux/Windows/Android 三端），已评估并否决：

| 迁移到 Tauri 要搬的 | 规模 | 留在 Flutter 的代价 |
| --- | --- | --- |
| EPUB 渲染（`epub_renderer_view.dart` 等 4 个文件） | 4015 行 | **零改动**（纯 Flutter CustomPaint，不依赖 WebView） |
| PDF 桥接层 | 3225 行 JS + 712 行 Dart | 仅替换 `pdf_renderer_view.dart`（358 行） |
| OCR 原生实现 | 1684 行（WinRT C++ 632 + Kotlin 341） | 零改动（`OcrEngine` 接口隔离良好） |
| Drift schema / 迁移 | 全量 | 零改动 |

**关键不对称**：EPUB 那条线已经是纯 Flutter 实现，根本不碰 WebView。所以「消掉 WebView」这个目标，在 Flutter 内部就能达成——代价是替换一个渲染器，换栈的代价则是重写全部。

同时，换栈也**治不好**桌面端：Tauri 桌面端同样使用系统 webview，WebView2 stale 缓存那类问题依旧存在。

## 4. 方案：pdf_graphics 5.1.1

### 4.1 依赖

同作者的 `dart-pdf` monorepo 提供三个包，均为 Apache-2.0、纯 Dart：

| 包 | 当前项目版本 | 目标版本 | 作用 |
| --- | --- | --- | --- |
| `pdf_graphics` | 1.4.7 | 5.1.1 | 渲染引擎 + `PdfDevice` 接口 |
| `pdf_document` | 1.4.7 | 5.1.1 | 页树 / 注释 / 表单 |
| `dart_pdf_editor` | — | 5.1.1 | 提供 `CanvasPdfDevice`（Flutter Canvas 后端） |

`dart_pdf_editor` 是**纯 Dart 包，无任何原生插件**，因此不引入平台通道依赖。

### 4.2 迁移后删除的内容

```text
lib/renderers/pdf/pdf_renderer_server.dart   182 行  dart:io HttpServer + cache-bust hack
assets/renderer/pdf/bridge.js              3225 行  手写桥接层
assets/renderer/pdf/pdf.min.js / worker            vendored PDF.js (~1.5MB)
flutter_inappwebview 依赖
```

连带消失：WPE WebKit 依赖、WebView2 stale 缓存 hack（`pdf_renderer_server.dart:9` 的注释记录了该问题）、以及历史上两个移动端 PDF 冻结提交所针对的问题域。

## 5. POC 验证结果

环境：Fedora 44 / Flutter 3.44.2（revision `c9a6c48423`）/ debug 构建。

### 5.1 渲染

| 能力 | 样本 | 结果 |
| --- | --- | --- |
| 系统字体回退中文 | `chinese.pdf` | 通过 |
| **嵌入 CJK 字形**（`/CIDFontType2`） | `chinese-embedded.pdf`（Sarasa Mono SC） | 通过，等宽特征可见，证明走真实轮廓路径 |
| 生僻字 `龖 靐 齾 爩` | 同上 | 通过 |
| 图像解码 | `image-only.pdf` | 通过 |
| 线性渐变 ×2、圆角矩形 | `vector.pdf` | 通过 |
| 双三次贝塞尔曲线 | 同上 | 通过，光滑无多边形化 |
| 描边宽度 3pt / 1.5pt | 同上 | 通过 |
| 多页文档 | `large-text.pdf`（80 页） | 通过 |

### 5.2 文本选区与搜索

在嵌入 CJK 字体的样本上验证：

| 能力 | API | 结果 |
| --- | --- | --- |
| 拖选取词 | `PdfTextExtractor.textIn(rect)` | 返回 15 字完整标题 |
| 点击定位 | `positionNear(x, y)` | 光标 index 103，上下文正确 |
| 选区几何 | `quadsFor(start, end)` | 四角点，视觉**严丝合缝**贴合目标文字 |
| 缩放一致性 | 同上，1x / 2x / 3x | 三档均正确 |
| 搜索 | `findAll(query)` | 3 处命中，索引与文本精确 |

`PdfTextQuad` 提供四个角点而非包围盒，因此旋转文字的选区也能正确贴合；每点带 `isRightToLeft`，为 RTL 语言预留。

### 5.3 性能

debug 构建下整页渲染（含解释器、字体解析、PNG 编码）：

| 缩放 | 耗时 |
| --- | --- |
| 1x | 135 ms |
| 2x | 164 ms |
| 3x | 未取到独立计时，但产物正常 |

**该数据仅供参考**：`flutter run --debug` 未开启 release 优化，且包含 PNG 编码开销，不能代表真实滚动性能。

## 6. 迁移必须遵守的实现约束

以下三点是 POC 实测踩出的坑，**包文档未明确说明**，迁移时必须照抄 `dart_pdf_editor/lib/src/renderer.dart` 的做法。

### 6.1 页面变换：翻转支点是 `box.height`，不是 0

```dart
// 正确
canvas.scale(zoom, zoom);
canvas.translate(0, box.height);
canvas.scale(1, -1);
canvas.translate(-box.left, -box.bottom);

// 错误：翻转围绕 y=0，内容被推到负 y 区域 → 整页空白
canvas.scale(zoom, -zoom);
```

写错时**不抛异常**，只是渲染出全白页，排查成本高。

### 6.2 图片需要先做一次 scan-only 遍历

```dart
final collector = ImageCollector();
PdfInterpreter(cos: cos, device: collector, scanImagesOnly: true).drawPage(page);
final images = await decodeImages(cos, collector.streams);
// 之后把 images 传给 CanvasPdfDevice(canvas, images: images)
```

漏掉这一步，图片内容全部丢失，且同样**不抛异常**。

注：`ImageCollector` 与 `decodeImages` 未从 `dart_pdf_editor` 顶层导出（被 `show` 子句限制），需 `import 'package:dart_pdf_editor/src/image_decoder.dart';`。

### 6.3 字体行为需要如实告知用户

未嵌入字体的 PDF，中文走**系统字体替换**（渲染器注释原文：*"Text is drawn with substituted system fonts, horizontally scaled to the PDF's own metrics, until the font engine produces real glyph outlines"*）。

结果：**内容正确可读，选区准确，但字形外观与原 PDF 不完全一致。** 若产品需要「所见即原样」，必须使用嵌入字体的 PDF，或后续评估字体嵌入覆盖。

## 7. 影响范围与未验证项

### 7.1 受影响文件

```text
lib/renderers/pdf/pdf_renderer_view.dart        主要改造对象
lib/renderers/pdf/pdf_renderer_controller.dart  命令下发改为直调解释器
lib/renderers/pdf/pdf_renderer_server.dart      删除
assets/renderer/pdf/*                            删除
lib/core/search/pdf_text_extractor.dart          适配 pdf_graphics 5.x API
lib/features/reader/presentation/reader_page.dart 选区 overlay 依赖 WebView DOM，需重写
```

`RendererEvent` 契约（`lib/renderers/common/renderer_event.dart`）**无需改动**——现有事件设计与 `text` + `quads` 输出结构对应。

### 7.2 未验证项（迁移期间需覆盖）

- 大文档（数百页）滚动性能
- 注释 overlay 在 Canvas 上的叠加与命中测试
- 扫描版 PDF（现有 OCR 链路与新渲染器的衔接）
- Windows / Android 平台回归（Linux 可用不代表另两端无回归）
- 表格、公式、复杂版式的还原度

## 8. 复现方式

```bash
cd poc_pdf_canvas
flutter pub get
dart run tool/make_samples.dart      # 生成嵌入 CJK 字体与矢量图形样本
flutter run -d linux --debug        # 结果输出到 build/poc_out/
```

PDF 内容流经 FlateDecode 压缩，直接 grep PDF 二进制查不到图形算子；检查样本内容需先解压内容流。

## 9. 参考

- `pdf_graphics` / `pdf_document` / `dart_pdf_editor`：<https://github.com/ben-milanko/dart-pdf>
- 官方渲染实现参考：同仓库 `packages/dart_pdf_editor/lib/src/renderer.dart`（`_applyPageTransform`）
- 项目内 POC：`poc_pdf_canvas/`，分支 `poc/pdf-graphics-canvas`