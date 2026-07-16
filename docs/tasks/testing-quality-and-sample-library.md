# TASK-23：自动化测试、样本库和质量门禁

## 目标

建立覆盖核心阅读闭环、数据持久化、搜索、笔记、AI、导出和平台差异的质量体系，确保后续开发每个 task 都能被重复验证。

## 来源与边界

- 来源：`docs/05-technical-architecture.md`、`docs/07-roadmap.md`、`AGENTS.md`。
- 不做：生产遥测上传和远程崩溃收集默认开启。
- 约束：关键逻辑有单元测试或可重复手动验证步骤；Android 和 Windows 平台变化需手动验证。

## 功能范围

- 单元测试。
- Widget 测试。
- 集成测试。
- 样本书库。
- 渲染手动验证清单。
- 数据库迁移测试。
- 性能基线。
- CI 或本地质量命令。
- 回归测试模板。

## 实现任务

- [ ] 为 hash service、format detector、locator serialization 增加单元测试。
- [ ] 为 repository mapping 和 DAO 查询增加测试。
- [ ] 为 search query builder 和 FTS 查询增加测试。
- [ ] 为 AI ContextBuilder 增加测试。
- [ ] 为导出 Markdown/CSV 增加测试。
- [ ] Widget 测试覆盖书库空状态、书籍卡片、搜索结果、设置表单、AI 面板状态。
- [ ] 集成测试覆盖导入 EPUB、导入 PDF、打开、保存进度、重启恢复。
- [ ] 建立手动样本清单：标准 EPUB、大型 EPUB、带图片 EPUB、标准 PDF、大 PDF、扫描版 PDF、损坏文件。已新增 `docs/manual-samples.md` 和 `tool/generate_manual_samples.dart`，可生成本地原创 EPUB/PDF/损坏文件样本；仍缺真实扫描版 PDF 与人工导入/阅读记录。
- [ ] 为每个 renderer 变更记录手动验证结果。
- [ ] 增加数据库迁移测试，覆盖旧 schema 到新 schema。
- [ ] 建立性能基线：书库 1000 本、搜索 1000 chunk、常规 EPUB/PDF 首屏。
- [ ] 增加 `docs/testing-checklist.md` 或在本目录维护验证清单。
- [ ] 每个 task 完成时更新对应测试或手动验证记录。

## 涉及模块和文件

- `test/`
- `integration_test/`
- `test/core/`
- `test/domain/`
- `test/features/`
- `test/renderers/`
- `docs/testing-checklist.md`
- `docs/tasks/`
- `.github/workflows/` 或后续 CI 配置

## 数据与接口

- 测试样本不应打入生产包。
- 样本书籍若有版权限制，只保存测试说明或使用可公开分发样本。
- 测试数据库使用临时目录，不能污染用户数据。
- AI 测试使用 fake provider，不发真实网络请求。

## UI 与交互

- Widget 测试需覆盖空状态、错误状态、加载状态。
- 可访问性测试应检查语义标签和焦点路径。
- 渲染手动验证记录需要包含平台、样本、操作、结果和问题。

## 验收标准

- [ ] `flutter test` 覆盖核心 domain 和 application 逻辑。
- [ ] 关键 UI 状态有 widget test。
- [ ] 导入和恢复进度有集成或可重复手动验证。
- [ ] Renderer 变更有 EPUB/PDF 样本验证。
- [ ] 数据库迁移有测试。
- [ ] AI 测试不需要真实 API key。

## 测试与验证

- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter doctor -v`
- 平台手动验证：Windows 加 Android。

## 依赖与风险

- 依赖：所有业务 task。
- 风险：没有固定样本会导致 renderer 回归难以判断。
- 风险：AI 和平台测试如果依赖真实服务或设备，会导致本地验证不稳定，需要 fake 和手动清单结合。
