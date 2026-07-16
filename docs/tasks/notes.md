# TASK-12：笔记、摘录、编辑、列表和回跳

## 目标

实现本地笔记系统，支持文字笔记、摘录笔记、AI 回答笔记和问题卡片，能从阅读器创建、在笔记页管理、搜索命中，并跳回原文。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/06-data-model.md`。
- 不做：云笔记同步、多人协作编辑、复杂 Markdown 所见即所得。
- 约束：笔记默认本地保存，删除书籍时相关笔记处理必须确认。

## 功能范围

- 阅读器中从选中文本创建笔记。
- 从高亮创建笔记。
- 独立文字笔记。
- AI 回答保存为笔记。
- 笔记列表页。
- 笔记详情和编辑。
- 按书籍、标签、时间筛选。
- 笔记搜索。
- 从笔记跳回原文。
- 删除、未保存关闭确认。

## 实现任务

- [x] 建立 `Note` domain model 和 repository。
- [x] 实现 `NoteDao`。
- [x] 阅读器笔记面板支持创建摘录笔记。
- [x] 笔记字段保存 title、content、source_text、locator、note_type。
- [x] 支持 note type：`text`、`excerpt`、`ai`、`question`。
- [x] 从 annotation 创建笔记时建立双向关联。
- [x] AI 回答保存为笔记时关联 `ai_conversation.note_id`。
- [x] 笔记页移动端列表和详情页。
- [x] 笔记页桌面端左侧列表、右侧预览/编辑。
- [x] 支持按书籍、标签、时间、类型筛选。
- [x] 支持 Markdown 文本输入。
- [x] 支持删除笔记，危险关联删除需要确认。
- [x] 笔记保存后写入搜索索引。
- [x] 点击“跳转原文”打开对应书籍并 goTo locator。

## 涉及模块和文件

- `lib/domain/notes/note.dart`
- `lib/domain/notes/note_repository.dart`
- `lib/core/database/daos/note_dao.dart`
- `lib/features/notes/presentation/notes_page.dart`
- `lib/features/notes/presentation/widgets/`
- `lib/features/notes/application/notes_controller.dart`
- `lib/features/reader/presentation/widgets/notes_panel.dart`
- `lib/features/search/application/search_indexer.dart`
- `test/features/notes/`

## 数据与接口

- `notes.book_id` 可为空，用于独立笔记。
- `notes.annotation_id` 可为空。
- `notes.content` 保存 Markdown。
- `notes.source_text` 保存原文摘录。
- `notes.locator` 保存 JSON locator。
- `note_tags` 用于笔记标签。
- `NoteRepository.watchNotes(filter, sort)` 支持列表页。

## UI 与交互

- 创建笔记面板显示原文摘录和输入框。
- 手动保存为默认策略；有未保存内容关闭时需要确认。
- 笔记卡片显示书名、原文摘录、正文摘要、更新时间。
- 桌面端支持键盘上下切换笔记。
- 空笔记页提供打开最近阅读的入口。

## 验收标准

- [x] 从阅读器选中文本可以创建笔记。
- [x] 笔记重启后存在并可编辑。
- [x] 笔记能跳回原文位置。
- [x] 笔记可以按书籍和时间筛选。
- [x] 删除书籍时关联笔记处理有明确确认。
- [x] 笔记内容可以被全局搜索命中。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- Widget 测试：笔记空状态、列表、详情编辑、未保存关闭确认。
- 手动验证：EPUB/PDF 摘录笔记、独立笔记、从 AI 保存笔记、回跳原文。

## 依赖与风险

- 依赖：TASK-02 notes/note_tags，TASK-05 locator，TASK-11 annotation，TASK-14 搜索。
- 风险：笔记自动保存和手动保存混用会导致用户心智混乱，需要先明确策略。
