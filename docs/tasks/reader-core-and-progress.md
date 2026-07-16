# TASK-05：阅读器外壳、定位模型、进度保存和恢复

## 目标

建立 EPUB/PDF 共用的阅读器外壳和稳定定位模型，确保打开书籍、阅读、保存进度、关闭后恢复位置的核心体验可靠。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：具体 EPUB/PDF 渲染细节、书内搜索、AI、笔记编辑。
- 约束：renderer 只发事件，不直接持久化；Dart 层 debounce 保存进度。

## 功能范围

- 统一 Reader route。
- 阅读器顶部、底部和侧边面板外壳。
- Renderer controller 抽象。
- EPUB/PDF locator domain model。
- 阅读进度读取、保存、恢复。
- `last_opened_at` 和阅读状态更新。
- 前后台切换立即保存。
- 从头开始阅读和标记已读。

## 实现任务

- [x] 定义 `ReadingLocator`，覆盖 EPUB CFI 和 PDF 页码/滚动/缩放。
- [x] 实现 locator JSON 序列化和容错解析。
- [x] 定义 `BookRendererController` 接口。
- [x] 定义 renderer command：open、goTo、applyTheme、setTextOptions、search。
- [x] 定义 renderer event：ready、locationChanged、textSelected、searchResults、bookmarkRequested、renderError。
- [x] `ReaderPage`/`_RendererHost` 根据 book format 选择 renderer。
- [x] 打开书籍时读取 `reading_progress` 并传给 renderer。
- [x] locationChanged 后 debounce 保存 locator 和 progress。
- [x] 应用进入后台、关闭 reader、route pop 时立即 flush 进度。
- [x] 更新 `books.last_opened_at` 和 `read_status`。
- [x] 支持从头开始阅读，不删除历史书签和笔记。
- [x] 支持 progress 为 1.0 时标记已读。
- [x] 渲染错误映射为可读错误 UI。

## 涉及模块和文件

- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/widgets/`
- `lib/features/reader/application/reader_providers.dart`
- `lib/features/reader/application/reader_controller.dart`
- `lib/domain/books/reading_position.dart`
- `lib/domain/books/book.dart`
- `lib/domain/books/book_repository.dart`
- `lib/renderers/common/renderer_command.dart`
- `lib/renderers/common/renderer_event.dart`
- `lib/core/database/daos/progress_dao.dart`
- `test/domain/books/reading_position_test.dart`
- `test/features/reader/`

## 数据与接口

- EPUB locator 主字段：`cfi`；备用字段：`href`、`chapterIndex`、`progress`、`excerpt`。
- PDF locator 主字段：`page`、`scrollOffset`、`zoom`；备用字段：`progress`、`excerpt`。
- `reading_progress.progress` 范围为 0 到 1。
- `reading_progress.updated_at` 每次保存更新。
- 保存频率需要 debounce，默认 1 到 3 秒。

## UI 与交互

- 移动端阅读器默认全屏正文，工具栏隐藏。
- 单击正文空白区域显示工具栏，3 秒无操作自动隐藏。
- 桌面端显示顶部工具栏、可收起目录面板、右侧上下文面板和底部状态栏。
- 底部状态栏展示章节或页码、百分比、字号或缩放。
- 渲染失败时展示“重试”和“查看详情”。

## 验收标准

- [x] 打开书籍会恢复上次阅读位置。
- [x] 翻页或滚动后数据库中的 locator 更新。
- [ ] 关闭应用再打开能回到同一章节或页附近。
- [ ] 字号或缩放变化后当前位置不明显丢失。
- [x] 应用进入后台时进度立即保存。
- [x] renderer 报错不会造成整应用崩溃。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 本轮已验证：`dart format lib/features/reader/presentation/reader_page.dart lib/renderers/epub/epub_renderer_view.dart`、`flutter analyze`、`flutter test -r expanded`、`flutter build windows --debug`。
- 当前实现说明：桌面阅读器已支持左侧常驻目录面板，可通过顶部目录按钮展开/收起；EPUB 目录高亮当前章节，PDF 目录使用 outline 或页码 fallback。阅读器顶部新增阅读模式切换按钮，便于在连续滚动和分页阅读之间切换。桌面底部状态栏已接入当前位置、进度百分比、阅读模式和格式，减少正文上的浮动提示干扰。
- 单元测试：locator 序列化、非法 JSON 容错、progress clamp。
- 手动验证：EPUB/PDF 打开、导航、关闭、重启恢复；Android 返回手势；Windows route 返回。

## 依赖与风险

- 依赖：TASK-02 进度表，TASK-06 EPUB renderer，TASK-07 PDF renderer。
- 风险：EPUB CFI 对样式变化敏感，必须保存 href/chapter/progress 备用。
- 风险：PDF scroll offset 和 zoom 在不同 viewport 下需要容错恢复。
