# TASK-15：AI Provider 设置、安全存储和连接测试

## 2026-11-12 增量：中断恢复与设置交互

- 凭证修改/清除/删除与恢复共用数据库 OS 锁；pending 写入无法核实则清除不确定密钥、
  提示重新输入，保留非敏感配置。失败的复制不遗留可见空配置，原配置密钥不受影响。
- 关闭 AI 时允许离线编辑和保存，连接测试仍需启用；首次保存失败后保留草稿及新 profile 身份。
- 阅读设置防抖保存增加状态、失败重试、串行写入和面板关闭 flush。
- 验证与安装证据统一记录在
  [设置恢复与 AI 交互打磨](settings-recovery-ai-polish-2026-11-12.md)。

## 目标

建立 AI Provider 设置体系，支持 OpenAI-compatible Provider 和本地模型扩展点，安全保存 API key，并在未配置时提供清晰引导。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：自动整本书分析、后台自动上传、云账号。
- 约束：AI 请求的上下文范围必须可见；API key 只存 secure storage，不进 SQLite 和普通日志。

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

## 2026-11-10：设置表单与交互打磨

### 实施前基线与验收

- 基线：普通保存没有独立忙碌状态，“保存并测试”在保存之后才进入忙碌状态，清除密钥可与保存交叠；卡片销毁会丢弃草稿，服务返回时部分路径没有卸载检查。生成参数与连接字段全部平铺，操作按钮在长表单末尾。
- 本轮范围：连接配置优先展示，高级参数折叠；连接区附近显示保存/测试操作、未保存状态及明确的结果。统一保存、测试、启用和清密钥的互斥；设置页会话内保留草稿，刷新时按字段合并，失败保留输入，忽略已过期或卸载后的测试结果。草稿仅驻留内存，不新增持久化或依赖。
- 行为证明：扩展 `test/features/settings/ai_settings_card_test.dart`，新增 `test/features/settings/ai_settings_form_controller_test.dart`；用可控 Future 验证慢保存、重复操作、失败重试、切换分类、外部配置刷新、测试中改配置及卸载返回，不连接真实模型服务或用户 secure storage。
- 相关回归：`test/features/settings/`、`test/features/ai/ai_chat_service_test.dart` 和 `test/widget_test.dart`，以及 `flutter analyze`；正常测试并发 4。
- 离屏：900/1440px 桌面、390px 窄屏、短窗口及 1.5/2 倍文字，检查浅/暗色、未配置、未保存、处理中和失败。证据存于 `/tmp/pagesage-ai-settings-*.log` 与 `build/workbench-captures/ai-settings-*.png`。
- 通过后静默执行 Linux 构建安装并核对完整 bundle；不启动窗口、不重启运行实例。真实窗口、真实接口及 Windows/Android 本轮未验收。

### 实施与验证结果

- 新增应用层 `AiSettingsFormController` 管理草稿、校验、互斥操作与结果；界面保留文本控制器和密钥清除确认，不新增领域/数据库契约、依赖或迁移。设置页持有表单会话，分类卡片重建不丢草稿。
- UI 去掉 AI 分组内的重复装饰卡片，连接配置与保存操作优先；高级项默认收起，字段校验失败时自动展开。状态就地显示，不使用会打断操作的临时提示。
- 反例：旧实现的同一保存回调连续触发两次实际写入 2 次，`/tmp/pagesage-ai-settings-baseline.log` 留存失败；修复后只写入 1 次。另修复刷新配置时将缓存旧值误作新配置，导致成功提示消失或进行中的测试失效的问题，刷新中的缓存值不参与合并。
- 行为验证：`flutter test test/features/settings/ai_settings_form_controller_test.dart test/features/settings/ai_settings_card_test.dart --concurrency=4 --reporter expanded` 24 项通过，覆盖操作互斥、失败重试、桌面分类/窄屏返回保留、外部刷新合并和旧测试结果隔离。
- 相关回归：`flutter test test/features/settings test/features/ai/ai_chat_service_test.dart test/widget_test.dart --concurrency=4 --reporter expanded` 83 项通过；`flutter analyze` 无问题。此为受影响回归，不是全仓回归。
- 离屏组件验证：`flutter test test/features/settings/ai_settings_card_test.dart --dart-define=CAPTURE_READER_WORKBENCH=true --concurrency=1 --reporter expanded` 13 项通过；涵盖 1440/900/390px、浅/暗色及最高 2 倍文字，生成 17 张截图。已目检桌面、窄屏操作、高级项、未配置、保存中、失败和禁用 8 张，另补测高级项收起时校验错误会自动展开。测试使用虚构配置，不访问用户密钥或真实模型服务。
- 网络边界：测试过期和卸载时仅忽略其返回结果，不声称中断已发出的 HTTP 请求；本轮未修改 `AiChatService`。
- 安装：静默执行 `FLUTTER=<HOME>/app/flutter-3.44.2/bin/flutter CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 成功；release bundle 与 `$HOME/.local/opt/pagesage` 全目录对比一致。两侧 `libapp.so` SHA256 均为 `6fa07efa2d3fb9d03721fdf36c6c1b3776fa634d447a15c000f0ac89f31fe1ab`；源码候选清单安装前后校验一致，见 `/tmp/pagesage-ai-settings-candidate.sha256`、`/tmp/pagesage-ai-settings-candidate-check.log`、`/tmp/pagesage-ai-settings-install.log` 和 `/tmp/pagesage-ai-settings-bundle-diff.log`。安装前后均未发现运行实例，未启动窗口。

## 2026-11-11：多组配置交互与异常收口

- 基线与问题：配置列表加载中、读取失败、空列表和活动配置不在返回列表中的表现混在一起；加载或失败时仍可操作，活动 ID 缺失会让下拉选项与当前值不一致。复制、重命名和删除同时平铺，窄屏占用较高；配置操作失败没有就地反馈，也没有统一的防重复保护。
- 交互调整：当前配置始终以已保存的组名显示，活动 ID 暂时不在列表中也不会失去选中项；加载中明确显示读取状态并暂时禁用选择与操作，读取失败显示可重试状态，空列表提示新建后自动切换。
- 操作收拢：保留配置下拉和“新建配置”直接入口，将复制、复制配置和密钥、重命名、删除统一收进“配置操作”菜单。新建或复制成功后自动切换到新组；所有配置操作在完成前互斥，失败后显示当前配置区域内的可关闭错误，不丢现有表单内容。
- 返回契约：`AiSettingsController.createProfile` 返回创建的 `AiProfile?`，供界面在成功后选中；底层仓储与持久化格式未变化。
- 定向验证：新增 `test/features/settings/ai_profile_selector_test.dart`，覆盖加载、读取失败、活动配置缺失、菜单收拢、切换与新建后自动激活及重命名失败。`flutter test test/features/settings --dart-define=CAPTURE_READER_WORKBENCH=true --concurrency=4 --reporter expanded` 48 项通过；`test/features/ai/ai_panel_thread_test.dart` 与 `test/widget_test.dart` 受影响回归 45 项通过。综合测试原先在进入 AI 设置时读取默认数据库，现显式隔离空配置流。日志为 `/tmp/pagesage-ai-profile-settings-suite-final.log`、`/tmp/pagesage-ai-profile-regression-3.log`。
- 离屏检查：检查 5 张截图，涵盖 390px/1.5 倍文字下的加载、读取失败、操作菜单、重命名失败，以及 1440px 设置页。加载状态、错误操作、菜单边界和空配置提示均无溢出；截图位于 `build/workbench-captures/ai-profile-*.png` 与 `ai-settings-*.png`。不能替代真实窗口、真实 Provider 或跨平台验收。
- 工程验证：相关 4 个 Dart 文件格式检查通过，`flutter analyze` 无问题，`git diff --check` 通过。日志为 `/tmp/pagesage-ai-profile-format.log`、`/tmp/pagesage-ai-profile-analyze-final.log`、`/tmp/pagesage-ai-profile-diff-final.log`。
- 安装：`CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 静默构建并安装成功，完整 release bundle 与 `$HOME/.local/opt/pagesage` 对比一致；两侧 `lib/libapp.so` SHA-256 均为 `9ffdfc9258d8e8e3533bdceb5e8a4319874574931e3248966250fed5f3d89980`。日志为 `/tmp/pagesage-ai-profile-install-final.log`、`/tmp/pagesage-ai-profile-install-final-hashes.log`。安装时未发现运行实例，未启动窗口；真实窗口、真实 Provider 和 Windows/Android 未验收。
