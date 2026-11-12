---
name: review-code-organization
description: 评估 PageSage Dart/Flutter 的 feature 归属、领域与存储边界、Riverpod 依赖和渲染模块组织；用于结构审查或明确的重构，不按文件大小套用通用架构模板。
---

# PageSage 代码组织审查

先读根 `AGENTS.md`、`docs/05-technical-architecture.md`，再读
[Dart 工程入口](../pagesage-dart-engineering/SKILL.md)。以实际 import、调用和资源所有权判断，
不把设计文档中的建议目录当作必须批量迁移的目标。

## 当前边界

- `lib/features/<feature>/presentation` 管界面；`application` 管 controller、用例与跨仓储编排。
- `lib/domain` 定义模型、值对象和 repository 契约，不引入 Flutter Widget、Drift row 或平台 I/O。
- `lib/core/database` 管 Drift 与领域映射；`lib/core/search` 管现有共享索引基础设施。
- `lib/renderers` 管加载、解析、排版和渲染，通过定位/事件与应用层衔接。
- `lib/app` 管装配、路由、主题；feature 私有逻辑不因复用预期就搬到 `core`。

现有解析器等跨层引用须结合调用与迁移成本审查，不能因看到一条 import 就启动全仓 Clean Architecture 重写。

## 输出可实施结论

1. 只盘点相关源码，排除构建、依赖和生成产物；检查实际调用者及被导出的接口。
2. 对发现项区分：保持现状、补边界约束、随功能迁移、需要独立重构。
3. 只有职责冲突、循环依赖、状态/资源所有权不清或重复契约造成具体问题时，建议移动/拆分。
4. 文件长不等于必须拆分。提取可命名、可测试且拥有单一职责的边界，不规定任意行数上限。
5. 获得重构授权后才改结构；保持外部行为和生成入口，验证实际消费者，不顺手统一所有 import。

以确定问题和证据开头，区分本次必要修复与将来可选迁移。不要为了审查产出强制给出新目录树。
