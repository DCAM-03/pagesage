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
Windows 附件任务因此仅依赖 Windows，Android 继续原有构建并保留 Actions 附件，
不自动改动已经发布的 Release。本次 Release 不包含 Android APK/AAB。

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
