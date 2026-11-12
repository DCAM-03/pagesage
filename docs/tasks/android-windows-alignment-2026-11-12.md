# Android / Windows 与 Linux 功能对齐

用户授权：先完成本轮代码审查、OCR 工具条与主题，再按 Linux 功能适配；
用户换设备后集中验证。这里区分已修改的代码与尚未完成的设备验收。

## 本轮实现

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

## 验证证据

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

## 换设备验收清单

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
