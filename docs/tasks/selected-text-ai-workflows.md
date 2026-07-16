# TASK-16：划词 AI、上下文范围、流式回答和保存

## 目标

实现用户主动触发的划词 AI 工作流：选中文本、选择动作、明确上下文范围、发送请求、流式显示回答、取消、复制、重试和保存为笔记。

## 来源与边界

- 来源：`docs/00-overview.md`、`docs/01-product-requirements.md`、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`。
- 不做：自动整章或整本书后台分析、默认上传整本书、云端对话同步。
- 约束：AI 请求只发送用户允许的上下文；每次请求的上下文范围必须可见。

## 功能范围

- 文本选择菜单 AI 入口。
- 阅读器 AI 面板。
- 搜索结果和笔记页对片段提问。
- 快捷动作：解释、翻译、总结、提取要点、生成问题、简单说明、自定义提问。
- ContextBuilder。
- 上下文范围选择。
- 隐私确认。
- 流式回答和取消。
- 保存对话记录。
- 保存回答为笔记。
- AI 回答进入全局搜索。

## 实现任务

- [x] 定义 `ContextBuilder`，按 selected text 和 locator 获取上下文。
- [x] 支持上下文范围：仅选中文本、前后段落、当前章节、当前页。
- [x] 生成用户可读的上下文范围说明。
- [x] AI 面板展示选中文本摘要、范围、输入框和回答区。
- [x] 隐私设置开启时发送前弹确认框。
- [x] 调用 `AiProvider.streamChat()` 并流式显示回答。
- [x] 支持取消请求，保留已生成部分供用户决定是否保存。
- [x] 支持重试和复制回答。
- [x] 保存 `ai_conversations`，不保存 API key。
- [x] 保存为笔记时创建 `notes` 记录并写回 `ai_conversations.note_id`。
- [x] AI 回答保存后写入搜索 chunk。
- [x] 对上下文过长做提示并允许缩小范围。
- [x] 错误状态提供修改设置和复制错误。

## 涉及模块和文件

- `lib/features/ai/application/context_builder.dart`
- `lib/features/ai/application/ai_chat_controller.dart`
- `lib/features/ai/presentation/ai_panel.dart`
- `lib/domain/ai/ai_conversation.dart`
- `lib/core/database/daos/ai_conversation_dao.dart`
- `lib/features/reader/presentation/widgets/text_selection_menu.dart`
- `lib/features/search/presentation/widgets/search_result_card.dart`
- `lib/features/notes/presentation/`
- `lib/features/search/application/search_indexer.dart`
- `test/features/ai/selected_text_ai_test.dart`

## 数据与接口

- `ai_conversations` 保存 provider、model、prompt、context_text、answer、source_text、locator、note_id。
- `context_text` 属于用户数据，普通日志不得记录。
- `AiRequest` 包含 systemPrompt、userPrompt、context、temperature、maxTokens。
- ContextBuilder 需要按书籍格式返回不同上下文：EPUB 章节信息，PDF 页码信息。

## UI 与交互

- 移动端 AI 面板使用底部抽屉或全屏页。
- 桌面端 AI 面板在右侧 Tab。
- 默认上下文范围为“仅选中文本”。
- 快捷动作使用按钮或 segmented group，不使用夸张科技风。
- AI 未配置时入口提示配置。
- 流式输出时不使用整块 loading。
- 回答完成后显示复制、保存、重试。

## 验收标准

- [x] 用户选中文本后能打开 AI 面板。
- [x] 发送前能看到上下文范围。
- [x] 默认不会发送整本书。
- [x] 请求可取消。
- [x] 回答可保存为笔记。
- [x] 保存后的 AI 回答可搜索。
- [x] 未配置、网络错误、上下文过长等状态有明确提示。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 单元测试：ContextBuilder、范围说明、请求取消、保存为笔记。
- 手动验证：EPUB 选词解释、PDF 选词总结、搜索结果提问、笔记页提问、隐私确认开关。

## 依赖与风险

- 依赖：TASK-11 文本选择，TASK-12 笔记，TASK-14 搜索索引，TASK-15 AI Provider，TASK-18 隐私策略。
- 风险：上下文构造如果过宽会违背隐私预期，必须默认最小范围。
- 风险：AI 流式响应和取消需要避免资源泄露。
