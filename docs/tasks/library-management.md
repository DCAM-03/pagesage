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

- 空书库显示插画、一个「导入」菜单（导入文件 / 扫描文件夹 / 把文件夹作为一本书）和稍后配置 AI 入口。
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

### 2026-11-10 桌面分类栏折叠

- 桌面筛选栏左端提供常驻的“收起书库分类 / 展开书库分类”按钮，收起后释放分类栏的 248px 宽度。
- 折叠状态由 `LibraryController` 管理，仅在本次应用运行中保留；不修改阅读器设置或数据库。筛选、排序、视图切换和清除筛选不改变折叠状态。
- 收起后以紧凑菜单保留当前阅读状态和书架筛选，可修改或清除；重新展开时保留树内目录的展开状态。
- 验证：`flutter analyze` 通过；`flutter test test/features/library test/app/widgets test/widget_test.dart --concurrency=4 --reporter expanded` 共 47 项通过。控制器测试覆盖折叠与筛选/排序/视图隔离；侧栏测试使用真实 `PageSageApp` 和明确断言的 1440px 视口，验证收起后网格实际增宽约 249px、目录展开状态保留、菜单改筛选、无结果清除以及缩窄再恢复桌面宽度。
- `app_chrome_test.dart` 验证横向滚动筛选项时，展开入口不移动且仍可点击。`library_sidebar_test.dart` 加 `--dart-define=UPDATE_PAGESAGE_SCREENSHOTS=true` 另有 4 项通过，生成 `.codex-run/ui-screenshots/library-sidebar-{1440,1024}-{expanded,collapsed}.png` 和 `library-sidebar-1024-large-text.png`，覆盖真实壳层、两种宽度和 1.4 倍文字。渲染未报告溢出；图片查看工具未返回图像，因此不记为人工目检通过；真实桌面窗口未验收。
- Linux release 已通过 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 更新到本地安装路径；`diff -qr` 确认整个安装 bundle 与构建一致，双方 `libapp.so` SHA256 均为 `2e90704fb19d24cb68aa86380f79ac6596281e08bf5e935b7a75531fff4f2e06`。检查时无运行中的 `pagesage`，未启动窗口。

- `dart format .`
- `flutter analyze`
- `flutter test`
- Widget 测试：空状态、卡片、列表行、筛选 chip、删除确认。
- 手动验证：1000 本模拟数据滚动、Windows 右键菜单、Android 长按菜单。

## 依赖与风险

- 依赖：TASK-02 数据库，TASK-03 导入。
- 依赖：TASK-09 分类标签，TASK-10 书签，TASK-12 笔记，TASK-14 搜索状态。
- 风险：书库状态过多时 controller 容易膨胀，需要保持查询、命令和 UI 状态边界。
