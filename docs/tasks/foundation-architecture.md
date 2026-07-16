# TASK-01：工程基础、分层架构、导航和主题

## 目标

建立 PageSage 长期开发所需的 Flutter 工程骨架，让功能代码按 Presentation、Application、Domain、Data、Renderer、Platform 分层扩展，并形成稳定的主导航、主题、错误模型和日志入口。

## 来源与边界

- 来源：`docs/00-overview.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`、`docs/05-technical-architecture.md`。
- 不做：具体书籍业务、AI 请求、搜索索引、导出备份的业务实现。
- 约束：使用 Flutter、Riverpod、go_router；保持 Android 和 Windows 首发兼容。

## 功能范围

- 应用启动和依赖初始化。
- go_router 路由树。
- 移动端底部导航和桌面端侧边导航。
- 全局主题、阅读主题基础 token。
- 应用错误模型和错误展示基础。
- 日志服务基础，默认不记录敏感内容。
- Feature 目录和核心服务目录保持一致。

## 实现任务

- [ ] 梳理 `lib/` 目录，确认 feature、domain、core、renderers、app 边界。
- [ ] 统一 Riverpod provider 命名和生命周期。
- [ ] 建立 app bootstrap，集中初始化数据库、文件目录、日志和平台服务。
- [ ] 配置 go_router：书库、搜索、笔记、设置、书籍详情、阅读器。
- [ ] 实现响应式 shell：compact 使用底部导航，expanded 使用左侧导航。
- [ ] 阅读器作为独立页面打开，主导航在阅读器中隐藏。
- [ ] 建立 `AppError`、错误映射和通用错误 UI。
- [ ] 建立 `AppLogger`，对密钥、书籍正文、AI 请求内容做默认脱敏。
- [ ] 统一主题 token：颜色、字号、间距、圆角、焦点样式。
- [ ] 为主要入口添加语义标签和 tooltip 基础策略。

## 涉及模块和文件

- `lib/main.dart`
- `lib/app/bootstrap.dart`
- `lib/app/pagesage_app.dart`
- `lib/app/router.dart`
- `lib/app/theme/app_theme.dart`
- `lib/app/theme/reader_theme.dart`
- `lib/core/errors/app_error.dart`
- `lib/core/errors/error_mapper.dart`
- `lib/core/logging/app_logger.dart`
- `lib/features/*/presentation/`
- `lib/features/*/application/`
- `test/widget_test.dart`

## 数据与接口

- 路由参数统一使用 `bookId`、`noteId`、`searchQuery` 等稳定命名。
- Presentation 只依赖 controller/provider 暴露的状态。
- Controller 调用 use case 或 repository，不直接操作 widget context 做业务持久化。
- Repository 返回 domain model，不返回 Drift row。

## UI 与交互

- 启动后直接进入书库，不做营销页或强制引导。
- 移动端主导航为：书库、搜索、笔记、设置。
- 桌面端主导航为：PageSage、书库、搜索、笔记、分类目录、设置。
- 阅读器打开后隐藏主导航，保留返回入口。
- 所有 icon-only 按钮需要 semantic label；不明显图标需要 tooltip。

## 验收标准

- [ ] 应用在 Android 和 Windows 都能启动到主界面。
- [ ] 窗口宽度变化时主导航能在底部导航和侧边导航之间切换。
- [ ] 阅读器 route 不显示底部或侧边主导航。
- [ ] 主题切换不会造成文字对比度明显不足。
- [ ] 错误状态能显示简短原因和可执行操作。
- [ ] 日志中不出现 API key、完整 AI payload、选中文本或整段书籍正文。

## 测试与验证

- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- 手动验证：Windows 窗口缩放、Android 竖屏导航、阅读器 route 返回。

## 依赖与风险

- 依赖：无业务前置依赖，是其他 task 的基础。
- 风险：早期路由和 provider 命名混乱会放大后续迁移成本。
- 风险：桌面和移动导航如果在同一页面硬编码，后续响应式维护成本高。

