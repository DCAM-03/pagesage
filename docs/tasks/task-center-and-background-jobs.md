# TASK-19：任务队列、任务中心、重试和取消

## 目标

实现统一任务队列和任务中心，用于导入、元数据提取、索引、重建索引、导出、备份和恢复等长任务，并支持进度展示、失败重试、取消和应用重启后的恢复策略。

## 来源与边界

- 来源：`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/06-data-model.md`。
- 不做：系统级后台同步、云任务、跨设备队列。
- 约束：长任务不能阻塞阅读；任务失败要可恢复。

## 功能范围

- 任务模型。
- 任务队列。
- 任务持久化。
- 任务中心 UI。
- 导入队列。
- 索引任务。
- 导出和备份任务。
- 取消、重试、查看详情。
- 重启后的任务恢复。
- 错误日志和用户可读消息。

## 实现任务

- [x] 定义 `TaskModel` 和 `TaskStatus`。
- [x] 多文件导入由用例逐项 await，任务状态、取消与启动恢复由现有 repository / registry / controller 管理；未接入的 `TaskQueue` 骨架已于 2026-11-09 清理。
- [x] OCR 页码范围任务由跨任务 FIFO 单 worker 串行执行；排队任务可暂停/取消，并持有本进程取消令牌以避免启动恢复误判。
- [x] 实现 `TaskDao` 持久化任务状态。
- [x] 导入任务写入 queued/running/indexing/done/failed/cancelled。
- [ ] 索引任务支持重建单书和重建全部。
- [x] 导出和备份任务支持进度。
- [ ] 长任务可取消，取消后清理临时文件。
- [x] 失败任务可重试。
- [x] 任务中心展示等待中、进行中、完成、失败。
- [x] 应用重启后 pending/running 任务按类型恢复为 pending 或 failed。
- [x] 书库卡片和详情能显示导入/索引状态。
- [x] 错误详情支持复制，但脱敏。

## 涉及模块和文件

- `lib/core/tasks/task_cancellation.dart`
- `lib/core/tasks/task_models.dart`
- `lib/core/tasks/task_runner.dart`
- `lib/features/ocr/application/ocr_job_controller.dart`
- `lib/core/database/daos/task_dao.dart`
- `lib/features/tasks/presentation/task_center_page.dart`
- `lib/features/import/application/import_use_case.dart`
- `lib/core/search/search_indexer.dart`
- `lib/features/export/application/export_service.dart`
- `test/core/tasks/`

## 数据与接口

- 任务字段：id、type、status、source_path、target_path、book_id、progress、message、error、created_at、updated_at。
- 任务类型：import、metadata、index、rebuildIndex、exportNotes、backup、restore。
- 任务状态：queued、running、done、failed、cancelled。
- 任务 progress 范围 0 到 1。

## UI 与交互

- 多文件导入时打开任务中心或显示导入队列。
- 任务项显示文件名或书名、状态、进度、消息。
- 失败项显示重试和查看详情。
- 可取消任务显示取消按钮。
- 任务完成后可收起历史或清除已完成任务。
- 书库中索引中状态轻量显示，不阻塞打开。

## 验收标准

- [x] 多文件导入能逐项显示状态。
- [x] 索引中不阻塞阅读。
- [x] 失败任务能重试。
- [ ] 可取消任务能停止并清理临时文件。
- [x] 应用重启后运行中任务不会卡在 running。
- [x] 任务错误详情不泄露敏感文本或 API key。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 单元测试：任务状态流转、重试、取消、重启恢复策略。
- 手动验证：多文件导入、索引失败、导出取消、任务中心 UI。

## 依赖与风险

- 依赖：TASK-02 import_tasks，TASK-03 导入，TASK-14 索引，TASK-17 导出备份。
- 风险：长任务并发写数据库可能导致状态错乱，需要事务和状态机保护。
- 风险：取消任务如果不清理临时文件会产生孤立文件。

## 2026-11-11 增量：OCR 任务控制

- 部分完成或失败 OCR 任务提供“重试失败页”，只重置 failed 页；完成页不会再次 OCR。
- 非运行中 OCR 任务提供“清除 OCR 结果”，确认后清理关联页文本、任务 checkpoint、内存缓存与搜索索引。
- 清除不会删除原 PDF、原生文字、笔记或批注；运行中任务必须先暂停或取消。
- 证据：OCR/任务/索引器 53 项聚焦、全仓 961 项通过 / 5 skipped、静态分析无问题；Linux 安装 bundle 一致。
