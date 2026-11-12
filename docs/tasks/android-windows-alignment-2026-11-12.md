# Android / Windows 与 Linux 功能对齐

用户授权：先完成本轮代码审查、OCR 工具条与主题，再按 Linux 功能适配；
用户换设备后集中验证。这里区分已修改的代码与尚未完成的设备验收。

## Windows 主机续验（2026-11-12）

本次用户要求对接测试 Android 和 Windows。工作树起始无未提交改动，
运行环境为 Windows、Flutter 3.44.2 / Dart 3.12.2、VS 2022、Android SDK 36。

验证计划：

- 先使用 `flutter pub get --enforce-lockfile` 恢复锁定依赖，再执行 Windows release
  与 Android debug 原生编译；日志放在仓库根目录的忽略文件 `*-build.log`。
- 定向覆盖 `test/core/platform/`、`test/core/ocr/method_channel_ocr_engine_test.dart`、
  `test/features/import/import_use_case_test.dart`、`test/features/export/export_service_test.dart`、
  `test/features/settings/settings_export_test.dart`、`test/features/reader/reader_providers_test.dart`，
  验证选择/取消、content URI、导入副本、导出与进度持久化；发现失败后补充精确反例。
- 检查原生 PDF/OCR、插件注册、Windows 中文空格路径，以及 Android 生命周期和系统返回。
  用户要求只做静默构建和离屏测试，不启动 Windows 可见窗口；Android 使用独立数据目录的
  API 36 x86_64 无窗口模拟器（`emulator-5580`），不连接用户原有模拟器数据或书库。
- 初始环境缺口：镜像源与锁文件的 pub.dev 源不一致，严格解析失败；只在当前命令设置
  `PUB_HOSTED_URL=https://pub.dev` 后恢复成功，锁文件保持不变。
  用户授权补装 SDK 并接受许可证；已安装 `platforms;android-37.0`，接受缺少的许可证。
  Android Studio 自带 JDK 25 与现有 Gradle 8.13 不兼容，使用命令级
  `GRADLE_OPTS=-Dorg.gradle.java.home=C:/Software/Java/jdk-21.0.1` 选择已有 JDK 21，
  不改全局 Flutter/Java 配置。
- 若发生应用改动，执行 Linux 安装命令并如实记录当前 WSL 是否具备 Linux Flutter/GTK
  构建环境；Windows 构建或组件测试不能替代 Linux 安装、Android 真机或原生选择器验收。

已定位的修复与新增验证入口：

- Android 实际 Kotlin 编译发现 `lineText.isEmpty` 误写为属性；改为 `isEmpty()`，
  debug APK 编译通过。仅 Dart/mock 测试无法发现该问题。
- Windows 备份恢复组件用例中，恢复后的 AI 设置流还在执行凭证锁文件 I/O，测试就开始
  删除临时目录。增加有界等待并断言设置加载成功，保留原恢复和数据断言；单例复验通过。
- Markdown 目录会话测试原来把绝对文件路径写死为 `/` 分隔；改为核对平台路径的精确值，
  locator 内的 `sub/b.md` 保持平台无关，不修改领域定位契约。
- 阅读器离屏截图优先加载当前平台中文字体，缺失时回退到已打包字体。
- `test/native/CMakeLists.txt` 提供无窗口 CTest 入口；
  `windows_native_channels_test.cpp` 直接调用生产 handler 和 WinRT worker，
  仅替换结果接收器。真实 PDF 栅格化、OCR、中文空格路径、像素预算、错误页码、
  缺失语言包均有行为断言，CTest 还要求最终 PASS 标记，避免提前退出被误判通过。
  本机识别语言为 `en-US`、`zh-Hans-CN`。
- `integration_test/android_platform_test.dart` 提供独立 Android 目标测试，验证
  原生 PDF/ML Kit、系统安全存储、SQLite FTS5 文件重开、导出无效源文件与阅读进度恢复。
  样本临时生成，不上传正文、不调用 AI、不使用真实密钥。

复验命令（CMake/CTest 在 Visual Studio 开发环境执行）：

```powershell
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:GRADLE_OPTS = '-Dorg.gradle.java.home=C:/Software/Java/jdk-21.0.1'
flutter pub get --enforce-lockfile
flutter build windows --release
cmake -S test/native -B build/native-tests -A x64
cmake --build build/native-tests --config Release --parallel 4
ctest --test-dir build/native-tests -C Release --output-on-failure
flutter test integration_test/android_platform_test.dart -d emulator-5580 --reporter expanded
flutter build apk --release
```

`emulator-5580` 必须先连接到独立测试模拟器。不要对用户常用模拟器安装测试包；
不要把上面的 Android 集成用例改为 Windows 目标运行。本轮只允许无窗口验证。

### 续验结果

| 检查 | 实际结果与证据（日志为本机忽略文件） |
| --- | --- |
| Windows release | 构建成功；`windows-build.log`；`build/windows/x64/runner/Release/` 包含 exe、Flutter engine、SQLite 和插件 DLL，分发必须保留整个目录 |
| Windows 原生无窗口 | CTest 4 PASS / 0 FAIL；`native-tests.log` 与 `build/native-tests/Testing/Temporary/LastTest.log`；真实 WinRT PDF 栅格化、英文 OCR、语言能力及错误分支通过 |
| Android 构建 | debug 和 release 均成功；最终普通应用 release 为 `build/app/outputs/flutter-apk/app-release.apk`（125710425 bytes），日志 `android-release-final.log`；沿用现有 debug 签名，仅用于本地测试 |
| Android 无窗口集成 | API 36 x86_64，5 PASS / 0 FAIL，退出码 0；`android-integration-final.log`；测试结束已关闭专用模拟器 |
| Windows 主机定向组件回归 | 561 PASS / 0 FAIL，退出码 0；`platform-regression-final.log`；覆盖平台服务、导入、导出/恢复、阅读 provider、三类 renderer、目录会话、主题和阅读设置 |
| 离屏布局与交互 | 25 PASS / 0 FAIL，退出码 0；`windows-captures-final.log`；与上组重叠，不合并计数 |
| 静态检查 | 最终 `flutter analyze --no-pub` 无问题，`platform-analyze-final.log`；4 个变更 Dart 文件 format 校验和 `git diff --check` 通过 |

Android release APK 已核对 arm64-v8a、armeabi-v7a、x86_64 的 `libapp`、
`libflutter`、`libsqlite3`，包含离线 ML Kit 模型及打包字体。
当前 debug APK 是集成测试构建，不作为普通应用产物交付。

离屏检查使用 `--dart-define=CAPTURE_READER_WORKBENCH=true`，执行
`test/features/reader/reader_chrome_test.dart` 和
`test/features/settings/reader_settings_test.dart`，并发 4。
截图位于 `build/workbench-captures/`；已目检 1440px / 200% 工具条和设置页、
窄 PDF 工具条、深色 OCR 菜单、390px / 200% 设置与字体控件、
360px / 150% 和 420px / 200% 底部设置。未见横向溢出或控件叠盖，长面板可滚动。
长自定义字体名称样例显式绑定测试中文字体，验证布局，不证明该自定义字体在系统中可用。

验证边界：

- Android 真实原生调用验证了英文样本的 PDF 和图像 OCR、归一化坐标、
  预算、异常请求后的继续处理；安全存储使用独立合成 key 写/读/删；SQLite FTS5 使用临时文件关闭重开。
- Android 阅读器触摸翻页后保存至第 2 页，关闭并重新挂载恢复第 2 页。
  阅读 harness 使用内存数据库，此项不等于进程重启后恢复；文件持久化另由 FTS 用例证明。
- Windows 原生测试直接调用生产 handler，未验证 Flutter messenger 与真实窗口的整条接线；
  本机可用语言为 `en-US`、`zh-Hans-CN`，本次只验证英文内容识别。
- 按用户要求未启动 Windows 可见窗口。系统选择器的人工选择/取消/覆盖、
  EPUB/Markdown 在 Android 上的完整阅读闭环、Android 真机及旋转/前后台/进程终止、
  Windows 原生安全存储和真实键盘/DPI 行为仍未验收。
- 已执行 `bash tool/install_linux.sh`，日志 `linux-install.log`：WSL 调用 Windows Flutter 时
  因 CRLF（`shared.sh: line 5: $'\\r': command not found`）失败，当前 WSL 也缺 Linux Flutter/GTK 环境。
  本次没有更新 Linux 安装；生产改动仅 Android Kotlin，不用 Windows 构建替代 Linux 安装证据。

首轮扩展回归为 560 PASS / 1 FAIL（路径分隔符断言），修复后重跑同组得到上述 561 PASS。
备份恢复的真实文件清理时序失败也已修复并包含于最终回归；不以单例通过替代整组结论。

## Linux 主机前次实现（历史记录）

### 共享 Flutter

- OCR 主入口合并为「识别文字 + 下拉」，菜单提供范围和整本；菜单打开期间不自动收起。
- 阅读主题覆盖书页、目录、工具条、底栏、菜单、对话框和选区 overlay；
  不修改书库/设置页的应用主题偏好。Android 系统栏图标亮度跟随当前主题。
- 平台导出成功、取消、写入失败与任务中心终态一致，finally 释放任务取消注册。

### Android

- 应用 Kotlin 插件，源文件路径与 `dev.pagesage.app` package/namespace 对齐。
- 生成导出文件后调用系统文档创建界面，原生流式复制到 content URI；
  不把 content URI 当作 `dart:io File` 路径，也不先用空 bytes 清空目标。
- 图片批注将 Markdown 和相对路径资源打为 ZIP，保持解压后的链接完整。
  其他文本和数据库备份保留原格式；取消保存不显示成功。
- 不展示不支持的「打开所在目录」。关闭 Android 系统自动备份，保持本地优先和手动备份路径。
- PDF raster 使用 ARGB_8888，尊重像素预算，解码图片先检查尺寸并下采样。
  OCR 客户端和 PDF 资源在同一工作队列末尾关闭，避免识别中被销毁。
- 语言列表只报告实际打包的中文/拉丁脚本，不再宣称包含日文、韩文模型。
- 系统文档 picker 返回失败、用户取消和 activity 销毁分别回传；文件复制不占 UI 线程。

### Windows

- 继续使用桌面原生保存路径选择，不在选路径时写空文件。
- WinRT OCR 枚举实际安装的识别语言；请求缺失语言明确提示安装，不静默改用其他语言。
- PDF 与显示图 OCR 都限制像素和引擎最大边长；输出坐标仍按实际识别图归一化。
- 修复原生 channel 空参数先解引用的崩溃分支；共享 OCR 引擎识别串行执行。
- PDF 尺寸预算函数拆为独立无 WinRT 依赖的头文件，在 Linux 编译运行边界测试。

## Linux 主机前次验证证据（历史记录）

- `/tmp/pagesage-review-regression.log`：433 PASS / 1 SKIP，含 Android 导出完成/取消/
  写失败的设置页测试、native OCR 通道模型、图片 ZIP、原有桌面导出与恢复。
- `/tmp/pagesage-review-final-platform-renderer.log`：187 PASS；覆盖最终平台路径、
  OCR 编排、PDF/Markdown/EPUB 受影响渲染，以及阅读主题与系统栏对比度测试。
  与前组有重叠，不相加为去重总数。
- `g++ -std=c++17 test/native/pdf_render_budget_test.cpp` 编译并运行通过：
  常规 A4 比例、边长/总像素限制、极端长宽比、非法预算与无穷尺寸。
- `flutter doctor -v` 确认本机没有 Android SDK；
  实际 `flutter build apk --debug` 失败于 SDK 缺失（不是 Kotlin 编译通过），
  `flutter build windows --release` 失败于非 Windows 主机。
  日志分别为 `/tmp/pagesage-review-android-build.log`、`/tmp/pagesage-review-windows-build.log`。
- 未修改本机 SDK/签名/系统配置，未生成 APK、AAB 或 Windows exe。
  Android/Kotlin 与 Windows/WinRT 编译、真实原生选择器和设备行为待验证；
  Dart/mock channel 测试不替代这些检查。
- 最终离屏布局补测 5 PASS，日志 `/tmp/pagesage-review-captures-final.log`；
  `/tmp/pagesage-review-analyze-final.log` 静态分析无问题。C++ 预算测试最终重跑通过。
- 共享代码已随 Linux release 静默重建安装，完整 bundle 比对无差异；
  安装日志与哈希见 [本轮审查记录](code-review-2026-11-12.md)。
  未启动新窗口，Linux 构建成功不代表 Android/Windows 原生构建通过。

## 人工验收场景清单（按上方续验结果核对剩余项）

| 场景 | Android | Windows |
| --- | --- | --- |
| 构建与启动 | 安装 debug APK，正常启动/恢复后台 | `flutter build windows --release`，启动 runner |
| 导入与阅读 | 系统选择 EPUB/PDF/MD，保存进度后重开 | 选择/拖入文件，目录阅读、重开 |
| 主题 | 夜间/纸张目录、底栏、设置面板及系统栏 | 夜间/纸张目录、菜单和阅读工具；系统标题栏另看 OS |
| OCR | 中文/英文当前页、范围、整本，队列暂停恢复，旋转页划词 | 安装/未安装语言包分别测试，当前页/范围/整本，坐标划词 |
| OCR 生命周期 | 识别时旋转/切后台/退出，恢复后任务状态 | 识别时切书/关闭，重开后任务恢复 |
| 导出 | 下载目录/文档 provider，取消、同名覆盖、磁盘失败；ZIP 图片可打开 | 空格中文路径、同名覆盖、取消、Explorer 定位 |
| 备份恢复 | 新笔记/批注/进度恢复可用，API key 需重新输入 | 同左；恢复后完全重开 |
| 交互 | 390px 宽、大字号、键盘弹出/返回手势 | 100%/150%/200% 缩放，键盘 Tab/ESC，窗口窄化 |

Android 仍使用已有 ML Kit；Windows 仍使用 WinRT，不将 Linux Tesseract 的依赖打包到其他平台。
原生 OCR 不支持中途打断正在执行的一页，队列取消在页边界生效；本轮未改成强杀 worker。
