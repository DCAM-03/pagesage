# TASK-04：书库页面、书籍管理、排序筛选和详情

## 目标

实现 PageSage 主入口书库，让用户能查看、搜索、筛选、排序、打开和管理所有已导入 EPUB/PDF，并在移动端和桌面端使用合适布局。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`。
- 不做：全文搜索结果页、阅读器内部功能、AI。
- 约束：书库是应用默认入口；UI 不直接调用 DAO。

## 功能范围

- 空书库、加载、错误、有书籍状态。
- 网格、列表、紧凑列表。
- 书籍卡片和列表行。
- 书籍详情侧栏或底部抽屉。
- 排序、筛选、基础搜索。
- 右键/长按上下文菜单。
- 收藏、标记已读、重命名标题、修改作者。
- 重建索引、重新提取封面。
- 从书库移除和删除应用副本与数据。

## 实现任务

- [x] 建立 `LibraryController` 和 `LibraryState`。
- [x] 支持按最近阅读、最近导入、标题、作者、进度、文件大小、格式排序。
- [x] 支持按阅读状态、格式、分类、标签、收藏、有笔记、有书签筛选。
- [x] 实现移动端书籍网格，默认 2 到 3 列。
- [x] 实现桌面端网格和列表视图切换。
- [x] 实现紧凑列表视图。
- [x] 书籍卡片展示封面、标题、作者、格式角标、进度条。
- [x] 列表行展示分类、标签、格式、进度、最近打开时间。
- [x] 选中书籍时桌面右侧显示详情。
- [x] 移动端详情使用详情页或底部抽屉。
- [x] 上下文菜单支持继续阅读、详情、重命名、修改作者、分类、标签、收藏、标记已读、重建索引、重新提取封面、移除、删除数据。
- [x] 删除类操作使用确认对话框，危险操作不作为默认焦点。
- [x] 导入中和索引中状态显示轻量状态，不阻塞打开。

## 涉及模块和文件

- `lib/features/library/presentation/library_page.dart`
- `lib/features/library/presentation/widgets/`
- `lib/features/library/application/library_providers.dart`
- `lib/features/library/application/library_controller.dart`
- `lib/domain/books/book.dart`
- `lib/domain/books/book_repository.dart`
- `lib/domain/books/library_filter.dart`
- `lib/domain/books/library_sort.dart`
- `lib/core/database/daos/book_dao.dart`
- `test/features/library/`

## 数据与接口

- `BookRepository.watchLibrary()` 支持排序和筛选参数。
- `BookRepository.updateDisplayMetadata()` 支持用户修改标题和作者。
- `BookRepository.markReadStatus()` 设置 `unread`、`reading`、`finished`。
- `BookRepository.toggleFavorite()` 更新收藏。
- `BookRepository.removeBook()` 按删除规则删除应用副本和关联数据。
- `SearchRepository.rebuildBookIndex(bookId)` 供重建索引菜单调用。

## UI 与交互

- 空书库显示插画、导入按钮、扫描文件夹按钮和稍后配置 AI 入口。
- 书籍点击打开阅读器。
- 桌面列表单击选中，双击打开，方向键移动选中，Enter 打开。
- 长标题最多两行，作者一行，避免卡片尺寸跳动。
- 桌面右键菜单包含快捷键提示。
- 错误卡片显示可恢复动作，如重试导入、重建索引、查看详情。

## 验收标准

- [x] 用户能看到所有已导入书籍。
- [x] 重启后书库状态保持。
- [x] 排序和筛选结果正确。
- [x] 网格、列表、紧凑列表之间切换不丢失筛选条件。
- [x] 书籍卡片能正确展示格式和阅读进度。
- [x] 删除操作不会误删用户原始路径文件。
- [x] 索引失败的书籍仍可打开阅读。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- Widget 测试：空状态、卡片、列表行、筛选 chip、删除确认。
- 手动验证：1000 本模拟数据滚动、Windows 右键菜单、Android 长按菜单。

## 依赖与风险

- 依赖：TASK-02 数据库，TASK-03 导入。
- 依赖：TASK-09 分类标签，TASK-10 书签，TASK-12 笔记，TASK-14 搜索状态。
- 风险：书库状态过多时 controller 容易膨胀，需要保持查询、命令和 UI 状态边界。
