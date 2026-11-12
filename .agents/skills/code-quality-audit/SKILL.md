---
name: code-quality-audit
description: 审查 PageSage Dart/Flutter 变更的错误处理、类型与空安全、异步竞态、Riverpod 状态、资源释放、数据兼容和测试真实性；用于质量审查及有明确风险的修复，不默认扩成全仓整治。
---

# PageSage Dart 质量审查

读取 [Dart 编码与异步规范](../pagesage-dart-engineering/references/dart-conventions.md)，
涉及界面时再读 [Flutter 状态与资源](../pagesage-dart-engineering/references/flutter-state.md)。

## 从实际变更检查

1. 确认本任务起始状态、实际差异和新文件；仓库内其他未提交改动不是本轮成果，也不自动成为修复范围。
2. 对照用户行为和调用方检查下列高风险位置，不能把搜索命中机械地认定为 bug。
3. 每个问题说明触发路径、实际影响、最小修复与对应验证。分类为确定缺陷、合法兼容/降级或非问题。
4. 优先修正范围内确定缺陷；无关重构和可选优化单列。用 `validation-harness` 验证关键行为。

## Dart 审查重点

- `dynamic`、`as`、`!`、`late` 是否仅用于明确边界，是否把无数据、损坏和加载失败混为一种状态。
- `catch` 是否吞错或返回空成功；`rethrow` 是否保留堆栈；取消是否被错误保存为完整成功或普通失败。
- `await` 后是否检查存活与请求身份，旧书/旧查询结果是否可能覆盖新选择。
- Widget `build()` 是否启动 I/O、写入业务数据或重复订阅；Riverpod 是否持有同一状态的多个可变副本。
- controller、timer、subscription、数据库、PDF 页面/图片和文件资源是否由实际拥有者释放。
- `unawaited` 是否有明确的错误处理与生命周期归属；昂贵解析是否阻塞 UI。
- settings / locator / AI 快照是否往返一致，nullable 更新是否能区分“清空”和“不修改”。
- 测试是否断言原始定位、旧数据、失败和重开等真实行为，而非只断言“不抛错”或固定文案。
- 日志、夹具和截图是否含密钥、用户正文或本机真实书库数据。

## 工具的边界

主要证据为 `flutter analyze`、实际代码检查及命名行为测试。此目录遗留的
`scripts/scan_code_quality.py` 不支持 Dart；不得以其零命中或 Java/Go profile 声称 Dart 审查通过。
搜索只用于定位候选，不能代替语义分析；本次不新增一套正则扫描门禁。
