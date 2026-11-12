---
name: pagesage-dart-engineering
description: 实现和修复 PageSage Dart/Flutter 阅读器，遵循现有 Riverpod、领域分层、Drift/SQLite 和原生渲染结构。用于功能开发、编码规范、异步与持久化修复；不用于把普通任务扩成架构重写。
---

# PageSage Dart / Flutter 工程规范

先读根 `AGENTS.md`、相关任务和实际调用入口。根规范与用户当前要求控制产品边界；
本 skill 补充工程方法，不新增产品能力或改变产品边界。

## 按影响读取

| 本次改动 | 必读参考 |
| --- | --- |
| Dart 实现与错误/异步处理 | [编码与异步](references/dart-conventions.md) |
| Widget、Riverpod、异步 UI、平台资源 | [状态与资源](references/flutter-state.md) |
| 阅读器工具条、提示条、浮动面板与自动收起 | [阅读器界面](references/reader-ui.md) |
| Drift、JSON、领域接口、locator 或导出 | [数据契约](references/data-contracts.md)，并使用 `api-contract-sync` |
| Markdown/EPUB/PDF、索引、AI 检索与来源 | [阅读与检索](references/reader-retrieval.md) |
| 验证、构建、更新本地安装 | 使用 `validation-harness` |

普通开发不用加载所有 reference。规范以本仓库的 `pubspec.yaml`、`analysis_options.yaml`、
最近实现和有效设计为准；查询新增 API/依赖时核对对应版本的官方文档，不假定网络最新版适用。

## 实施顺序

1. 检查相关 Git 差异和新文件，保护现有未提交成果；找到最小生产调用链，而非只看报错行。
2. 明确用户可见预期及关键反例，选择 `validation-harness` 的最小行为证明。
3. 沿现有 Presentation → Application → Domain 边界实现；Data 和 Renderer 使用领域契约。
   UI 不直接调用 DAO；不为小修复批量迁移旧代码。
4. 只修改本任务需要的接口和消费者。优先复用现有模型、取消机制和错误类型，不新增通用框架。
5. 通过选定验证，检查实际差异；应用有变化时完成静默构建和本地安装核对。
6. 在原任务记录实际结果，简洁报告本次改动、验证和影响交付的限制。

## 编码基线

- 保持 `flutter_lints` 与 `dart format`，不为一次功能修改全仓 lint 或加入大包。
- 使用明确类型、sound null safety、不可变状态及有归属的异步任务。
- Dart 文件和目录使用 `lowercase_with_underscores`，类型使用 `UpperCamelCase`，成员使用 `lowerCamelCase`。
- 延续同目录 import 与构造风格；不把所有类统一改为一种修饰符，不添加全局 barrel 或 `utils` 大杂烩。
- 生成文件通过生成器维护；业务规则、失败语义、数据兼容和来源定位必须有可观察验证。

skill、任务或一次通过的测试不是应用完成本身。不得用文档承诺替代实际实现、
用分析器替代行为测试，或用安装成功替代真实阅读与平台验证。
