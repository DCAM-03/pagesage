# PageSage 技术架构文档

版本：0.1  
日期：2026-06-13  
状态：详细技术架构  

## 1. 技术目标

PageSage 的技术架构需要满足：

- Android 和 Windows 首发。
- 数据本地优先。
- EPUB/PDF 渲染可替换。
- MOBI/AZW 与外部转换工具暂缓。
- 搜索、笔记、AI 与阅读器位置稳定关联。
- 后续可以扩展 iOS、macOS、Linux。

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
| PDF 渲染 | `pdf_graphics` + Flutter Canvas（见 `10-pdf-renderer-migration.md`） |
| MOBI/AZW 转换 | 暂缓 |
| 本地文件 | path_provider + file_picker |
| 安全存储 | flutter_secure_storage |
| 日志 | logger 或 talker |
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
  EPUB native renderer, PDF renderer, PDF JS bridge protocol

Platform Layer
  File picker, secure storage, external process, PDF WebView, OS integration
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
      task_queue.dart
      task_models.dart
    platform/
      file_picker_service.dart
      webview_capabilities.dart
      webview_capabilities.dart
    security/
      secure_store.dart
    logging/
      app_logger.dart
    errors/
      app_error.dart
      error_mapper.dart
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
      renderer_bridge.dart
      renderer_event.dart
      renderer_command.dart
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
library/covers/<book-id>.jpg
```

规则：

- 导入时复制到应用目录。
- 数据库记录应用目录路径和原始路径。
- 应用不依赖原始路径继续存在。
- 删除应用副本不删除原始文件。

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
5. 复制文件。
6. 解析格式和元数据。
7. 写入 books。
8. 创建索引任务。

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
lib/renderers/epub/epub_document.dart
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

- 从 EPUB/PDF/笔记/书签/AI 中提取文本。
- 按 chunk 切分。
- 写入 search_chunks。
- 同步 FTS5。

EPUB chunk：

- 章节标题。
- href。
- CFI 或段落位置。
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

**已修复（2026-10-21）**：`availableText` 断链已接通。`ReaderPage` 把 `bookPath` / `isEpub` 传给 `AiPanel`，面板经 `AiContextSource` 从磁盘读一页 PDF（`PdfTextExtractor.reflowPage`，走 isolate）或一章 EPUB（`EpubDocumentLoader`），再交给 `ContextBuilder.build(availableText: …)`。超长章节由 `_boundedChapter` 以选区为中心截到 `maxSourceChars`，不再报错；读不到书文件或本页无文字时明确提示并退回「仅选中文本」。方案与后续步骤见 `docs/12-ai-retrieval-strategy.md` §7.1、§9。

### 13.3 全书 / 文件夹检索

不做向量索引，采用「结构感知的词法检索」：

- 复用 `SearchChunks`（1200 字分块，带 locator）与 FTS5 bm25；
- 复用 `SearchDao.search()` 已有的 `bookId` / `categoryId` / `tagIds` 过滤；
- 用 EPUB `EpubTocItem` 树与 PDF `PdfOutline` 做结构重排与邻近扩展；
- 检索结果必须回显为可检查、可增删的引用清单，满足「上下文范围显式」约束。

否决 DCI 与向量 RAG 的实测依据见 `docs/12-ai-retrieval-strategy.md`。

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

错误分层：

- DomainError。
- DataError。
- RendererError。
- PlatformError。
- AiError。

错误展示：

- UI 展示简短原因。
- 详情可展开。
- 日志保存 stack trace。
- 用户数据相关错误不能吞掉。

示例：

```dart
sealed class AppError {
  String get message;
  String? get recoveryAction;
}
```

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
