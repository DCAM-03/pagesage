# Windows / Android GitHub 自动构建

## 范围与验证计划

用户要求补齐现有 Linux 之外的 GitHub CI/CD。保留此前的平台修复和测试。
实现阶段仅本地验证；用户随后报告已配置四项 Secrets，并授权提交推送到 `main`，
明确本轮不创建版本标签或 Release。正式签名配置的可用性由首次云端构建确认。

- Windows：固定 Flutter、严格恢复两个项目的依赖、分析、默认组件回归、release 构建、
  无窗口原生通道测试、完整 ZIP 与 SHA-256。
- Android：JDK 21、SDK 37.0、API 36 无窗口模拟器集成测试，之后重新生成普通应用的
  release APK；配置签名后同时生成 AAB。PR 不读取签名密钥，标签发布要求正式签名。
- 共享草稿 Release：标签与 pubspec 版本一致，下载后复核校验和；Windows/Android
  与原 Linux 发布 job 串行附加资产，允许重复运行，拒绝修改已公开的 Release。
- 证明方式：actionlint、PowerShell/Bash 语法检查、打包工具的真实归档及反例测试、
  草稿发布工具的替身行为测试、命名 Flutter 回归；签名配置另做真实临时 keystore 构建验证。
  日志写入本机忽略文件。云端 runner 只有在推送后实际运行才能标记通过。

## 使用

入口为 `.github/workflows/windows-android.yml`，`main` push、PR、手动运行和 `v*`
标签均触发；固定 Flutter 3.44.2 官方 tag / revision，Actions 引用固定提交。
测试/构建 job 只有读取仓库权限，草稿发布 job 才取得 `contents: write`。

普通分支 / PR：

- Windows 上传 `pagesage-VERSION-windows-x86_64.zip` 与 `.sha256`，保留整个 bundle，
  不把 exe 单独分发，不启动窗口；运行默认组件回归及 3 项原生 CTest。
  runner 不保证安装 OCR 语言包，明确不运行 `windows_ocr`，本机的真实 OCR 验收证据另见平台对接记录。
  当前 ZIP 未做 Authenticode 签名，目标机器须具有 Microsoft Visual C++ 2015–2022 x64 Runtime。
- 未配置 Android 签名时，上传 `pagesage-VERSION-android-test.apk` 与校验和；
  这是 debug 证书签名的 release 模式测试应用，不生成商店 AAB、不上传 Release。
- Android 先在独立 API 36 x86_64 无窗口模拟器运行 5 项集成场景，然后重新构建普通 APK，
  避免误交付 integration_test 包。失败时上传模拟器日志；Windows 失败时保留原生 CTest 日志。
- artifact 保留 14 天；不新增自动更新或应用商店上传。

正式 Android 签名需在仓库 Settings → Secrets and variables → Actions 配置：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 正式 keystore 的单行 Base64，不换行 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 签名 alias |
| `ANDROID_KEY_PASSWORD` | alias 密码 |

签名只在可信 push / 手动运行使用，PR 不读取；全部配置后产物为
`pagesage-VERSION-android.apk`、`pagesage-VERSION-android.aab` 及校验和。
部分配置缺失会失败，`v*` 标签缺少全部签名配置也会失败，不降级使用 debug 证书发布。
临时 keystore 只写入 runner 临时目录，`always()` 步骤删除，不放 artifact。
Gradle 使用 `PAGESAGE_ANDROID_KEYSTORE_PATH`、`PAGESAGE_ANDROID_STORE_PASSWORD`、
`PAGESAGE_ANDROID_KEY_ALIAS`、`PAGESAGE_ANDROID_KEY_PASSWORD` 环境变量；
`PAGESAGE_REQUIRE_RELEASE_SIGNING=true` 可在本地强制拒绝未签名发布配置。
不自动生成项目正式密钥或修改仓库 Secrets。

标签必须匹配 `pubspec.yaml` 的 `vVERSION` 或含 build number 的 `vVERSION+BUILD`。
各工作流在自己的构建与门禁通过后，将对应资产附加到同一个草稿 Release；
发布 job 使用共享 tag concurrency 串行执行，允许重跑覆盖同名资产，拒绝修改已公开 Release。
预发布版本附带 prerelease 标记，最终公开发布由维护者操作。

本地复验入口：

```powershell
python -m unittest discover -s test/tool -p '*_test.py' -v
python tool/package_platform.py windows
python tool/package_platform.py android
python tool/package_platform.py verify
flutter test --no-pub --concurrency=4 --reporter expanded
```

Python 脚本仅使用标准库。Windows 替身发布测试使用 Git for Windows 附带的 Git Bash，
不会调用真实 GitHub API；Linux 使用系统 Bash。

## 验证结果

- Windows 首轮全量回归 1099 PASS / 23 SKIP / 2 FAIL，发现 POSIX mode 位断言
  和目录书 widget 的绝对路径字符串断言不适用于 Windows。前者保留其他平台的权限验证，
  后者比较规范化文件 URI；不跳过业务场景、不修改 Linux 生产实现。
  修复后重跑同组为 **1101 PASS / 23 SKIP / 0 FAIL**、退出码 0，
  日志 `windows-ci-full-final.log`。跳过包括 Linux 专用分发及显式外部环境场景，
  不当作这些平台/环境实测通过。
- Python 行为测试 **13 PASS**，日志 `platform-packaging-tests.log`：完整 ZIP、
  中文空格路径、缺插件/ABI/离线模型拒绝、篡改和空校验和拒绝、正式与测试产物区分、
  草稿复用/创建、已公开 Release 保护、缺资产和上传失败。发布测试只使用替身 `gh`，未访问真实 Release。
- actionlint 1.7.12 + ShellCheck 0.11.0 检查两个工作流和发布 Bash 通过；
  composite action YAML、内嵌 PowerShell 解析通过；直接运行 composite 的版本 guard，
  验证两种正确标签接受、错误版本拒绝。
- 对本机真实 Windows bundle 和普通 Android APK 打包成功，ZIP / APK 内资源与
  SHA-256 复核通过，验证产物放在忽略目录 `.codex-run/ci-packages/`。
  Windows ZIP 约 26.6 MB，包含完整 DLL / data / 字体树，排除 PDB。
  检查发现测试输出目录会留下包含主机绝对路径的 `native_assets.json`，
  Windows CMake 安装规则已排除这份测试清单，保留实际 DLL；打包工具发现清单混入时拒绝归档。
  随后 Windows release 重建成功（`windows-ci-release.log`），按 CI 的命令执行原生 CTest
  **3 PASS / 0 FAIL**（`windows-ci-native-tests.log`），最终 bundle 未包含该清单、归档校验通过。
- 真实 Gradle 验证：要求签名但缺 key、只配置 alias 都明确失败，日志分别为
  `android-ci-signing-required.log`、`android-ci-signing-partial.log`。
  使用两天有效期的合成测试 JKS 构建 release APK / AAB 成功，日志
  `android-ci-signed-apk.log`、`android-ci-signed-aab.log`；
  `apksigner` 确认 APK 使用合成测试证书，`jarsigner` 确认 AAB `jar verified.`，
  日志 `android-ci-apk-certificate.log`、`android-ci-aab-signature.log`。
  正式命名的归档/校验和路径也已实测，但这些合成签名产物不是正式发布包。
  测试 keystore 已删除，普通本地 APK 已重建恢复默认测试签名，日志 `android-ci-default-apk.log`。
- 最终 `flutter analyze --no-pub` 无问题，日志 `windows-android-ci-analyze.log`；
  变更 Dart 文件格式和差异空白检查通过。
- 实现阶段未推送、未创建标签/Release，也未配置正式 Secrets。用户随后已报告配置 Secrets，
  授权提交推送到 `main`，本轮只触发分支构建，两个草稿发布 job 均因非标签引用而跳过。
  GitHub 托管 Windows Server 和 Ubuntu Android 模拟器的执行结果需另行核对，本机通过不替代云端结果。
  Android 5 项原生集成和 Windows 4 项原生通道的前次本机证据见
  [平台对接记录](android-windows-alignment-2026-11-12.md)；本轮未修改识别/阅读行为，不重复计数。

## 首次云端执行与 Android 磁盘修复

- `47fee17` 的 Windows job 成功并上传 ZIP；用户提供的运行截图与 Android 日志显示，
  Android 在模拟器启动时失败，还没有运行集成测试或正式签名步骤。
- Emulator 37.2.13 为 API 36 AVD 创建默认 userdata 分区，要求 7372.80 MB，
  `/home/runner/.android/avd/pagesage-ci.avd` 所在磁盘仅剩 4635.20 MB，
  直接报 `FATAL | Not enough space to create userdata partition`。
  setup-java 的 Node / v4 弃用提示不是这次退出码 1 的原因，现有 Secrets 尚未得到云端签名验证。
- 修复仅涉及 CI：安装前释放 Ubuntu runner 的预装 .NET 和非目标版本 Android NDK；
  SDK 安装后要求至少 12 GiB 可用空间，同时容纳约 7.4 GB 的 userdata 启动检查和
  后续 Gradle / 产物余量，日志打印磁盘容量。
  加 `-no-metrics` 避免模拟器未来出现交互式遥测确认；不更改用户本机工具或数据目录。
- 实测验证了不能单纯依赖缩小分区：本机 Emulator 36.1.9 的 `-partition-size` 上限为
  2047 MB；独立 API 36 Google Play AVD 以该参数无窗口启动成功，但 `hardware-qemu.ini`
  仍记录 6 GB data 分区，设备 `/data` 为 5.8 GB。因此最终修复采用释放空间和容量门禁，
  不保留无效的分区缩小参数。探针只复制 AVD 配置，不复制用户数据；测试后已关闭，
  日志位于 `.codex-run/android-disk-probe/`。本机镜像不同于云端 google_apis，
  不将此项当作云端镜像、磁盘或完整构建通过。
- Actions / ShellCheck 检查通过，日志 `android-ci-disk-actionlint.log`；直接执行工作流中
  实际容量门禁，原始失败容量及 12 GiB 以下容量被拒绝，12 GiB 和 16 GiB 被接受，
  日志 `android-ci-disk-capacity.log`。未在本机执行 runner 专用工具清理。
  修复推送后需核对新的 Android job；当前主机无法读取该私有仓库的 Actions API，
  原始云端失败结论来自用户截图及复制的失败日志。应用源码未变，不重复完整 Flutter 回归。
