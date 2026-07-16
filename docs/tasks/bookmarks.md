# TASK-10：书签数据、面板、备注和跳转

## 目标

实现书签能力，让用户能在 EPUB/PDF 当前阅读位置一键添加或取消书签，编辑备注，并从书签面板、全局入口或搜索结果跳回原文。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/06-data-model.md`。
- 不做：多人共享书签、云同步书签。
- 约束：书签使用稳定 locator；删除书签不影响笔记。

## 功能范围

- 当前页或当前位置添加书签。
- 当前位置书签状态识别。
- 取消当前书签。
- 书签备注编辑。
- 书签面板列表。
- 从书签跳转原文。
- 全局书签入口。
- 书签备注参与全局搜索。

## 实现任务

- [x] 建立 `Bookmark` domain model 和 repository。
- [x] 实现 `BookmarkDao` 增删改查。
- [x] ReaderController 根据当前 locator 判断是否已有书签。
- [x] 阅读器工具栏书签按钮支持添加和取消。
- [x] 添加书签时保存 locator、title、excerpt、created_at。
- [x] snackbar 提示“已添加书签”，提供“添加备注”。
- [x] 取消书签时提供撤销。
- [x] 书签面板展示章节或页码、摘录、备注、创建时间。
- [x] 支持编辑备注和删除。
- [x] 点击书签调用 reader goTo。
- [x] 书籍详情展示书签数量和最近书签。
- [x] 书签备注和 excerpt 写入搜索 chunk。

## 涉及模块和文件

- `lib/domain/books/bookmark.dart`
- `lib/domain/books/bookmark_repository.dart`
- `lib/core/database/daos/bookmark_dao.dart`
- `lib/features/reader/presentation/widgets/bookmark_button.dart`
- `lib/features/reader/presentation/widgets/bookmarks_panel.dart`
- `lib/features/reader/application/reader_controller.dart`
- `lib/features/search/application/search_indexer.dart`
- `test/features/reader/bookmarks_test.dart`

## 数据与接口

- `bookmarks.locator` 保存 EPUB/PDF JSON locator。
- `bookmarks.title` 可来自章节标题或页码。
- `bookmarks.note` 保存用户备注。
- `bookmarks.excerpt` 保存附近原文，用于列表和搜索。
- `BookmarkRepository.watchByBook(bookId)` 支持阅读器面板。
- `BookmarkRepository.findAtLocator(bookId, locator)` 支持当前按钮状态。

## UI 与交互

- 当前页已有书签时工具栏图标显示已选中。
- 移动端书签面板使用底部抽屉或全屏页。
- 桌面端书签面板放在右侧 Tab。
- 删除书签不需要强确认，但需要撤销提示。
- 编辑备注时未保存关闭需确认或明确自动保存策略。

## 验收标准

- [x] 添加书签后工具栏状态立即更新。
- [x] 书签重启后仍存在。
- [x] 书签能跳回原文位置。
- [x] 编辑备注后搜索可以命中。
- [x] 删除书签不影响笔记和高亮。
- [x] EPUB 和 PDF 都支持书签。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- Widget 测试：书签按钮状态、书签面板、备注编辑。
- 手动验证：EPUB CFI 书签跳转、PDF 页码书签跳转、撤销删除。

## 依赖与风险

- 依赖：TASK-02 bookmarks 表，TASK-05 locator 和 reader goTo。
- 依赖：TASK-14 搜索索引。
- 风险：当前位置和已有书签匹配不能只做 JSON 字符串相等，需要按格式容忍误差。
