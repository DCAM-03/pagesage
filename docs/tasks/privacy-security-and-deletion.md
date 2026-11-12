# TASK-18：隐私、安全、日志和危险删除

## 目标

落实 PageSage 的本地优先和可控 AI 原则，确保书籍、笔记、进度、搜索索引和 AI 上下文默认保存在本机，敏感信息不被日志或普通设置泄露，并为危险删除提供明确确认。

## 来源与边界

- 来源：`AGENTS.md`、`docs/01-product-requirements.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：账号、云同步、端到端加密同步。
- 约束：AI 上下文范围可见；不自动上传整本书；API key 仅 secure storage。

### AI 触发规则更新（2026-11-09）

- 按用户要求，取消将「每次必须由用户主动点击」作为所有 AI 功能的实现前提。摘要生成、模型辅助索引和其他后台 AI 能力可按具体功能设计实现，不再受这条全局限制阻挡。
- 保留上下文范围明确、不自动上传整本书、AI 启用开关和现有请求确认设置；自动触发的功能也须遵守这些设置与请求范围。
- 本次同步产品文档，不新增自动任务，不改变现有请求流程或用户设置。验证选择：检索旧约束残留、运行具名文档链接检查并检查差异空白；无需应用构建安装。
- 验证结果：全局「仅用户触发」限制的旧表述已清除；`release_readiness_test.dart` 的 `documentation links and release assets stay valid` 用例通过（1 项），日志 `/tmp/pagesage-ai-trigger-rule-doc-check.log`；本轮 6 份文档相对开工快照无新增空白错误，`lib/`、`test/`、`assets/` 文件哈希保持不变。

## 功能范围

- 隐私设置页。
- AI 开关和请求前确认。
- 清空 AI 历史。
- 删除所有本地数据。
- 删除书籍和关联数据规则。
- 日志脱敏。
- 错误详情脱敏。
- 安全存储封装。
- 导出和备份隐私边界。

## 实现任务

- [x] 隐私设置中提供启用 AI 开关。
- [x] 提供“每次 AI 请求前确认上下文”开关。
- [x] AI 面板发送前展示上下文范围。
- [x] 清空 AI 历史：删除 `ai_conversations` 和 source_type 为 `ai` 的 search chunks。
- [x] 清空 AI 历史时不删除已保存为普通笔记的内容，除非用户选择。
- [x] 删除所有本地数据：删除数据库、应用副本、封面、索引、书签、笔记、AI 记录。
- [x] 危险删除使用二次确认或输入确认文字。
- [x] 删除书籍时明确是否删除关联笔记和 AI 记录。
- [x] 日志默认不记录 API key、AI payload、选中文本、完整上下文和大段书籍正文。
- [x] 错误详情对路径、密钥、正文做必要脱敏。
- [x] 安全存储失败时给出明确错误和恢复建议。
- [x] 隐私说明用于发布包。

## 涉及模块和文件

- `lib/features/settings/presentation/privacy_settings_page.dart`
- `lib/core/security/secure_store.dart`
- `lib/core/logging/app_logger.dart`
- `lib/core/errors/error_mapper.dart`
- `lib/domain/books/book_repository.dart`
- `lib/domain/ai/ai_conversation_repository.dart`
- `lib/core/database/daos/search_dao.dart`
- `lib/core/files/file_repository.dart`
- `docs/privacy.md`
- `test/core/logging/`
- `test/features/settings/privacy_test.dart`

## 数据与接口

- `privacy.confirmBeforeAiRequest` 控制 AI 发送前确认。
- `ai.enabled` 控制联网 AI 入口。
- 清空 AI 历史需要同时处理 `ai_conversations` 和对应搜索 chunk。
- 删除全部数据需要按数据库、文件、缓存、日志策略执行。
- API key 只通过 `SecureStore` 获取，不能通过 repository 暴露给 UI 字符串状态。

## UI 与交互

- 隐私设置分组清楚区分“AI 隐私”“本地数据”“日志与诊断”。
- 危险按钮使用 danger 样式，不作为默认焦点。
- 删除所有本地数据需要输入确认文字或二次确认。
- AI 请求确认框展示：将发送的文本范围、Provider、模型、可取消按钮。
- 清空 AI 历史说明不会删除已保存为笔记的内容。

## 验收标准

- [x] 默认不需要登录即可使用。
- [x] 默认不自动上传书籍正文。
- [x] API key 不进入 SQLite、日志、导出备份。
- [x] 用户可以关闭 AI 功能。
- [x] 用户可以清空 AI 历史。
- [x] 删除所有本地数据后书库、笔记、进度、索引、AI 记录都被清除。
- [x] 危险操作都有确认。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 单元测试：日志脱敏、清空 AI 历史、删除全部数据。
- 手动验证：AI 确认框、API key 清除、删除书籍关联数据、删除全部数据。

## 依赖与风险

- 依赖：TASK-02 数据库，TASK-15 AI 设置，TASK-16 AI 工作流，TASK-17 导出备份。
- 风险：错误日志在异常路径中容易意外记录上下文，需要统一 error mapper 和 logger policy。
- 风险：删除全部数据不可逆，必须确保确认足够明确。
