# Linux 自动构建与分发包

## 目标与范围

用户要求在 `DCAM-03` 个人账号下创建私有 `pagesage` 仓库，并编写自动构建和打包脚本。
本轮按 pagesage-dart-engineering、validation-harness 和 project-coordination 实施。

交付 Linux x86_64 `tar.gz`、校验和、独立用户级安装脚本及 GitHub Actions。
版本标签生成草稿 Release，不自动公开发布；暂不增加 AppImage、deb、自动更新，
不把本轮 Linux 构建当作 Windows/Android 原生验收。

## 基线与决策

- 当前完整回归已有 1101 PASS / 7 SKIP 的记录。本轮修改构建配置后需重新验证，
  不沿用旧结果冒充新配置通过。
- 仓库尚无 remote 或 `.github/workflows/`。
- GitHub CLI 目前登录 `WcjKaos`；指定新 SSH key 已实测识别 `DCAM-03`。
  SSH 推送身份不等于 GitHub API 登录身份，创建个人私有仓库需对应账号的 API 授权。
- Flutter 3.44.2 对应官方提交
  `c9a6c484230f8b5e408ec57be1ef71dee1e77020`，与本机 SDK 一致。
- Linux SQLite hook 原来写死 Fedora 路径；改用当前锁定 sqlite3 依赖的默认随包
  native asset，构建时下载并核对依赖内置 SHA-256，运行时不依赖系统 SQLite 路径。
  不新增依赖；保留外部 Tesseract 与语言模型，不静默下载模型或打包开发机私有文件。
- 分发包保留完整 Flutter bundle，独立安装器不依赖源码或本机 Flutter SDK。

## 实施与验证计划

| 路径 | 待证明行为 | 验证 |
| --- | --- | --- |
| 打包脚本 | 完整资源、版本与校验和，拒绝缺失 bundle 和非法版本 | `test/tool/linux_distribution_test.dart`，真实 bundle 打包 |
| 分发安装器 | 中文/空格路径可安装、升级保留应用数据，失败可恢复原 bundle | 临时 HOME/XDG 目录内运行，无应用窗口 |
| 分发启动器 | 从任意工作目录启动，包内库路径和参数正确传递 | 仅执行测试替身，不启动真实应用 |
| SQLite hook | 随包 native asset 加载可用，FTS 和迁移保持正常 | 默认全仓回归、release 构建与本地安装 |
| GitHub Actions | 固定 SDK、分析和测试先于构建，产物与草稿发布权限分离 | actionlint、ShellCheck；云端执行须实际创建仓库并上传源码后验证 |

日志使用 `/tmp/pagesage-distribution-*.log`。测试和构建在现有会话静默运行；
应用配置变化后静默重建安装，比较原始 release bundle 与本地安装目录。

## 结果

### 仓库与自动构建

- 已创建 `https://github.com/DCAM-03/pagesage`，API 核验 `isPrivate=true`。
  当前 GitHub CLI 身份为 `DCAM-03`；本地 `origin` 指向该仓库的 SSH 地址，
  仅在当前仓库配置指定 SSH key，`git ls-remote origin` 成功。
- 工作流已完成：固定 Flutter 官方提交、Ubuntu 22.04 x86_64 runner，
  锁文件解析、脚本检查、静态分析和全仓测试先于 release 构建；
  上传压缩包与校验和，匹配版本的 `v*` 标签另生成草稿 Release。
  发布权限仅授予草稿发布 job。
- 随后按用户要求完成提交推送，首次 GitHub Actions 运行的故障及修复见末节。
  Ubuntu runner 完整构建和下载后的干净机器运行分别验收；
  当前 Fedora 构建不能替代跨发行版兼容验收。

### 自动验证与真实分发包

- 最终默认全仓回归 `flutter test --no-pub --concurrency=4 --reporter expanded`：
  **1117 PASS / 7 SKIP / 0 FAIL**，退出码 0，日志
  `/tmp/pagesage-distribution-full-final.log`。其中包含分发脚本的 16 项测试；
  跳过项沿用显式环境条件，不计作平台或 OCR 实测通过。
- 最终 `flutter analyze --no-pub` 无问题；新增测试格式检查、5 个 shell
  脚本的语法及 ShellCheck、actionlint 1.7.12、`git diff --check` 均通过。
  ShellCheck 发现本机安装脚本的变量模式缺少内层引号，已作局部修正。
- 全包比对发现 Flutter 测试会在共享 native asset 输出目录留下带开发机绝对路径的
  `native_assets.json`，增量 release 安装会将其混入 bundle。CMake 安装规则已排除
  该测试清单，保留实际 `.so`；新增用真实 CMake 配置和安装执行该规则的回归测试。
  AOT 使用的 release 清单仍仅包含库文件名，不改写 Flutter 生成的运行契约。
- `bash tool/build_linux_release.sh` 真实构建并打包成功，日志
  `/tmp/pagesage-distribution-build-package.log`。安装器最终修正后已重新打包：
  `dist/pagesage-0.1.0+1-linux-x86_64.tar.gz`，24,226,218 bytes，
  附带 `.tar.gz.sha256`；打包日志 `/tmp/pagesage-distribution-package-final.log`。
- 真实压缩包通过 SHA-256 校验；解压后两个脚本与最终源码逐字节一致。
  在中文和空格路径的临时 HOME/XDG 下安装成功，完整包与临时安装目录一致，
  desktop entry 通过 `desktop-file-validate`。随包 SQLite 3.53.4 可加载，
  FTS5 编译选项开启；可执行文件和全部包内 `.so` 在当前主机无缺失动态依赖。
  日志 `/tmp/pagesage-distribution-package-verification.log`。

### 本地更新与证据边界

- 已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，
  完整 release bundle 与 `<HOME>/.local/opt/pagesage` 比对无差异；
  日志 `/tmp/pagesage-distribution-install.log`。
- `libapp.so` SHA-256：
  `edd1a13b90653c20fbc88a3dedef8db278030e220bb4b5f70220b9bac64cf2de`；
  随包 `libsqlite3.so` SHA-256：
  `b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2`，
  构建与安装两侧一致。
- 未启动应用或终端窗口，未停止或重启已有 PageSage 进程。
  本轮证明构建、测试、分发安装与本机库加载，不新增真实阅读窗口或
  Windows/Android 验收结论。

## 首次云端构建故障与修复

- 后续按用户要求将当前工作树提交为 `e82a3a0` 并推送到 `main`，
  触发 Actions run `43160751128`。该次运行失败于依赖解析；
  分析、全仓测试、构建及上传均未执行，未生成 artifact。
- 原因：工作流只浅拉 Flutter 提交，没有取得 `3.44.2` 版本标签。
  Flutter 在干净 runner 上报告 `0.0.0-unknown`，
  不能满足 `path_provider_platform_interface` 要求的 Flutter `>=3.38.0`。
  失败日志 `/tmp/pagesage-github-linux-first-failure.log`。
- 修复：显式浅拉官方 `3.44.2` 标签，继续校验其提交与固定 SHA 一致；
  安装步骤额外检查 Git 标签及 `flutter --version --machine` 返回的版本和提交，
  在进入依赖解析之前拒绝未知或错误 SDK。不升级 Flutter，也不放宽依赖锁文件。
- 验证：先用临时 Git checkout 对照缺失标签与补齐标签的行为，再执行
  actionlint、脚本检查与工作流差异审查；推送修复后跟进云端完整构建与 artifact 校验。
  本轮仅调整 CI 与文档，不修改应用产物，不重复本地安装。
