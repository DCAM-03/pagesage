# TASK-03：文件导入、应用书库目录、元数据和去重

## 目标

实现 EPUB/PDF 文件导入闭环：选择文件、识别格式、计算 hash、复制到应用书库目录、提取元数据和封面、写入数据库、创建索引任务，并对重复和异常提供可恢复处理。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`。
- 不做：MOBI/AZW、Calibre 转换、OCR、云端导入。
- 约束：导入必须复制到应用库目录；从 PageSage 删除不删除用户原始路径文件。

## 功能范围

- 单文件和多文件导入。
- EPUB/PDF 格式识别。
- 重复文件检测和用户选择。
- 应用内文件命名和目录布局。
- 元数据、语言、描述、封面提取。
- 导入任务状态。
- 导入失败清理。
- 暂不支持格式的明确提示。

## 实现任务

- [x] 完善 `FormatDetector`，只接受 `.epub` 和 `.pdf`。
- [x] 为 MIME、扩展名和文件头建立组合识别策略。
- [x] 实现大文件 hash 计算，避免一次性读入内存。
- [x] 按 hash 前缀创建 `library/books/<2>/<4>/<book-id>.<ext>`。
- [x] 导入前创建任务记录，导入完成后关联 `book_id`。
- [x] 复制文件后校验文件大小或 hash。
- [x] 提取 EPUB 元数据：标题、作者、语言、描述、封面。
- [x] 提取 PDF 元数据：标题、作者、页数可用时保存扩展信息。
- [x] 无封面时使用默认封面策略。
- [x] 重复导入时弹出：打开已有书籍、仍然导入副本、取消。
- [x] 选择未支持格式时不创建 book 记录，不创建转换任务。
- [x] 导入失败时删除半成品副本，并保留任务错误详情。
- [x] 导入成功后创建索引任务，但不阻塞打开阅读。

## 涉及模块和文件

- `lib/features/import/application/import_use_case.dart`
- `lib/features/import/application/import_providers.dart`
- `lib/features/import/application/import_result.dart`
- `lib/core/platform/file_picker_service.dart`
- `lib/core/files/app_paths.dart`
- `lib/core/files/file_repository.dart`
- `lib/core/files/hash_service.dart`
- `lib/core/files/format_detector.dart`
- `lib/core/files/metadata_extractor.dart`
- `lib/core/database/daos/book_dao.dart`
- `lib/core/database/daos/task_dao.dart`
- `lib/features/library/presentation/library_page.dart`
- `test/core/files/`
- `test/features/import/`

## 数据与接口

- `books.original_file_path` 记录用户来源路径，但阅读不依赖它。
- `books.library_file_path` 指向应用内副本。
- `books.file_hash` 默认用于去重。
- `books.original_format` 记录用户原始格式，当前只应为 `epub` 或 `pdf`。
- `books.indexing_status` 在导入成功后为 `pending` 或 `running`。
- `import_tasks.status` 使用 `queued`、`running`、`indexing`、`done`、`failed`、`cancelled`。

## UI 与交互

- 空书库主按钮和书库顶部按钮都能进入导入。
- 成功后 snackbar 显示“已导入”，提供“打开”操作。
- 多文件导入显示任务队列或任务中心入口。
- 暂不支持格式提示“当前版本暂不支持此格式，请导入 EPUB 或 PDF 文件”。
- 重复导入弹窗默认焦点是“打开已有书籍”。

## 验收标准

- [x] EPUB/PDF 可以导入并出现在书库。
- [x] 导入后的书籍不依赖原文件继续存在。
- [x] 重复文件能被识别，并按用户选择执行。
- [x] 导入失败不会留下无效 book 记录。
- [x] 未支持格式不会创建转换任务或无效书籍。
- [x] 删除书籍时不删除 `original_file_path` 指向的文件。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 手动验证：单文件 EPUB、单文件 PDF、多文件混合导入、重复导入、损坏文件、无权限路径、磁盘空间不足模拟。

## 依赖与风险

- 依赖：TASK-02 的 books、tasks 表和 DAO。
- 依赖：TASK-19 的任务队列可先简化实现，但最终需要接入。
- 风险：大文件 hash 和复制可能阻塞 UI，必须放在异步任务中。
- 风险：Windows 和 Android 文件选择权限差异需要平台验证。
