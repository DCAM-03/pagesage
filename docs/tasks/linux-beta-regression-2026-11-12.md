# Linux beta 候选全仓回归与分发路径核对

## 范围

按用户要求，对当前最终工作树执行完整自动回归，并核对通过 GitHub 构建 Linux
分发包的可行路径。本轮使用 validation-harness，不修改应用功能，不创建远程仓库、
提交、推送或发布 Release。

待证明行为：最近的阅读设置、AI 配置恢复及交互修改与现有全部默认测试兼容，
且静态分析没有问题。默认测试跳过项单列，不将自动回归等同于人工窗口验收。

## 候选与运行环境

- 日期：2026-11-12。
- 环境：Linux，Flutter 3.44.2，Dart 3.12.2。
- 候选：当前工作树，包括此前未提交和新增的实现及测试；基准 HEAD 为
  `3dbbec36b867d8c76fad398e8ed12cc1ad7cc198`，不能只按该提交重现本轮代码。
- 命令在现有工具会话中运行，完整输出写入 `/tmp`，未打开终端或应用窗口。
- 测试开始前已明确全仓范围、并发 4、最终失败数为零的预期信号及以下日志位置。

## 实际结果

| 检查 | 命令 | 结果 | 证据 |
| --- | --- | --- | --- |
| 全仓默认测试 | `flutter test --concurrency=4 --reporter expanded` | 1101 PASS / 7 SKIP / 0 FAIL，退出码 0，约 72 秒 | `/tmp/pagesage-beta-full-2026-11-12.log` |
| 静态分析 | `flutter analyze` | No issues found，退出码 0 | `/tmp/pagesage-beta-analyze-2026-11-12.log` |

测试日志含 Drift 多实例调试警告，包括故意创建第二个连接验证凭证互斥的场景；
本轮保留原始输出，没有通过关闭警告改变回归结果。

### 跳过的 7 项

| 数量 | 范围 | 原因 |
| --- | --- | --- |
| 1 | 搜索规模 benchmark | 未显式设置 `PAGESAGE_SEARCH_BENCHMARK=true` |
| 3 | 真实 Tesseract smoke | 未提供 `PAGESAGE_OCR_SMOKE_IMAGE` 等外部样本变量 |
| 1 | Linux PDF 光栅化和 OCR 集成性能测量 | 未提供 `PAGESAGE_OCR_PIPELINE_PDF` |
| 2 | Android debug APK / release AAB 资源检查 | 本地缺少对应构建产物 |

### 平台产物边界

资源检查还读到了已有 Windows Debug/Release 资源目录与 Android release APK。
Android APK 修改时间为 2026-07-17，Windows 目录修改时间分别为 2026-09-22
和 2026-07-17。这些通过结果仅代表已有产物的资源检查，不能证明当前
Android/Kotlin 或 Windows/WinRT 代码编译成功。

本轮没有运行桌面 `integration_test`、人工操作已安装 release、调用真实模型，
也没有重做 OCR 质量或性能评测。默认全仓回归已通过；其余验收边界保留。

应用、依赖与运行配置未修改，因此不重复构建安装，也不操作已有应用进程。

## GitHub Linux 分发路径

可以由 GitHub Actions 在 Linux runner 构建，并将结果上传为 workflow artifact，
再按版本标签附加到 GitHub Release。当前工作树没有 `.github/workflows/`，
`git remote -v` 为空；本轮仅核对方案，没有宣称云端构建已接入或执行。

建议分两层：

1. 每次代码变更执行静态分析和默认全仓回归，手动运行可生成候选包。
2. 发布标签触发 release 构建，将完整 Flutter bundle 打成 Linux x86_64
   `tar.gz`，附校验和、运行依赖说明和版本记录；后续按需要增加 AppImage。

不能只复制 `pagesage` 可执行文件，需要包含 Flutter bundle 的 `lib/` 与 `data/`。
工作流与安装包解决不同问题：CI 负责编译和保存产物，打包脚本决定产物的安装、
桌面入口、依赖和运行时兼容策略。

接入前已确认的项目事项：

- `pubspec.yaml` 的 SQLite 配置写死 `/usr/lib64/libsqlite3.so.0`，
  不能原样假定 GitHub Ubuntu runner 或其他发行版存在相同路径；
  需统一系统库名称解析或明确随包方案，并分别验证构建和目标机加载。
- `tool/install_linux.sh` 面向本机重建和安装，不是现成的可分发打包入口。
- 固定可验证的 Flutter SDK 与 runner 环境，准备 GTK、编译工具及插件所需开发库；
  分发包还需在声明支持的干净目标环境启动验证。
- OCR 继续区分外部 Tesseract/语言数据依赖与基本阅读功能，不能把开发机已有模型
  当成分发包自带模型。
- CI 首次运行仍需实际证明；本轮本地回归不是 GitHub 构建通过的证据。
