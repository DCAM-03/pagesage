# 代码审查与修复（2026-11-12）

## 范围与验证计划

基于当前工作区审查（包含此前未提交的功能），不以 HEAD 差异作为本轮成果。
采用 code-quality-audit、review-code-organization、pagesage-dart-engineering、
validation-harness；共享定位契约按 api-contract-sync 核对消费者。

重点检查状态与资源所有权、异步身份、迁移失败重试、仓储到渲染器的依赖和无消费者实现。
不按文件行数进行机械拆分，不改数据 schema 或用户书库。

| 候选问题 | 待证明行为 | 验证 |
| --- | --- | --- |
| 两个 AI provider 各建仓储、通知流未释放 | 任一入口写入，两种订阅都更新；初次读取期间不丢更新；销毁终止流 | 新增 ai_profile_repository_test，临时 SQLite + 内存凭证 |
| 迁移 pending 被缓存完成或误标 done | 凭证写失败后，同实例/重建实例可重试且复用同一 profile | ai_profiles_migration_test |
| revision 先查后写 | 同版本并发更新仅一项成功，另一项明确冲突 | ai_profile_repository_test |
| 切配置未失效异步结果 | 原配置的保存/连接测试不能覆盖新配置，切回可编辑 | ai_settings_form_controller_test |
| 通用定位处理位于 EPUB renderer | 仓储、搜索直接使用领域 helper，保留三种格式与定位字段 | epub_jump_test、仓储/搜索/导出回归 |
| 旧单配置仓储及重复读取分支 | 移除无消费者实现，保留旧数据迁移；首次保存走 profile | 静态分析 + profile/恢复测试 |

环境：Linux，Flutter/Dart 版本沿本地锁定环境；测试不访问真实密钥、不发送模型请求。
失败基线和修复后日志放 `/tmp/pagesage-review-*.log`。
完成后运行受影响命名测试、flutter analyze、差异检查，静默构建安装并比对完整 bundle。

## 结果

已修复的确定问题：

- AI settings/profile 共用一个 provider 所有的仓储；通知订阅在初次读取前建立，
  销毁时关闭通知流，避免更新丢失和两套实例不同步。
- 首次保存直接创建 profile 并保存独立凭证，不再写入已废弃的全局配置路径；
  旧仓储删除，唯一工具消费者 `configure_ai_local.dart` 迁至新实现并 finally 释放资源。
- revision 检查、pending operation 与配置写入在同一 SQLite 事务中完成；
  settings 保存使用调用者 revision，拒绝旧快照覆盖新配置。
- pending 凭证迁移允许同实例或重开实例重试，复用确定的 legacy profile ID；
  非敏感旧字段读取逻辑合并，保留必要的历史数据迁移。
- 切 profile 使异步保存/测试结果失效，草稿不会遗留 busy 状态；首次创建后采用实际保存的身份。
- 通用 locator 摘要/补全文本移至 domain；四个仓储与 PDF 不再依赖 EPUB 跳转模块。
- 图片批注拒绝零宽、零高、负尺寸和非有限矩形，避免不可见数据。
- 删除本地数据先清理所有 profile（含逻辑删除组）及旧凭证；凭证服务失败时保留数据库以便重试。

失败基线：`/tmp/pagesage-review-baseline.log` 复现 6 项 AI 问题；
`/tmp/pagesage-review-image-baseline.log` 复现 5 项非法几何写入。
修复后定向回归 `433 PASS / 1 SKIP`，日志 `/tmp/pagesage-review-regression.log`。
跳过项是需要显式开启的规模 benchmark；并非全仓回归。
最终平台/渲染补测 187 PASS，日志 `/tmp/pagesage-review-final-platform-renderer.log`，
与前组重叠不累加。最终离屏布局补测 5 PASS，
日志 `/tmp/pagesage-review-captures-final.log`；检查阅读页深浅主题、页码对话框、
OCR 主按钮/菜单与窄工具条。离屏正文使用测试渲染器，不替代真实书页验收。
`/tmp/pagesage-review-analyze-final.log` 静态分析无问题，
最终两份测试文件格式检查和 `git diff --check` 通过。

截图测试期间曾因全局修改 `debugDisableShadows` 触发测试框架 invariant；
已撤销该修改并重跑通过，保留 `/tmp/pagesage-review-captures-complete.log` 的失败记录。

Linux release 已通过 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`
静默重建安装，日志 `/tmp/pagesage-review-install.log`。
`diff -qr build/linux/x64/release/bundle <HOME>/.local/opt/pagesage`
退出码 0、无差异；两份 `libapp.so` 的 SHA-256 均为
`18cc3f6610d2d864def9d5dcecd1f31113c75165e3531303c7d847704f26797c`。
安装后未发现运行中的 PageSage 实例，未启动新窗口或操作用户进程。

保留的结构债（未将其伪装成全部已清零）：

- `ReaderSettings` 仍引用 Flutter Color/ThemeMode，属于历史领域/视觉耦合；
  改为纯值契约会影响所有设置消费者，当前不为形式统一全仓迁移。
- 搜索索引器仍直接调用 EPUB/Markdown 解析器，宜在新增文档格式时抽取 document source。
- reader/settings 页面仍偏长；本轮提取共享职责并修复实际缺陷，没有按行数机械拆类。
- 阅读设置防抖 controller 的异步错误呈现、AI 凭证跨进程锁及崩溃 journal 恢复，
  在本次审查交付时尚未完成；后续已单独实施，
  见 [设置恢复与 AI 交互打磨](settings-recovery-ai-polish-2026-11-12.md)。
  原审查的 revision 事务结果本身不等价于完成整个凭证服务规格。

## 用户追加范围

1. OCR 工具条合并为一个主动作和下拉菜单，检查菜单生命周期与宽窄/深浅布局。
2. 阅读主题覆盖阅读页目录、工具条、状态栏和弹层，解决夜间正文配亮色周边的问题；
   应用主题继续用于书库、设置等外部页面。同步原先「只改纸色」的规范与提示。
3. 前两项完成后检查 Android/Windows 平台入口、原生 OCR/文件导出和构建配置，
   按 Linux 功能路径适配；本机可执行的分析/测试/构建先完成，真实设备验收由用户后续进行。
