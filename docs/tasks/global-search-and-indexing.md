# TASK-14：全局搜索、FTS5、索引任务和结果跳转

## 目标

实现跨书库全文搜索，让用户能搜索书名、作者、分类、标签、EPUB 正文、PDF 文本层、书签、笔记和 AI 回答，并从结果跳转到原文或详情。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：云端搜索、扫描版 PDF OCR、复杂语义搜索。
- 约束：使用 SQLite FTS5；索引失败不影响阅读。

## 功能范围

- 搜索 chunk 数据模型。
- FTS5 索引。
- EPUB 正文提取和切块。
- PDF 文本层提取和切块。
- 书签、笔记、AI 记录索引。
- 导入后后台索引。
- 手动重建单书或全部索引。
- 搜索页和过滤器。
- 搜索结果跳转。
- 索引状态展示。

## 实现任务

- [x] 实现 `SearchIndexer`，按来源生成 `search_chunks`。
- [x] EPUB 按章节和段落切块，目标 800 到 1500 字。
- [x] PDF 按页和文本块切块。
- [x] 笔记、书签、AI 记录写入或更新对应 chunk。
- [x] 实现 FTS5 表和触发器或同步写入逻辑。
- [x] 实现 `SearchRepository.search(SearchQuery)`。
- [x] 支持结果类型过滤：书籍、正文、笔记、书签、AI。
- [x] 支持格式、分类、标签、书籍范围过滤。
- [x] 结果排序考虑标题命中、正文命中、最近阅读、笔记权重。
- [x] 搜索输入 250ms debounce。
- [x] 点击正文结果打开书籍并 goTo locator。
- [x] 点击笔记结果打开笔记详情。
- [x] 点击 AI 结果打开 AI 记录并支持回跳原文。
- [x] 展示索引 pending/running/failed 状态。
- [x] 提供重建单书索引和重建全部索引。

## 涉及模块和文件

- `lib/core/search/search_indexer.dart`
- `lib/core/search/search_repository.dart`
- `lib/domain/search/search_query.dart`
- `lib/domain/search/search_result.dart`
- `lib/core/database/daos/search_dao.dart`
- `lib/features/search/presentation/search_page.dart`
- `lib/features/search/presentation/widgets/`
- `lib/features/search/application/search_controller.dart`
- `lib/features/import/application/import_use_case.dart`
- `lib/core/tasks/task_queue.dart`
- `test/core/search/`
- `test/features/search/`

## 数据与接口

- `search_chunks.source_type`：`book`、`note`、`bookmark`、`ai`。
- `search_chunks.source_id` 指向来源记录。
- `search_chunks.locator` 保存跳转位置。
- `search_chunks.sort_order` 保存书内顺序。
- `SearchQuery` 包含 query、typeFilters、bookId、categoryId、tagIds、format、limit、offset。
- `SearchResult` 包含 type、title、snippet、highlightRanges、bookId、locator、sourceId。

## UI 与交互

- 移动端搜索页顶部固定搜索框，筛选横向滚动。
- 桌面端顶部搜索框，过滤器在顶部或左侧，结果中间，右侧预览可后续增强。
- 结果卡片显示类型、书名、章节或页码、命中片段和操作按钮。
- 操作按钮：打开、复制、保存为笔记、提问。
- 索引未完成时显示状态和重建入口。
- `Ctrl+Shift+F` 打开全局搜索。

## 验收标准

- [x] 搜索书名和作者能返回书籍。
- [x] 搜索 EPUB/PDF 正文能返回片段。
- [x] 搜索笔记和书签能返回对应记录。
- [x] AI 回答保存后可被搜索命中。
- [x] 点击结果能跳转到原文或详情。
- [x] 索引失败不影响打开书籍。
- [x] 重建索引后搜索结果更新。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 单元测试：chunk 切分、FTS 查询、过滤器、结果排序、跳转 locator。
- 手动验证：1000 条 chunk 查询性能、中文关键词、英文短语、多类型过滤。

## 依赖与风险

- 依赖：TASK-02 search_chunks 和 FTS5，TASK-03 导入，TASK-10/12/16 内容来源，TASK-19 任务队列。
- 风险：SQLite FTS5 中文分词效果有限，先保证基础命中，再评估 tokenizer。
- 风险：索引任务和书籍删除并发时需要一致性处理。
