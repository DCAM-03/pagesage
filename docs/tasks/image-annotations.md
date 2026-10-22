# TASK-29：图片批注（B1–B2）

## 目标

让读者能圈选 PDF 中的插图、写评论、设颜色，并在 Notebook 里回顾与跳回原图；同时能把这部分内容导出。设计依据：`docs/13-image-annotations.md`。

## 进度（2026-10-21）

B1 已实现并通过验收，B2 未开始。下面「实现任务」里勾选的就是已完成项。

## 来源与边界

- 来源：`docs/13-image-annotations.md`、`docs/02-feature-spec.md` §8.6、`docs/06-data-model.md` §9。
- 不做：自由笔迹、箭头、贴纸等图形批注；插图 OCR；自动把插图发给 AI。
- 本任务只覆盖 **PDF**。EPUB 的图片要等 `epub-images.md` 先让图片真正显示出来。

## 功能范围

- 在 PDF 页面上拖出矩形，命中已识别图片边界时自动吸附（重叠 ≥ 60% 或边距 ≤ 8 logical px）。
- 浮动菜单：`注释此图` / `保存图片` / `复制图注`。
- 图片批注的颜色与评论；与文字划线共用 `annotations` 表，`target = image`。
- 四角括号描边渲染，点击角标打开详情。
- Notebook「图片」分组与跳回。
- 保存单张图到缓存目录；导出图片批注（Markdown / JSON）。

## 实现任务

### B1 数据与识别

- [x] `lib/domain/annotations/image_anchor.dart`：`ImageAnchor` 密封类，`PdfImageAnchor`，JSON 往返（损坏 JSON 返回 null，不抛）。
- [x] `annotations` 表新增 `target`（默认 `text`）与 `image_anchor`（nullable）；`schemaVersion` 4 → 5，`migrator.addColumn`。
- [x] `Annotation` / `AnnotationRepository.saveAnnotation` 增加对应参数；`DriftAnnotationRepository` 映射，空矩形拒绝写入。
- [x] `PdfCanvasRenderer.imagesOnPage(pageIndex)`：`PdfPageElements.of` 解析一次并 LRU 缓存；解析异常返回空列表，不阻断打开。
- [x] PDF 用户空间 `PdfRect` → 显示框 0..1 的转换函数，含 `/Rotate` 与裁剪框偏移；`pdf_image_detector_test.dart` 覆盖四种旋转与越界钳制。
- [x] `RendererImagesDetected` / `RendererImageAreaSelected` 事件接入 `pdf_canvas_view.dart`。吸附在视图内部完成，检测列表不经过主机。

### B1 交互与渲染

- [x] 拖框模式：`imageDragMode` 由阅读器状态经 `ReaderRendererHostConfig` 传入；打开时拖动画框（鼠标、触控笔、手指），关闭时不变。
- [x] 模式常驻提示 + 「退出」按钮 + `Esc`；保存一条批注后自动退出，菜单被 dismiss 时留在模式内。
- [x] 吸附算法抽成纯函数 `snapToDetectedImage`（覆盖 ≥ 60%、整体在内、四边误差 ≤ 1%）。
- [x] 浮动菜单复用文字选中位置与样式：桌面 `_ImageActionOverlay` 浮动条，移动端底部面板。
- [x] 批注描边绘制；点击框打开既有标注菜单（样式 / 笔记 / 删除）。
- [x] Notebook 图片条目类型；跳回时用 locator 里的矩形画琥珀色闪烁框（图片没有文本可闪）。
- [x] 「保存图片」走 `PdfPageImageSource.exportPageRegion` + 系统保存对话框，写入用户选择的位置。
- [x] 修复：修改图片批注颜色/样式时带回 `imageAnchor`，否则该批注会丢失几何。
- [ ] 删除书籍 / 删除批注时一并清理关联缓存图片（缓存目录随 B2 一起建立）。

### B2 提取与导出

- [ ] 裁剪页面渲染提取单图：2× 显示尺寸，硬上限 4096px，写入 `<cache>/images/<bookId>/`。
- [ ] `export_service.dart` 增加图片批注导出（Markdown + 图片目录、JSON）。
- [ ] 设置页「清理缓存」覆盖 `<cache>/images/`。

## 涉及模块和文件

- `lib/domain/annotations/annotation.dart`、`image_anchor.dart`
- `lib/core/database/app_database.dart`（表定义与迁移）
- `lib/core/database/drift_content_repositories.dart`
- `lib/renderers/common/renderer_event.dart`
- `lib/renderers/pdf/pdf_canvas_renderer.dart`、`pdf_canvas_view.dart`、`pdf_annotation_lines.dart`
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/export/application/export_service.dart`
- `test/renderers/pdf/`、`test/features/reader/`

## 数据与接口

- `annotations.target`：`text` | `image`。
- `annotations.image_anchor`：`{"kind":"pdf","page":12,"ordinal":3,"resourceName":"Im1","rect":{...},"region":{...}}`。
- 坐标系：显示框（应用 `/Rotate` 后）的 0..1，y 向下。
- 锚点主键是「哪张图」，`rect` 只作兜底。

## UI 与交互

- 拖框即标注，不要求先点中图片：识别不全（form XObject）时仍要能标注。
- 图片批注用描边不用填充；默认色 Blue。
- 浮动菜单与文字选中一致，不新造一套。
- 无图注时菜单里的「复制图注」置灰并说明原因。

## 验收标准

- [x] 图片在页面内容流中的 PDF（`image-xobject.pdf`）：拖框吸附，锚点带 `ordinal + resourceName`。
- [x] 图片在 form XObject 中的 PDF：不吸附，但能保存手绘框（`image-only.pdf` 等价路径已测）。
- [x] `/Rotate 90` 页面：批注框落在正确的显示位置（坐标单元测试）。
- [x] 缩放：批注框按 0..1 比例绘制，随页面缩放。
- [x] Notebook 图片条目可跳回并闪烁。
- [x] 框选模式关闭时，同一拖动仍是划词。
- [ ] 重启后仍在原位 —— 需要真实应用手动验证一次（schema v5 往返已有测试）。
- [ ] 删除批注后缓存图片被清理（B2）。
- [ ] 导出 Markdown 中的图片相对路径可被普通编辑器打开（B2）。

## 测试与验证

- 单元测试：锚点 JSON 往返、矩形旋转/翻转转换、吸附阈值。
- Widget 测试：拖框 → 菜单 → 保存 → 重新打开后渲染。
- 真实样本：`image-only.pdf`、`standard-text.pdf`，以及一本带旋转页与 form XObject 图片的 PDF（需补进 `docs/manual-samples.md`）。
- `dart format .`、`flutter analyze`、`flutter test`。

## 依赖与风险

- 依赖：无前置任务。
- 风险一：`PdfPageElements` 不列 form XObject 内部元素，识别率天然不完整 —— 已通过「拖框为主、识别为辅」规避。
- 风险二：拖框手势与文字拖选冲突。需要明确的模式切换或按区域判定，否则会破坏现有划线。实施前先用现有手势测试确认不会回归。
- 风险三：旋转页的坐标翻转是静默错误的高发点（不抛异常、位置偏）。必须用固定样本的坐标断言守住，不靠目测。
