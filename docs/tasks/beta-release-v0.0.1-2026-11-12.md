# v0.0.1 Beta 发布

日期：2026-11-12

状态：已公开发布 Beta

## 目标与授权

按用户要求创建并公开发布 GitHub Beta Release，不止创建标签或草稿。
标签使用 `v0.0.1`，标题 `v0.0.1 Beta`，GitHub `prerelease` 为 true。
应用版本为 `0.0.1+2`，构建号递增，避免回退已有 Android 开发安装的版本编号。

## 实施与验证

1. 同步 `pubspec.yaml` 与应用关于页版本，以组件测试核对显示值。
2. 运行静态分析及设置页、许可、打包相关定向测试，静默更新本地 Linux 安装。
3. 提交推送候选并创建标签，使用既有 Actions 完成 Linux / Windows 全仓回归与构建。
4. 保持草稿状态，核对 Linux tar.gz、Windows ZIP
   及对应校验和均来自同一标签提交。
5. 下载 Release 附件复核 SHA-256 与许可，发布为预发布版本，
   再通过 API 核对公开状态、标签、附件和匿名下载。

证据保存在被忽略的 `.local-data/releases/v0.0.1/`。
只报告实际通过的验证；不把 Windows / Android CI 当作所有真实设备的完整验收。
已有同实现有效证据可复用；本次标签工作流承担最终全仓回归。

用户随后明确：仅等待 Linux 与 Windows，不等待较慢的 Android 构建。
Windows 附件任务因此仅依赖 Windows，首次公开时 Android 仅保留 Actions 附件，
未包含在 Release。用户随后要求补充 Android，并自动同步后续标签构建产物，结果见下文。

## 结果

发布候选为 `5569a8de6688cbcb149ddc1ba9d883987144ab8a`，带注释标签 `v0.0.1`
已推送且远端解析到同一提交。应用版本为 `0.0.1+2`。

本地验证：锁定依赖解析、格式化和静态分析通过；设置与发布定向测试 7 项通过、
2 项因缺少 Android 产物跳过。旧许可文案断言修复后单独回归通过。
Linux 静默构建安装成功，安装目录与构建 bundle 核对一致。

云端 Linux 标签运行 `43189826537`：全仓默认测试 1120 项通过、9 项跳过；
静态分析、构建、运行库依赖检查、包校验和与草稿附件上传均成功。
下载后的包已核对源码提交、干净工作区、版本、glibc 2.35、启动脚本执行位、
许可文档及 `NOTICES.Z` 中的完整项目和字体许可。

Windows 标签运行 `43189826332`：全仓默认测试 1103 项通过、26 项跳过；
静态分析、分发工具测试、Release 构建、3 项原生 PDF 测试、打包校验和及草稿附件上传均成功。
该运行中的 Android 任务不作为本次桌面发布门禁。下载后的 Windows ZIP 完整性、
必要运行库和可执行文件、许可文档及 `NOTICES.Z` 核对通过。

Linux 包 SHA-256：
`fa09c5b49b6a3ce311e3d812a8f7edbca8ee710ad9eff57b36af53c99be317e1`。

Windows 包 SHA-256：
`fc8178c500122f6ec826ec49f89cbfe61635e15ac7c5f7c9ccc99927d1073b9a`。

2026-11-12 17:25:15（Asia/Shanghai）公开发布
[v0.0.1 Beta](https://github.com/DCAM-03/pagesage/releases/tag/v0.0.1)。
GitHub 返回 `draft=false`、`prerelease=true`；包含两个桌面安装包及各自的
SHA-256 文件。匿名 API 可访问，四个附件匿名下载成功，安装包摘要与已核对产物一致；
结果保存在本地发布证据目录。

真实 Windows 设备的窗口交互与 OCR 语言包仍需设备验收；
CI 中 3 项原生 PDF 测试未包含依赖系统 OCR 语言包的用例。

## Android 补充与自动同步

成功运行 `43191457452` 的 Android job `131124197292`：
API 36 无窗口集成测试 5 项通过，正式签名 APK / AAB 构建、
APK 证书校验和 AAB 签名校验均成功。来源提交 `e1af894` 与 `v0.0.1`
仅存在发布记录文档差异，应用与构建代码一致，不移动已有标签。

已下载并核对两个安装包的 ZIP 完整性、SHA-256、三种 ABI 原生库、
离线 OCR 模型、字体及完整许可；APK 二进制 Manifest 确认为
`dev.pagesage.app`、`versionName=0.0.1`、`versionCode=2`。
本地 `jarsigner -verify` 复验 AAB 返回 `jar verified.`。

- APK：`pagesage-0.0.1+2-android.apk`，125729353 bytes，
  SHA-256 `750a3360302f6216efcefb421543acb19275da0a85c7601583d5ffa79f5702f5`。
- AAB：`pagesage-0.0.1+2-android.aab`，105444235 bytes，
  SHA-256 `b8ba2654cc2298501b55d2c4dc7e9fcf425e72b0ea924004ccf9a8fb1b53e78a`。

两个 Android 包及各自的校验和已同步至现有公开 Beta，
原有 Linux / Windows 附件的 ID 和摘要保持不变；
Release 仍为公开预发布版本，共 8 个附件。发布说明已补齐 Android 下载用途和来源；
四个新增附件匿名下载通过，下载摘要与本地验证产物一致。

后续 Linux、Windows、Android 的标签构建及重跑分别同步到同标签 Release，
允许给已公开版本追加附件，并保留已有公开 / 预发布状态。
不存在 Release 时仍创建草稿；普通 `main` / PR 不改旧版本。
平台同步组互相独立，脚本处理并发首次创建，不因三个平台同时完成而取消待上传平台。
工具行为测试 28 项通过，ShellCheck、actionlint 和工作流依赖 / 权限 / 产物来源检查通过。
本次变更仅涉及 CI、发布工具、测试和说明，不改变已安装应用。
