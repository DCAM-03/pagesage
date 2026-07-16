# TASK-17：Markdown/CSV 导出、备份和恢复

## 目标

实现数据可迁移能力，让用户能导出笔记、书签和 AI 回答，并能备份和恢复本地数据库与必要资源。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：云备份、自动同步、第三方知识库 API 直连。
- 约束：导出路径由用户明确选择；备份不得泄露 API key。

## 功能范围

- 单本书笔记导出 Markdown。
- 全部笔记导出 Markdown。
- 书签导出 CSV。
- AI 问答导出 Markdown。
- 数据库备份 zip。
- 备份包含 SQLite、covers、可选 books 文件。
- 恢复数据库备份。
- 版本兼容检查。
- 冲突处理。

## 实现任务

- [x] 定义 `ExportService`。
- [x] Markdown 导出包含位置、原文、笔记内容、创建和更新时间。
- [x] AI 回答导出包含问题、回答、来源书籍、位置、上下文范围摘要。
- [x] CSV 书签导出包含位置、备注、摘录、创建时间。
- [x] 使用系统文件选择器选择恢复备份文件。
- [ ] 使用系统文件选择器选择导出目录或文件。
- [ ] 导出任务进入任务队列，显示进度和错误。
- [x] 备份 zip 包命名 `pagesage-backup-YYYYMMDD.zip`。
- [ ] 备份包含数据库和 covers，books 文件由用户选择是否包含。
- [x] 备份清单包含创建时间和内容清单。
- [x] 恢复前检查文件完整性。
- [x] 恢复前提示覆盖风险并创建当前数据库回滚副本。
- [ ] 冲突策略：覆盖当前数据、合并数据、取消，合并可后续增强。
- [ ] 恢复后重建索引或标记索引待重建。

## 涉及模块和文件

- `lib/features/settings/presentation/export_backup_page.dart`
- `lib/features/export/application/export_service.dart`
- `lib/features/export/application/backup_service.dart`
- `lib/core/files/app_paths.dart`
- `lib/core/platform/file_picker_service.dart`
- `lib/core/tasks/task_queue.dart`
- `lib/core/database/app_database.dart`
- `lib/domain/notes/note_repository.dart`
- `lib/domain/books/bookmark_repository.dart`
- `lib/domain/ai/ai_conversation_repository.dart`
- `test/features/export/`

## 数据与接口

- 导出读取 `notes`、`bookmarks`、`ai_conversations`、`books`。
- 备份不包含 secure storage 中的 API key。
- 恢复时需要 schema version 检查。
- 恢复后 `search_chunks` 可选择恢复或重建，必须保持一致。

## UI 与交互

- 设置页分组：导出与备份。
- 导出项使用明确按钮：导出单本书笔记、导出全部笔记、导出书签、导出 AI 问答、创建备份、恢复备份。
- 导出成功后显示路径和“打开所在位置”桌面入口。
- 恢复属于危险操作，需要二次确认。
- 导出失败展示原因和可重试操作。

## 验收标准

- [ ] Markdown 导出包含书名、位置、原文和笔记内容。
- [ ] CSV 书签导出可以被常见表格工具打开。
- [x] AI 导出不包含 API key。
- [ ] 备份文件能包含数据库和封面。
- [ ] 恢复前会检查版本和完整性。
- [ ] 导出失败不会产生半截不可识别文件，或会明确标记失败。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 本轮已验证：`dart format lib test`、`flutter analyze`、`flutter test -r expanded`、`flutter build windows --debug`。
- 当前实现说明：恢复备份 zip 已通过 `FilePickerService.pickBackupZipFile()` 选择文件，不再由设置页直接依赖第三方 picker；导出目前仍写入应用 exports 目录，用户选择导出目录待后续实现。
- 单元测试：Markdown 转义、CSV 转义、备份 manifest、版本检查。
- 手动验证：Windows 导出路径、Android 文件保存、备份恢复后书库和笔记可用。

## 依赖与风险

- 依赖：TASK-02 数据库，TASK-10 书签，TASK-12 笔记，TASK-16 AI 记录，TASK-19 任务队列。
- 风险：恢复过程若中断可能破坏数据，需要先备份当前状态或使用临时目录原子替换。
- 风险：导出内容可能包含用户敏感笔记，需要明确用户主动选择。
