# PageSage 验证与安装

## 选择最小证明

从本次行为和实际消费者选行，不把整张表变成每次任务的必做清单。

| 变化 | 优先验证 | 不足以单独证明 |
| --- | --- | --- |
| Dart 值对象、切块、序列化 | 命名纯逻辑测试、边界与往返断言 | analyze 通过 |
| controller / service / Riverpod | 依赖可控的行为测试，覆盖失败、取消与过期结果 | 只断言方法被调用 |
| Widget 交互、侧栏与设置 | 事件和状态断言；布局需要时补离屏截图 | 仅有截图或固定文案断言 |
| Drift schema / 恢复 / 删除 | 临时真实 SQLite，新库、历史结构升级、关键数据与必要的文件重开 | mock、内存对象或仅把当前库版本号改小 |
| EPUB / PDF / Markdown | 解析与排版组件测试；实际平台的定位、保存和重开 | 单元测试或离屏图代替真实 renderer 接线 |
| 检索与上下文 | 同口径夹具评测、证据完整性、来源 / 预算与无答案场景 | 离线召回代替模型答案与交互质量 |
| skill / 纯文档 | frontmatter、metadata、本地引用、差异与内容审查 | 无关的 Flutter 全套测试 |

迁移样本须对应真实旧结构；涉及文件持久化时保留 close/reopen。测试使用临时库和样本，
不连接用户书库、secure storage 或真实模型服务。以实际契约决定反例，不制造与功能无关的门禁。

## 命令选择

以下是本仓库现有路径的示例，选择受影响项，不逐条照跑：

```bash
dart format --output=none --set-exit-if-changed lib/domain/books/reader_settings.dart
flutter analyze
flutter test test/domain/books/reader_settings_test.dart --concurrency=4 --reporter expanded
flutter test test/core/database/ai_context_snapshot_test.dart --concurrency=4 --reporter expanded
```

需要写入格式时对变更 Dart 文件运行 `dart format <files>`。schema 或其他生成输入变化时才按项目入口运行
`dart run build_runner build --delete-conflicting-outputs`，审查生成影响范围。依赖变化或缺失才运行 `flutter pub get`。

- 命名测试优先，默认并发 4。`tool/check.sh` 是较宽验证入口，不是每次小改的默认命令。
- 完整回归用于明确的全量回归或发布准备；运行后如实记录，不把几个定向 PASS 当作完整回归 PASS。
- 长输出写入任务已有日志目录或临时日志，保留退出码后再读取摘要 / 失败上下文。不要用吞掉失败的管道制造成功。
- 全量 format、生成、测试或 build 的成本与影响应匹配本次变更；已有有效证据不因新一轮会话重跑。
- 不新开终端窗口。桌面 `integration_test` 可能启动真实应用，不能因命令名字叫 test 就当作离屏静默验证。
- 需要可见窗口的验证须符合用户已授权范围；本项目默认不自行启动，记录缺少的真实平台证据。
- 平台实现发生变化时，在环境可用且验证方式获授权的情况下验证 Windows 与一个 Android 目标；Linux 结果不能替代。

## 本地安装

应用代码、资源、依赖或运行配置变化且必要检查通过后，立即静默构建安装，不等下一轮提醒：

```bash
CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh
diff -qr build/linux/x64/release/bundle "$HOME/.local/opt/pagesage"
```

以实际 `tool/install_linux.sh` 的路径和配置为准；路径调整后同步检查目标。保留本次源码候选、
构建退出状态及产物 / 安装核对结果，避免拿上次成功日志证明新候选。构建与测试不并发争抢资源。

不启动新窗口，不关闭或重启用户已运行的 PageSage。已安装新产物与运行中进程版本分开记录；
仅在本次确实安装后简短告知用户重启已有应用。安装失败不能报已更新，也不修改无关的系统或安装脚本来掩盖问题。

仅修改 skill、任务说明或其他不进入应用产物的文档时，不重建、不重装、不运行无关 Flutter 检查。
使用 skill-creator 的 `scripts/quick_validate.py` 检查改动 skill，另查 YAML metadata、链接、作用范围和差异空白；
结构校验不等于证明未来所有实际任务的执行效果。
