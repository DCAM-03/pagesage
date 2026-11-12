# PageSage 文档导航

第一次使用请从[项目 README](../README.md)和[测试版说明](beta.md)开始。
本目录纳入版本控制；安装说明、架构决策与脱敏验证记录属于公开项目资料，
不应整体加入 `.gitignore`。

## 当前入口

| 目的 | 文档 |
| --- | --- |
| 测试版能力、限制与反馈 | [公开测试说明](beta.md) |
| Linux 安装、依赖与 OCR | [Linux 分发](linux-distribution.md) |
| Windows / Android 构建与签名 | [平台构建记录](tasks/windows-android-ci-2026-11-12.md) |
| 当前实现和验证边界 | [实现对照清单](implementation-status.md) |
| 隐私与授权 | [隐私说明](privacy.md)、[许可说明](licenses.md) |
| 贡献与安全反馈 | [贡献指南](../CONTRIBUTING.md)、[安全说明](../SECURITY.md) |
| 公开与发布准备 | [发布清单](release-checklist.md)、[本轮公开准备记录](tasks/public-release-preparation-2026-11-12.md) |
| 产品与交互 | [概览](00-overview.md)、[需求](01-product-requirements.md)、[功能](02-feature-spec.md)、[交互](03-interaction-spec.md) |
| 设计、架构与数据 | [设计系统](04-ui-design-system.md)、[技术架构](05-technical-architecture.md)、[数据模型](06-data-model.md) |
| 路线与任务定位 | [路线图](07-roadmap.md)、[任务索引](tasks/README.md) |

## 设计文档与历史记录

- `00`–`07` 是产品与工程设计入口，部分段落记录早期规划；具体落地范围结合最新实现记录和相关任务判断。
- `tasks/`、`specs/` 和迁移计划保留决策与验收背景，任务中的“待验证”不等于现在仍未实现，
  “构建通过”也不等于真实设备验收。
- `eval/` 包含脱敏指标。私人原书和原始题集不公开，不能用这些历史结果宣称任何人均可独立复现。
  自编题集示例与运行方法见[检索评测说明](../tool/retrieval_eval/README.md)。
- `generated/third-party-licenses.md` 是打包使用的依赖许可索引，应保留。
  旧品牌实验不属于发布资源；正式图片来自 `assets/` 与 `images/readme/`。

本机路径、私人评测原件、数据库和构建日志应存放在被忽略的本地目录，
不要借由文档、截图或自动生成报告公开。
