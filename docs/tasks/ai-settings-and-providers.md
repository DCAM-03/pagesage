# TASK-15：AI Provider 设置、安全存储和连接测试

## 目标

建立 AI Provider 设置体系，支持 OpenAI-compatible Provider 和本地模型扩展点，安全保存 API key，并在未配置时提供清晰引导。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：自动整本书分析、后台自动上传、云账号。
- 约束：AI 必须由用户主动触发；API key 只存 secure storage，不进 SQLite 和普通日志。

## 功能范围

- AI 设置页。
- Provider 抽象。
- OpenAI-compatible Provider。
- Base URL、model、temperature、max tokens、streaming、system prompt。
- API key 安全存储。
- Provider 连接测试。
- 启用/关闭联网 AI。
- 清空 AI 历史入口。
- 错误分类和恢复操作。

## 实现任务

- [x] 定义 `AiProvider`、`AiRequest`、`AiChunk`、`AiProviderStatus`。
- [x] 实现 OpenAI-compatible streaming adapter。
- [x] SecureStore 封装 API key 写入、读取、清除。
- [x] `app_settings` 保存非敏感 AI 设置。
- [x] 设置页支持 Base URL、Model、Temperature、Max tokens、流式输出、默认系统提示词。
- [x] API key 默认掩码显示，支持显示/隐藏和清除。
- [x] 连接测试不发送书籍正文。
- [x] 未配置时 AI 入口不会崩溃并提示配置。
- [x] 支持关闭所有联网 AI 功能。
- [x] 错误映射：API key 无效、网络错误、Provider 不可用、模型不存在、上下文过长、请求取消。
- [x] 日志脱敏 Provider 请求和响应内容。

## 涉及模块和文件

- `lib/domain/ai/ai_provider.dart`
- `lib/domain/ai/ai_request.dart`
- `lib/domain/ai/ai_models.dart`
- `lib/features/ai/application/ai_providers.dart`
- `lib/features/ai/data/openai_compatible_provider.dart`
- `lib/features/settings/presentation/ai_settings_page.dart`
- `lib/core/security/secure_store.dart`
- `lib/core/logging/app_logger.dart`
- `lib/core/errors/app_error.dart`
- `test/features/ai/`
- `test/core/security/`

## 数据与接口

- `app_settings` 保存：
  - `ai.enabled`
  - `ai.provider`
  - `ai.baseUrl`
  - `ai.model`
  - `ai.temperature`
  - `ai.maxTokens`
  - `ai.streaming`
  - `ai.systemPrompt`
  - `privacy.confirmBeforeAiRequest`
- API key 使用 secure storage key，例如 `ai.<provider>.apiKey`。
- `AiProvider.streamChat()` 返回 chunk stream，并支持取消。

## UI 与交互

- 设置页移动端为分组二级页，桌面端为左侧分组右侧详情。
- API key 输入框默认掩码。
- 清除 API key 需要确认。
- 连接测试显示测试中、成功、失败和失败原因。
- 未配置 AI 时，文本选择菜单中的 AI 操作显示“配置 AI 后使用”。

## 验收标准

- [x] API key 不出现在 SQLite、普通日志或错误详情中。
- [x] 配置 Provider 后能完成连接测试。
- [x] 未配置时 AI 入口不会崩溃。
- [x] 用户可以关闭联网 AI。
- [x] 清除 API key 后后续请求不可用并提示配置。
- [x] Provider 错误被映射为用户可理解原因。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 单元测试：设置读写、安全存储 mock、错误映射、stream 取消。
- 手动验证：Windows 和 Android 设置页、API key 掩码、清除确认、未配置入口。

## 依赖与风险

- 依赖：TASK-02 app_settings，TASK-18 隐私日志策略。
- 风险：AI API 形态可能变化，Provider 抽象应隔离 UI 和业务。
- 风险：安全存储在 Windows 和 Android 的行为不同，需要平台验证。
