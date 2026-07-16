# TASK-02：Drift/SQLite 数据库、迁移和 DAO

## 目标

建立完整本地数据模型，覆盖书籍、分类、标签、进度、书签、划线、笔记、AI 记录、搜索 chunk、设置和任务，并提供可维护的 Drift migration 策略。

## 来源与边界

- 来源：`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：具体 UI 页面和 renderer 事件处理。
- 约束：UUID 字符串主键，Unix milliseconds 时间戳，复杂定位和设置使用 JSON 文本，全文搜索使用 SQLite FTS5。

## 功能范围

- Drift 数据库入口。
- 所有核心表和索引。
- DAO 和 repository mapping。
- FTS5 external content table 和同步机制。
- schema version 和迁移。
- 开发期 reset 入口，仅限 debug。
- 删除规则和外键级联策略。

## 实现任务

- [ ] 拆分 Drift tables 到 `lib/core/database/tables/`。
- [ ] 建立 `books`、`reading_progress`、`app_settings` 的完整字段。
- [ ] 建立 `categories`、`tags`、`book_tags`。
- [ ] 建立 `bookmarks`、`annotations`、`notes`。
- [ ] 建立 `ai_conversations`。
- [ ] 建立 `search_chunks` 和 `search_chunks_fts`。
- [ ] 建立 `import_tasks` 或通用 `tasks` 表。
- [ ] 建立 `note_tags`，用于笔记标签。
- [ ] 为书库、搜索和时间排序添加必要索引。
- [ ] 实现 `BookDao`、`ProgressDao`、`CategoryDao`、`TagDao`、`BookmarkDao`、`AnnotationDao`、`NoteDao`、`SearchDao`、`TaskDao`、`SettingsDao`。
- [ ] 实现 row 到 domain model 的双向映射。
- [ ] 建立 migration 文件，禁止以清库作为升级捷径。
- [ ] 为大迁移预留备份和进度提示接口。
- [ ] 增加 locator JSON 序列化测试。

## 涉及模块和文件

- `lib/core/database/app_database.dart`
- `lib/core/database/migrations.dart`
- `lib/core/database/tables/*.dart`
- `lib/core/database/daos/*.dart`
- `lib/core/database/database_providers.dart`
- `lib/domain/books/`
- `lib/domain/annotations/`
- `lib/domain/notes/`
- `lib/domain/search/`
- `lib/domain/ai/`
- `test/core/database/`
- `test/domain/books/reading_position_test.dart`

## 数据与接口

- `books.file_hash` 用于重复检测。
- `reading_progress.book_id` 每本书仅一条主记录。
- `annotations.note_id` 允许为空，删除 annotation 不默认删除 note。
- `notes.note_type` 支持 `text`、`excerpt`、`ai`、`question`。
- `search_chunks.source_type` 支持 `book`、`note`、`bookmark`、`ai`。
- API Key 不进入 `app_settings`，只进入 secure storage。

## UI 与交互

- 本 task 不直接实现 UI。
- 删除和迁移错误应向上暴露可读错误，供 UI 展示确认或恢复操作。

## 验收标准

- [ ] 所有权威文档中的核心表都有 Drift 定义。
- [ ] 所有 release 级 schema 变更都有 migration。
- [ ] 插入、更新、删除、查询均通过 repository 返回 domain model。
- [ ] FTS 表能随 `search_chunks` 更新保持同步。
- [ ] 删除书籍时相关进度、书签、标注、搜索索引能按删除规则处理。
- [ ] API key 不会被写入 SQLite。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 增加数据库测试：建库、迁移、插入完整书籍、删除书籍、FTS 查询。

## 依赖与风险

- 依赖：TASK-01 的工程分层和 provider 基础。
- 风险：FTS5 tokenizer 对中文效果有限，需要先保证基础可用，再评估 tokenizer 策略。
- 风险：迁移设计不严谨会导致用户数据丢失，发布后不能用清库替代迁移。

