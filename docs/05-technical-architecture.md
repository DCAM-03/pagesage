# PageSage 技术架构文档

版本：0.1  
日期：2026-06-13  
状态：详细技术架构  

## 1. 技术目标

PageSage 的技术架构需要满足：

- Linux、Android 和 Windows 测试分发；平台验收边界见[测试版说明](beta.md)。
- 数据本地优先。
- EPUB/PDF/Markdown 渲染可替换。
- MOBI/AZW 与外部转换工具暂缓。
- 搜索、笔记、AI 与阅读器位置稳定关联。
- 后续可以扩展 iOS、macOS。

## 2. 技术栈

| 层级 | 技术 |
| --- | --- |
| UI | Flutter |
| 语言 | Dart |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 本地数据库 | SQLite |
| ORM | Drift |
| 全文搜索 | SQLite FTS5 |
| EPUB 渲染 | Flutter-native renderer |
| Markdown 渲染 | 复用 EPUB 文档模型与 Flutter-native renderer |
| PDF 渲染 | `pdf_graphics` + Flutter Canvas（见 `10-pdf-renderer-migration.md`） |
| MOBI/AZW 转换 | 暂缓 |
| 本地文件 | path_provider + file_picker |
| 安全存储 | flutter_secure_storage |
| 错误脱敏 | `PrivacySanitizer`；任务错误在展示前脱敏 |
| 测试 | flutter_test + integration_test |

## 3. 架构分层

```text
Presentation Layer
  Flutter screens, widgets, panels, dialogs

Application Layer
  Use cases, controllers, state notifiers, task orchestration

Domain Layer
  Entities, value objects, repository interfaces

Data Layer
  Drift DAOs, local file repositories, settings stores, search index

Renderer Layer
  EPUB/Markdown native renderer, PDF Canvas renderer, locator/event protocol

Platform Layer
  File picker, secure storage, native OCR, OS integration
```

依赖方向：

```text
Presentation -> Application -> Domain
Data -> Domain
Renderer -> Domain contracts
Platform -> Application/Data adapters
```

规则：

- UI 不直接操作数据库。
- WebView 不直接写业务数据。
- 数据库表结构不暴露给 UI。
- AI Provider 通过接口抽象。
- 平台能力通过 adapter 暴露。

## 4. Flutter 目录结构

建议结构：

```text
lib/
  main.dart
  app/
    pagesage_app.dart
    router.dart
    bootstrap.dart
    theme/
      app_theme.dart
      reader_theme.dart
  core/
    database/
      app_database.dart
      migrations.dart
      tables/
      daos/
    files/
      app_paths.dart
      file_repository.dart
      hash_service.dart
    search/
      search_indexer.dart
      search_repository.dart
    tasks/
      task_models.dart
      task_cancellation.dart
    platform/
      file_picker_service.dart
      platform_providers.dart
      open_file_location_service.dart
    security/
      secure_store.dart
    logging/
      privacy_sanitizer.dart
  domain/
    books/
      book.dart
      book_repository.dart
      reading_position.dart
    annotations/
    notes/
    search/
    ai/
  features/
    library/
      presentation/
      application/
    import/
    reader/
    search/
    notes/
    settings/
    ai/
  renderers/
    common/
      renderer_event.dart
    epub/
      epub_renderer_controller.dart
    pdf/
      pdf_renderer_controller.dart
assets/
  renderer/
    epub/
    pdf/
  images/
```

当前实现中的具体职责归属：

- `core/database/drift_*_repository.dart` 各自实现对应领域仓储，`database_providers.dart` 负责装配。
  locator 数据库解码由 `drift_locator_mapping.dart` 共享；数据库 schema、DAO 与生成入口保持原位。
- 阅读页负责会话与页面编排；`reader_renderer_host.dart` 负责渲染器装配，
  `reader_annotations_host.dart` 是只订阅批注并装配渲染器的叶子宿主，
  `reader_settings_sheet.dart` 管设置面板；目录按载体拆为
  `reader_desktop_toc_pane.dart`、`reader_epub_toc_sheet.dart`、
  `reader_pdf_toc_sheet.dart`，共享树遍历与行模型位于 `reader_toc_tree.dart`，
  `reader_context_empty_state.dart` 提供这些阅读组件共用的空状态。桌面目录接收文档 loader，
  不反向导入阅读页。
- `reader_notebook.dart` 管桌面 / 移动 Notebook 的列表、条目排序与菜单；查询 provider 统一归属
  `features/reader/application/reader_notebook_providers.dart`。正文菜单与 Notebook 共用
  `reader_annotation_editor.dart`、`reader_annotation_actions.dart`、`reader_bookmark_actions.dart`，
  对话框与 Snackbar 保留在 presentation，不反向依赖阅读页；页面仍负责阅读会话和工具编排。
- `reader_search_pane.dart` 管桌面 / 移动书内搜索的输入、结果导航与片段操作；
  `application/in_book_search_controller.dart` 管防抖和请求身份，输入变化、清空及释放会使旧请求失效。
  `reader_context_pane.dart` 只装配搜索 / Notebook / AI 页签；复用设置模型的 `ReaderContextTab`，
  图标与标签放在 presentation 扩展中，不再维护同名值的第二套枚举及名称转换。
  页签、侧栏尺寸和展开状态仍由阅读页持久化；搜索保存片段后刷新原书籍的笔记查询，
  由 `application/reader_excerpt_note_service.dart` 协调保存与查询刷新，
  不依赖保存发起组件在异步完成时仍存活。
- `reader_selection_actions.dart` 管文字 / 图片选区的动作组件与 presentation 枚举；阅读页管理
  浮层、当前菜单身份及动作编排。旧菜单结束只能清理自己的状态，移动端更新现有选区面板，
  不为每次选区变化叠加新路由。`reader_excerpt_editor.dart` 管摘录输入与草稿返回，
  与搜索摘录共用上述 application 服务，保存发起时的书籍、原文和定位不随后续 UI 变化漂移。
- `reader_image_actions.dart` 管图片框选菜单的动作枚举、桌面浮动菜单内容和移动底部菜单；
  阅读页仍统一管理与文字选区共享的 overlay 生命周期和定位。
  `application/reader_image_annotation_service.dart` 持久化图片批注，并在写入完成后异步导出
  裁图到缓存；缓存失败不影响已保存批注。页面保留文件选择器交互和短暂状态提示。
- `reader_ocr_overlay_controller.dart` 管 OCR 叠加的令牌、双页队列、会话内已恢复页集合与
  恢复代际；`application/reader_ocr_coordinator.dart` 负责可见页解析、显示页导出重试与
  缓存叠加查询；阅读页只发起流程、显示状态并读取当前快照，不再分别维护这些字段。
  `reader_ocr_result_sheet.dart` 管 OCR 结果在桌面对话框与移动底部面板中的复制 / 问 AI 呈现，
  不持有书籍或定位状态，避免识别流程与浮层生命周期互相拖拽。

## 5. 状态管理

使用 Riverpod。

Provider 分类：

- `RepositoryProvider`：数据库、文件、搜索、AI。
- `ServiceProvider`：文件选择、外部命令、安全存储。
- `ControllerProvider`：页面逻辑。
- `StateProvider`：轻量 UI 状态。
- `StreamProvider`：任务进度、AI 流式回答。

规则：

- 页面只监听 controller 暴露的状态。
- Controller 调用 use case 或 repository。
- Repository 返回 domain model，不返回数据库 row。
- 长任务通过 task queue 暴露进度。

示例：

```dart
final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, LibraryState>(
  LibraryController.new,
);
```

## 6. 路由设计

使用 go_router。

路由：

```text
/
/library
/search
/notes
/settings
/book/:bookId
/book/:bookId/reader
/book/:bookId/details
/settings/ai
```

移动端：

- 主页面使用 ShellRoute + bottom navigation。
- Reader 独立全屏 route。

桌面端：

- 主页面使用 ShellRoute + side navigation。
- Reader 可以是独立页面，也可以占据主内容区。

## 7. 本地文件架构

应用数据目录：

```text
PageSageData/
  library/
    books/
    covers/
  database/
    pagesage.sqlite
  cache/
    render/
    thumbnails/
  logs/
  exports/
```

文件命名：

```text
library/books/<hash-prefix-2>/<hash-prefix-4>/<book-id>.epub
library/books/<hash-prefix-2>/<hash-prefix-4>/<book-id>.pdf
library/books/<hash-prefix-2>/<hash-prefix-4>/<book-id>.md
library/covers/<book-id>.jpg
```

规则：

- 导入时复制到应用目录。
- 数据库记录应用目录路径和原始路径。
- 应用不依赖原始路径继续存在。
- 删除应用副本不删除原始文件。
- Markdown 文件夹书原地读取：`libraryFilePath` 指向用户目录，应用不写入该目录，移除书时不删除目录。

## 8. 数据库架构

使用 Drift 管理 SQLite。

核心表：

- books
- categories
- tags
- book_tags
- reading_progress
- bookmarks
- annotations
- notes
- ai_conversations
- search_chunks
- app_settings
- import_tasks

FTS5：

- `search_chunks_fts`
- 使用 external content table。
- search_chunks 更新后同步 FTS。

迁移：

- 每个 schema 版本有明确 migration。
- 禁止删除用户数据式迁移，除非有备份。
- 开发期可以提供 reset database debug action。

## 9. 导入架构

导入服务：

```text
ImportController
  -> ImportUseCase
  -> FileRepository
  -> FormatDetector
  -> MetadataExtractor
  -> BookRepository
  -> SearchIndexer
```

任务状态：

- queued
- running
- indexing
- done
- failed
- cancelled

导入流程：

1. 选择文件。
2. 创建 import task。
3. 计算 hash。
4. 去重检查。
5. 复制文件；Markdown 文件夹书改为记录目录路径指纹，不复制目录。
6. 解析格式和元数据。
7. 写入 books。
8. 创建索引任务。

Markdown 加载路径：

```text
BookDocumentLoader
  -> 单文件：MarkdownDocumentLoader -> MarkdownParser
  -> 文件夹：MarkdownFolderLoader.loadManifest
       -> MarkdownFolderManifest（文件列表 + 保留层级的文件树）
       -> 当前文件：MarkdownDocumentLoader.loadWithHref
            -> MarkdownParser（单个 .md / .markdown）
  -> EpubDocument / EpubChapter / EpubBlock
  -> EpubRendererView
```

Markdown 与 EPUB 共用章节、块和字符偏移模型。文件夹书只发现文件、目录树和 stat 数据，不把所有正文合并成一份文档；阅读器一次只加载当前文件，`href` 记文件夹内相对路径，`chapterIndex` / `chapterOffset` 是该文件内部坐标，`progress` 按文件大小加权到全书。manifest 与单文件解析结果都按路径、大小和修改时间缓存，编辑后自动失效。进度、书内搜索、全文索引、AI 当前章节上下文和目录面板都不按格式分支；文件夹全文索引逐文件写入，当前章节上下文只读活动文件。

## 10. 后续格式转换

MOBI/AZW 与 Calibre `ebook-convert` 不进入当前首版实现。后续需要支持时再新增独立转换服务：

```text
ConversionService
  detectCalibre()
  convertMobiToEpub(inputPath, outputPath)
```

检测方式：

- PATH 中查找 `ebook-convert`。
- 用户在设置中手动选择路径。
- Windows 常见路径自动探测。

调用规则：

- 外部命令必须有超时。
- stdout/stderr 写入任务日志。
- 转换产物写入后续定义的 converted 目录。
- 转换失败不创建 book 记录，或创建 failed import task。

## 11. 渲染层架构

### 11.1 Renderer 抽象

Dart 侧接口：

```dart
abstract class BookRendererController {
  Future<void> open(BookRenderRequest request);
  Future<void> goTo(ReadingLocator locator);
  Future<void> applyTheme(ReaderTheme theme);
  Future<void> setTextOptions(TextOptions options);
  Future<void> search(String query);
  Stream<RendererEvent> get events;
}
```

RendererEvent：

- ready
- locationChanged
- textSelected
- searchResults
- bookmarkRequested
- renderError
- imagesDetected / imageAreaSelected（图片批注，见 `13-image-annotations.md` §4）
- externalLinkRequested：EPUB / Markdown 文本渲染器点击 `http(s)` / `mailto` 链接时只传 URI；宿主显示完整地址、用户确认后再用 `LaunchMode.externalApplication` 打开。渲染器不直接调用 `launchUrl`，不处理内部锚点或 `javascript:`。

图片批注的边界：

- 渲染器只报告几何（`RendererDetectedImage`：页号、序号、资源名、显示框 0..1 矩形），不持有批注，不写数据库。
- 锚点由主机保存；重新打开时主机把锚点交给渲染器投影回屏幕坐标。
- 吸附在渲染器内部完成：`PdfCanvasView` 拖框结束时读 `PdfCanvasRenderer.imagesOnPage(page)` 并调用 `snapToDetectedImage`，`RendererImagesDetected` 目前没有生产者（B2 的 Notebook 缩略图会用到）。
- 识别结果只用于吸附。PDF 的 form XObject 内部元素不在 `PdfPageElements` 里，因此拖框是主入口，识别不是唯一入口。
- 保存图片走 `PdfPageImageSource.exportPageRegion`，与 OCR 的页面导出现在同一接口：主机只持有能力，不持有渲染器。
- 提取出的图片写入应用缓存目录 `<cache>/images/<bookId>/`，可随时重建；不写入书库目录，也不修改原始书籍文件。
- 缓存文件名按**图的同一性**（页 + 序号 + 资源名）而不是按矩形：同一张图换个框再标注时覆盖同一个文件。`lib/core/files/image_cache_store.dart` 是唯一的写入口。
- 裁图发生在标注那一刻，不是导出时：读者正在看那一页，页面已渲染过；导出时才裁意味着每张图再渲染一次整页。裁图失败不打断标注。
- 导出时图片拷到 Markdown 同级的 `<name>_images/` 目录，正文用相对路径引用。移动两者即可保持链接有效。
- 图片缓存是派生数据：删书、删批注都清缓存；设置页可单独「清理图片缓存」。

### 11.2 JS Bridge

Dart -> JS command：

```json
{
  "id": "cmd-1",
  "type": "goTo",
  "payload": {
    "locator": {}
  }
}
```

JS -> Dart event：

```json
{
  "type": "locationChanged",
  "payload": {
    "locator": {},
    "progress": 0.42,
    "chapterTitle": "Chapter 3"
  }
}
```

规则：

- 每个 command 有 id。
- PDF JS 错误必须回传 renderError。
- Dart 层负责 debounce 保存进度。
- renderer 层不直接持久化。

### 11.3 EPUB Renderer

实现：

```text
lib/renderers/epub/epub_document_loader.dart
lib/renderers/epub/epub_chapter_parser.dart
lib/renderers/epub/epub_document.dart
lib/renderers/epub/epub_paginator.dart
lib/renderers/epub/epub_renderer_view.dart
```

能力：

- open book。
- go to href/chapter/progress。
- report href/chapter/progress。
- apply Flutter reader settings。
- text selection。
- search。
- annotations。
- 插图（2026-10-22）：书里的图片按文档顺序显示在文字之间。

**章节模型：一个字符串加一串块。** `EpubChapter.text` 仍然只有字，图片不占字符；
`EpubChapter.blocks` 说明文字与图片在文中的先后。搜索、进度、跳转、划词高亮全都建立在
字符偏移上，让它们去理解「有些东西不是字」会到处漏 —— 与其如此，不如让偏移从一开始
就只有一种意思。

**文本是写出来的，不是读出来的。** 章节文本与它的偏移必须严丝合缝：跳到错字比跳不过去
更糟。解析器一边走标记一边拼文本，偏移是副产品。带 `id` 的元素会把它的偏移记进
`EpubChapter.anchors`，目录跳转因此落在准确的位置。

**图片有护栏。** 字节从 archive 读；`data:` URI 支持，远程图片不加载（本地优先）；
单图的字节与像素预算硬限制，且尺寸在解码之前从图片头部读 —— 一张 20000×20000 的图
先解再量，内存已经没了。加载失败时显示带原因和 `alt` 的占位块，不留空白。

**图注是正文的一部分。** `figcaption` 参与排版，也参与搜索。

**`alt` 是视觉图注。** 2026-11-08 起，EPUB / Markdown 图片的 `alt` 画在图片块下方，不写入 `EpubChapter.text`，因此不占搜索、进度、批注或 AI 上下文的字符偏移。分页测量通过 `epubImageCaptionTextStyle` 与渲染层共用图注高度；缺失图片也只显示一次图注，占位说明不再重复 `alt`。

**列表与链接是排版元数据。** `EpubTextBlock.listMarker` / `listIndent` 与 `EpubInlineRun.target` 不改变章节文本：列表 marker 仍在章节文本与偏移量里，渲染层用固定 `epubListHangingIndent` 分列并单独绘制 marker；链接目标随 run 穿过 `EpubPageFragment`，切页后仍可点击。分页器按同一缩进宽度量内容文字，避免量出来一页、画出来另一页。

**语法色是排版元数据。** 2026-11-09 起，Markdown 围栏代码的语言由 `EpubTextBlock.codeLanguage` 标注，`EpubCodeRun` 以同一章节字符坐标记录关键字、类型、字符串、数字、注释与字面量范围；它们穿过 `epubBlocks` / `EpubPageFragment`，与行内样式、批注、搜索命中一起被切成 `TextSpan`。`CodeSyntax` 不重写正文，也没有数据库或 locator 契约变化；无语言或未知语言代码块只做字符串与数字的保守着色。

**扩展语法是本地可读边界。** 2026-11-09 起，`MarkdownBoundary` 在解析前用每次解析的随机 token 把闭合显示数学、Mermaid 类围栏和 HTML 块包成内部边界；图表与 HTML 写成章节正文中的可读源码或安全可见文字，作者正文里的同名标记不会被误识别。2026-11-09 的 P14 把数学公式改为纯 Dart / Flutter 的 `flutter_math_fork` 本地排版：显示公式用 `EpubTextBlock.mathSource`，行内公式用新增的 `EpubInlineStyle.math` 与 `EpubInlineRun.mathSource` 携带归一化 TeX；`MathSource` 修复笔记里常见的 `\frac1{x^2}` 等紧凑写法，解析或构建失败时回退为原表达式文本。行内公式识别允许以 `\}` 等转义序列结尾，`$$...$$` 限制在同一行；分页器遇到公式内部的切点时把整条公式移到下一片段，并为高公式预留测量高度。公式 Widget 不占章节字符，搜索、进度、选区、批注与 locator 仍以 `EpubChapter.text` 的单一字符坐标为权威。`diagram` 块带 `Mermaid` 标签并按换行跨页；HTML 标签、注释、处理指令、危险标签整段和远程资源属性不进入正文；未闭合边界与代码围栏内内容保持原样。公式字体随应用包分发，无 WebView、图表 JS、HTML 执行或网络请求。

### 11.4 PDF Renderer

**已迁移（2026-10-21）。** PDF 由 `pdf_graphics` 5.1.1 直接解释并在 Flutter Canvas
上绘制，不再使用 WebView/PDF.js。历史上这条链路押在 `flutter_inappwebview` 上，
而该插件没有 Linux 平台实现、Linux 版又依赖 Fedora 不提供的 WPE WebKit，所以
迁移是必需项而非优化项；决策与验证过程见 `10-pdf-renderer-migration.md`，
逐阶段施工记录见 `11-pdf-canvas-implementation-plan.md`。

组成：

```text
lib/renderers/pdf/pdf_canvas_view.dart         视图：滚动/分页/选区/搜索高亮/标注/链接
lib/renderers/pdf/pdf_canvas_renderer.dart     解释器：页面缓存、worker、位图导出
lib/renderers/pdf/pdf_page_tint.dart           主题纸色与夜间滤镜
lib/renderers/pdf/pdf_annotation_lines.dart    F-02 永久标注跨行裁剪
lib/renderers/pdf/pdf_outline.dart             大纲扁平化
lib/renderers/pdf/pdf_links.dart               GoTo / URI 链接
```

能力：

- open PDF（含加密/损坏分级错误）。
- page jump、连续滚动与单页/双页分页。
- zoom（0.5–3.0 连续，四种模式）。
- report page/offset（`scrollOffset` 像素 + `pageOffsetFraction` 页内比例）。
- text selection（含 CJK 单字与旋转页）。
- search（全文命中高亮，最多 200 条）。
- annotations / highlights（含 F-02 跨行裁剪）。
- outline 与内部/外部链接（外链只上抛事件，由宿主确认后交给系统浏览器）。
- 导出页面位图（`PdfPageImageSource`，供 OCR 使用）。

**没有 JS 桥**：渲染器不写业务数据，位置、标注、进度都由 Dart 侧持久化——这条
约束在迁移后依然成立，只是从「JS 不写」变成了「视图不写」。

## 12. 搜索架构

### 12.1 Indexer

职责：

- 从 EPUB/PDF/Markdown/笔记/书签/AI 中提取文本。
- 按 chunk 切分。
- 写入 search_chunks。
- 同步 FTS5。

EPUB chunk：

- 章节标题。
- href。
- CFI 或段落位置。
- 800 到 1500 字。

Markdown chunk：

- 章节标题（单文件按标题切章，目录书按相对路径与标题切章）。
- `href`（目录书为相对文件路径）。
- 章节内字符偏移。
- 800 到 1500 字。

PDF chunk：

- 页码。
- 页内序号。
- 文本。

### 12.2 SearchRepository

接口：

```dart
abstract class SearchRepository {
  Future<List<SearchResult>> search(SearchQuery query);
  Future<void> indexBook(String bookId);
  Future<void> rebuildAll();
}
```

SearchQuery：

- query。
- type filters。
- book id。
- category id。
- limit。
- offset。

结果排序：

- 标题命中。
- 正文命中。
- 最近阅读权重。
- 笔记权重。

## 13. AI 架构

### 13.1 Provider 抽象

```dart
abstract class AiProvider {
  Stream<AiChunk> streamChat(AiRequest request);
  Future<List<AiModel>> listModels();
  Future<AiProviderStatus> checkStatus();
}
```

Provider 实现：

- OpenAI-compatible。
- Ollama，后续。

### 13.2 ContextBuilder

职责：

- 根据选中文本和 locator 获取上下文。
- 控制 token 或字符长度。
- 生成用户可读的上下文范围说明。

上下文来源：

- selected text。
- nearby text。
- chapter title。
- page number。
- book metadata。

**已修复（2026-10-21）**：`availableText` 断链已接通。`ReaderPage` 把 `bookPath` / `isEpub` 传给 `AiPanel`，面板经 `AiContextSource` 从磁盘读一页 PDF（`PdfTextExtractor.reflowPage`，走 isolate）或一章 EPUB（`EpubDocumentLoader`），再交给 `ContextBuilder.build(availableText: …)`。超长章节由 `_boundedChapter` 以选区为中心截到 `maxSourceChars`，不再报错；读不到书文件或本页无文字时明确提示并退回「仅选中文本」。发送内容以引用清单（`AiContextReference`）呈现，每段可跳回、可移除、可逐段编辑，多段时每段带 `【来源】` 标题。方案与后续步骤见 `docs/12-ai-retrieval-strategy.md` §7.1、§9。

**多轮对话（2026-10-21）**：`AiRequest.history`（`List<AiThreadTurn>`）携带同一上下文下的此前各轮，由 `OpenAiCompatibleProvider._messages()` 展开成 `user / assistant / …` 序列。书籍正文只挂在开篇一轮，后续轮只发问题——否则请求成本随轮数线性增长。会话通过 `ai_conversations.thread_id`（Drift v3 → v4 新增列）归组；升级前已有会话置空、按单轮展示，不按时间猜测归组。上下文一变（换选区、换范围、删引用）即开新会话。

### 13.3 全书 / 文件夹检索

不做向量索引，采用「结构感知的词法检索」：

- 复用 `SearchChunks`（1200 字分块，带 locator），**直接扫描正文打分，不走 FTS 索引**：
  FTS5 的 `unicode61` 把整段 CJK 当一个词元，实测「数据」命中 21 块而实含 489 块；
- 打分为 BM25（长度归一 + IDF）+ 覆盖度加权；中文查询按相邻二字切词；
- 目录页按点号密度识别并降权（实测 0.43–0.47，正文 ≤0.02）；
- 检索结果回显为可检查、可增删的引用清单，满足「上下文范围显式」约束。

否决 DCI 与向量 RAG 的实测依据见 `docs/12-ai-retrieval-strategy.md`；
第 4 步的实测数据与已知边界见同文件 §7.4。

### 13.4 安全

- API Key 存 secure storage。
- 普通日志不记录密钥。
- AI 请求内容不进入错误日志。
- 用户可清空 AI 历史。

## 14. 任务队列

任务类型：

- import book。
- extract metadata。
- build index。
- rebuild index。
- export notes。

任务字段：

- id。
- type。
- status。
- progress。
- message。
- createdAt。
- updatedAt。
- error。

规则：

- 长任务可取消。
- 失败可重试。
- 应用重启后 pending/running 任务恢复为 pending 或 failed，由类型决定。

## 15. 错误处理

错误在领域、存储、渲染和平台边界使用具体异常表达，应用层按操作提供恢复建议。
没有调用方的统一 `AppError` 继承骨架已在 2026-11-09 清理；不为目录对称保留空框架。

错误展示：

- UI 展示简短原因。
- 详情可展开。
- 日志保存 stack trace。
- 用户数据相关错误不能吞掉。

任务错误通过 `PrivacySanitizer` 脱敏后展示。当前不保留未接入的 logger 包装；
如需新增诊断链路，应在实际调用处落实隐私规则，而非只增加一个无人使用的日志类。

## 16. 测试策略

### 16.1 单元测试

- hash service。
- format detector。
- locator serialization。
- search query builder。
- AI context builder。
- repository mapping。

### 16.2 Widget 测试

- 书库空状态。
- 书籍卡片。
- 搜索结果。
- 设置表单。
- AI 面板状态。

### 16.3 集成测试

- 导入 EPUB。
- 导入 PDF。
- 打开并保存进度。
- 重启后恢复进度。
- 搜索笔记。

### 16.4 手动样本

样本库：

- 标准 EPUB。
- 大型 EPUB。
- 带图片 EPUB。
- 标准 PDF。
- 大 PDF。
- 扫描版 PDF。
- 损坏文件。

## 17. 构建与发布

Android：

```powershell
flutter build apk
flutter build appbundle
```

Windows：

```powershell
flutter build windows
```

规则：

- 发布包中包含打包的图片与字体资源。
- 不把测试书籍打入生产包。
- 许可证文件随包发布。
- Calibre/MOBI 转换暂缓，不随当前发布包处理。

## 18. 第一个技术 Spike

> **历史记录。** 本节记录 M0 当时的 Spike 计划，其中「PDF WebView + PDF.js」部分
> 已被 `10-pdf-renderer-migration.md` 取代（2026-10-21 完成）。保留原文是为了
> 说明当时的验收目标，不作为当前实现说明。

目标：

- 验证 Flutter-native EPUB renderer、PDF WebView renderer 和本地文件访问。

任务：

1. 创建 Flutter 工程。
2. 接入 EPUB 原生解析和渲染组件。
3. 打开本地 EPUB。
4. Dart renderer 回传当前位置。
5. 接入 PDF WebView。<!-- 已被 Canvas 渲染器取代，见 §11.4 -->
6. 放入最小 PDF.js viewer。<!-- 已删除 -->
7. 打开本地 PDF。
8. JS 回传页码。

验收：

- Android 和 Windows 都能打开测试书。
- Dart 能收到 locationChanged。
- 关闭再打开能 goTo 上次位置。
