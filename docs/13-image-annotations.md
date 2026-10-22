# 图片批注与插图文档

> 决策日期：2026-10-21
> 状态：已决策，待实施（B1 起）
> 上游需求：`docs/02-feature-spec.md` §8、`docs/tasks/annotations-and-highlights.md`（TASK-11）
> 约束来源：`AGENTS.md`（本地优先、AI 用户主动触发、渲染器不写业务数据）、`docs/privacy.md`

## 1. 目标与范围

两件事，共用一套锚点与存储：

1. **图片批注**：在书中的插图上圈选、写评论、设颜色，能在 Notebook 里回顾并跳回原图。
2. **插图文档**：把一本书的插图连同图注、页码汇总成一份可导出、可搜索的文档。

明确不做：

- 在图片上涂画（自由笔迹、箭头、贴纸）。这是图形批注，不是图片批注；走另一条决策。
- 对插图做 OCR。扫描 PDF 的 OCR 已有独立链路（`docs/tasks/pdf-ocr-optional.md`），不在此处复用。
- 自动把插图发给 AI。见 §6。

## 2. 起点：两个渲染器的图片现状

这张表决定了批次顺序，先摆出来，避免按「EPUB/PDF 一样处理」排计划。

| | PDF | EPUB |
| --- | --- | --- |
| 图片是否显示 | 是（`pdf_graphics` 直接绘制到页面画布） | **否** |
| 图片几何是否可得 | 是，`PdfPageElements.of(document, pageIndex)` 给出 `PdfContentElement`，`kind == PdfElementKind.image` 的元素带 `bounds`（PDF 用户空间）、`resourceName`、`imageWidth/imageHeight` | 否 |
| 已解码像素是否可得 | 间接（可渲染页面后裁剪），`pdf_graphics` 也能做 XObject 级解码 | 否 |
| 需要的新前置工作 | 无 | **真实渲染图片**（解压、路径解析、解码缓存、像素上限） |

EPUB 为什么「不显示」：`epub_document_loader.dart` 只取 XHTML 的 `innerText`，`<img>` 被丢弃；渲染端的 `_EpubImagePlaceholder`（`epub_renderer_view.dart`）要段落文字以 `[image` / `image:` / `figure:` 开头才触发（`epub_paginator.dart`），而加载器从不生成这种文字。也就是说这条分支目前不可达。

**因此**：B3（EPUB 显示图片）是一个独立功能，不是图片批注的子任务。它单独排期、单独验收，因为「EPUB 阅读器看不到插图」本身就是产品缺陷。

### 2.1 PDF 识别结果的可信边界

`PdfPageElements` 的文档写明了：**form XObject 内部的元素属于该 form，不在页面的元素列表里**。InDesign 导出、扫描件、部分出版系统会把插图包在 form 里。

这条必须写进设计，因为它决定了交互形态：**只做「点一下自动识别到的图」会静默漏掉一整类书**，表现是「有些书能点，有些点不到」，用户无法归因。

结论：主交互是拖框 + 吸附，识别结果只用于吸附和自动取图注，不作为唯一入口。

## 3. 数据模型

### 3.1 图片锚点

新增 `lib/domain/annotations/image_anchor.dart`：

```dart
sealed class ImageAnchor {
  const ImageAnchor();
  Map<String, Object?> toJson();
  static ImageAnchor? fromJson(Map<String, Object?> json);
}

final class PdfImageAnchor extends ImageAnchor {
  /// 1-based 页号。
  final int page;
  /// 该页图片元素按绘制顺序的序号，识别不到时为 null。
  final int? ordinal;
  /// /XObject 资源名（如 `Im1`），用于重新解析后对齐。
  final String? resourceName;
  /// 兜底：显示框（应用 /Rotate 之后）的 0..1 矩形，y 向下。
  final ReaderRect rect;
  /// 圈选范围相对该图框的 0..1 矩形；整图批注时等于 `rect`。
  final ReaderRect? region;
}

final class EpubImageAnchor extends ImageAnchor {
  final String href;          // 章节 XHTML
  final int ordinal;          // 该文档内第几个 img
  final String? archivePath;  // EPUB 内路径，内容变更后的兜底
  final ReaderRect rect;      // 相对渲染后的图片框，0..1
  final ReaderRect? region;
}
```

三条硬规则：

- **主键是「哪张图」（`page + ordinal + resourceName` / `href + ordinal`），不是坐标。** 同一张图在 `/Rotate` 不同的两版文件里矩形不同，但用户认为它们是同一张图。
- **`rect` 只作兜底。** 重新解析后找不到对应元素时，用矩形框显示「原文此处有一张被批注的图」，比整条批注消失好。
- **坐标系只有一种。** 存储一律是**显示框**（已应用 `/Rotate`）的 0..1、y 向下，与 `ReaderRect` 的既有约定一致（`pdf_selection_controller.dart` 已按此实现）。PDF 的 `PdfRect` 是 y 向上的用户空间，翻转的支点必须是显示框 —— 这是之前 PDF 迁移里「不抛异常但渲染空白」的同类坑，转换处要写单元测试。

### 3.2 annotations 表扩展

复用 `annotations` 表，`schemaVersion 4 → 5`，只 `addColumn`，不重建表：

| 列 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `target` | text | `'text'` | `text` / `image` |
| `image_anchor` | text nullable | null | `ImageAnchor` 的 JSON |

`locator` 仍然写：图片批注的 locator 表示「跳到这一页的这一处」。PDF 图片批注写 `ReadingLocator.pdf(page, selectionRects: [anchor.rect])` —— 把框**同时**存进 locator，因为跳回时渲染器没有文本可闪，只能靠这个矩形画出闪烁框。这样现有跳转、进度、导出逻辑不用改。

`selected_text` 允许空串（无图注的插图）。当前列是 not null，空串即可，不改约束。

迁移代码遵循 v3→v4 的做法：`migrator.addColumn`，不回填、不清数据。旧行默认 `target = 'text'`，语义正确。

## 4. 渲染器契约

渲染器只发事件、不写业务数据（现有硬规则）。新增两个事件：

```dart
/// 页面上识别到的图片，供主机做吸附与菜单。
final class RendererImagesDetected extends RendererEvent {
  final int page;                  // 1-based
  final List<RendererDetectedImage> images;
}

final class RendererDetectedImage {
  final int? page;            // EPUB 为 null
  final int ordinal;
  final String? resourceName;
  final ReaderRect rect;      // 显示框 0..1
  final int? pixelWidth;
  final int? pixelHeight;
}

/// 用户圈出了一块区域（可能吸附到某张图）。
final class RendererImageAreaSelected extends RendererEvent {
  final ImageAnchor anchor;     // 已吸附时带 ordinal/resourceName
  final ReaderRect sourceRect;  // 窗口坐标，用于浮动菜单定位
}
```

实施时对契约收敛了两处，理由写在下面，不要按设计稿「补回去」：

- **吸附在渲染器内部完成。** `PdfCanvasView` 拖框结束时自己调用 `snapToDetectedImage`，读 `PdfCanvasRenderer.imagesOnPage(page)`，检测列表不经过主机。吸附是纯几何判断，主机拿到同一份列表也算不出不同答案，反而要在拖动中来回传矩形。因此 `RendererImagesDetected` 目前没有生产者；类型保留，B2 的 Notebook 缩略图与图注需要主机侧列表时再启用。
- **没有 `suggestedCaption`。** PDF 的图片 XObject 没有 alt 文本，文档里也没有「哪段文字是这张图的图注」的信息；先塞一个永远为空的字段，会让人以为它在工作。等 B3 的 EPUB（`alt` / `figcaption`）与 B4 的启发式提取，和 `RendererImagesDetected` 一起启用。

配套的主机→渲染器入口：

- PDF：`imagesOnPage(page)`，由 `PdfCanvasRenderer` 用 `PdfPageElements.of` 解析一次并 LRU 缓存；解析失败返回空列表，不让书打不开。
- 保存图片：`PdfPageImageSource.exportPageRegion(pageNumber, rect)`，按显示框 0..1 裁剪页面的渲染结果（2× 密度，上限 4096 px）。与 OCR 的 `exportPageImage` 放在同一接口，读者只持有 `activePdfRendererControllerProvider`。
- EPUB：B3 之后才有。

## 5. 交互

### 5.1 创建图片批注

1. 先进入「框选图片」模式：桌面在阅读器标题栏的「更多」菜单里，移动端在底部「更多」面板的 PDF 分组里。模式开着时，状态区显示常驻提示「框选图片：拖出图片范围」和「退出」按钮，`Esc` 也退出。
2. 读者在插图附近拖出一个矩形。桌面的鼠标/触控笔拖拽一直是划词；只有模式打开时拖动才改为画框，因为同一个手势不能同时是两件事。触屏同理：模式打开时手指拖动画框（触屏原本靠长按划词，不与拖动冲突）。
3. 若命中识别到的图（重叠面积 ≥ 60%，或框整体落在某张图内，或四边对齐误差 ≤ 1% 页宽），吸附到该图边界；否则保留手绘框。
4. 弹出与文字选中同一位置、同一套样式的浮动菜单（桌面为浮动条，移动端为底部面板）：`注释此图` / `保存图片` / `复制图注`。无图注时「复制图注」置灰而不是消失，菜单布局跨格式保持一致。
5. 选择颜色、写评论 → 保存。**保存后退出模式**，拖动回到划词；从菜单 dismissed（点空白、Esc）则留在模式里，方便重画。

为什么不默认「点一下就选中整张图」：识别不全（§2.1），而且书的插图经常是多张拼在一起，整图选中无法区分。

为什么用模式而不是修饰键：修饰键在触屏上不存在，也不可发现；模式的代价是「状态可见 + 一步退出」，所以常驻提示与 `Esc` 是这条设计的一部分，不是装饰。

### 5.2 绘制

- 图片批注画**四角括号 + 1.5px 描边**，**不加填充色**。文字高亮的半透明色块用在插图上会改变图片观感，两者不能共用同一套视觉。
- 已有批注的位置显示一个小角标（图标 + 颜色，不只靠颜色），点击打开批注详情。
- 颜色枚举复用 `AnnotationColor`，但图片批注的默认色是 `blue`（文字默认 `yellow`），避免与正文高亮的视觉语言混淆。

### 5.3 Notebook 与跳转

- Notebook 增加「图片」条目类型（`_NotebookEntryType.image`），与「标注」分开列出：一页里没有文字的框混在正文标注里很难找。标题取图注，没有图注时用「图片 · 第 N 页」，副标题说明「没有图注」。
- 点击条目跳回该页并闪烁该批注框：渲染器没有文本可闪，改为读 locator 里的 `selectionRects` 画出琥珀色边框（不是填充色，避免改变图片观感）。
- 缩略图属于 B2（要先把图片提取进缓存）。
- 删除书 → 一并删除图片批注与缓存图片。删除批注 → 删除对应缓存图片。
- 修改颜色/样式时必须原样带回 `imageAnchor`，否则这条批注会退化成「没有几何的图片批注」，从页面上消失且再也找不到。已有回归测试。

## 6. 隐私红线

| 规则 | 落点 |
| --- | --- |
| 图片默认只存本地 | 不进入任何自动 AI 上下文 |
| 问这张图必须用户显式触发 | 确认面板显示缩略图、书名、页码；不提供「问全书插图」这类批量入口 |
| 日志不出现图片字节或 base64 | 新增测试断言 logger 输出不含 `data:image` / 长 base64 串 |
| 缓存图片可清理 | 设置页「清理缓存」一并清理 `<cache>/images/` |

## 7. 提取像素：先截图，后解码

| 方案 | 做法 | 优点 | 缺点 |
| --- | --- | --- | --- |
| A. 裁剪页面渲染（v1） | 用 `bounds` 换算到显示框，按 2× 显示尺寸（硬上限 4096px）渲染该页再裁 | 所见即所得；SMask、颜色空间、内联图片自动正确 | 一张图要渲染整页；清晰度受倍率限制 |
| B. 解码 XObject（后续） | `pdf_graphics` 的 `PdfImageBase` / `PdfDecodedPixels`，自行做资源解析与 SMask 合成 | 保留原始分辨率；单图成本低 | CMYK、软掩码、JPX 出错时同样「不报错、颜色不对」，风险高 |

先做 A。B 只在用户明确抱怨清晰度时再做，且必须先有小样本回归集（CMYK 封面、带 SMask 的 PNG 插图、JPX 扫描页）。

缓存位置：`<appCache>/images/<bookId>/<anchorKey>.png`。理由：派生数据、可重建、删书可清；**绝不写入书库目录，也绝不修改原始书籍文件**。

EPUB 侧（B3 之后）从 `archive` 内存流读取，沿用 `EpubDocumentLoader` 的 LRU 缓存，另加两条护栏：单图解码后像素预算上限（防解压炸弹）、连续失败标记为不可用而非无限重试。

## 8. 插图文档

输入：一本书的全部图片批注（B2 起可为「全部识别到的图片」，不要求先批注）。

结构：

```text
书名
  第 12 页 · 图 3
    [缩略图]
    图注：……（来自 alt / figcaption，可为空）
    批注：……（用户评论）
  第 40 页 · 图 1
    ...
```

导出格式：

- Markdown + 图片文件（默认）：图片拷到同名目录，正文引用相对路径。可移植、可被任意编辑器打开。
- JSON：给备份与再导入用，复用 `export_service.dart` 的既有结构。

规则：

- 图注缺失时显示「未标注」，不臆造。
- 同一页多张图按 `ordinal` 排序。
- 文档本身不落库；它是导出产物，可随时重建。这样避免出现「文档内容与批注不同步」的第二份真相。

## 9. 分批计划

| 批次 | 范围 | 依赖 | 规模 |
| --- | --- | --- | --- |
| **B1** | PDF 图片识别事件 + 拖框吸附 + 图片批注存储/绘制/Notebook/跳回 | 无 | 中 |
| **B2** | 缓存提取图片 + 图片批注导出（Markdown/JSON） | B1 | 小 |
| **B3** | EPUB 真实图片渲染（独立功能） | 无（可与 B1 并行） | 大 |
| **B4** | EPUB 图片批注，复用 B1 锚点与交互 | B1 + B3 | 小 |
| **B5** | 插图文档：汇总 + 导出 + 图注搜索 | B2（+B4） | 中 |

B1 的验收面：

- `image-xobject.pdf`（图片直接画在页面内容流里）：拖框能吸附到图片边界，保存 `ordinal + resourceName`；重启后仍在原位。已有测试。
- `image-xobject-rotated.pdf`（`/Rotate 90`）：吸附框落在旋转后的显示位置。已有坐标系测试。
- `image-only.pdf`（只有矢量图形、没有图片 XObject）：拖框不吸附但能保存手绘框。已有测试。
- 只有在模式打开时拖动才画框；模式关闭时同一拖动仍然是划词。已有测试。
- 缩放 50% / 200%：批注框随页面缩放，不偏移（框是 0..1 比例，乘视图尺寸）。
- form XObject 里的图片：`PdfPageElements` 列不出来，表现同 `image-only.pdf`，靠手绘框兜底。这是设计内行为，见 §2.1。

## 10. 需要同步的文档

- `docs/02-feature-spec.md` §8：新增 8.6 图片批注、8.7 插图文档。
- `docs/03-interaction-spec.md`：拖框、吸附、浮动菜单。
- `docs/06-data-model.md` §9：`target` / `image_anchor` 两列与 v4→v5 迁移。
- `docs/05-technical-architecture.md`：图片锚点、渲染器只读契约、缓存目录。
- `docs/09-design-system.md`：图片批注的描边式视觉（与文字高亮区分）。
- `docs/tasks/`：新增 `image-annotations.md`（B1–B2）与 `epub-images.md`（B3）。
