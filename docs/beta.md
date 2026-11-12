# PageSage 公开测试版说明

更新：2026-11-12

PageSage 是本地优先的 EPUB、PDF、Markdown 阅读器，目前处于早期测试阶段。
公开源码与发布二进制是两件事：仓库可访问不代表已有正式稳定版。

版本说明见 [v0.0.1 Beta](releases/v0.0.1.md)；测试包统一从下方 Releases 入口获取。

## 测试范围

- Linux x86_64 已有候选包与本机安装验证，GitHub 在 Ubuntu 22.04 构建。
  其他发行版仍需验证运行库、桌面集成与系统安全存储。
- Windows x86_64 和 Android 已接入构建及部分无窗口/设备自动验证；
  文件选择器、实际窗口交互、设备生命周期等仍需逐平台验收。
- iOS、macOS 和 Web 不属于本次公开测试的分发目标。
- 具体构建结果看对应 CI；详细证据与未验证项看[实现记录](implementation-status.md)。

## 获取与升级

优先使用维护者公开发布的
[Release](https://github.com/DCAM-03/pagesage/releases)。
Actions 中成功运行的附件是开发构建，需登录 GitHub 下载，保留期通常为 14 天。
请核对附件对应的提交号与 SHA-256；不要混用不同版本的可执行文件和资源目录。
草稿 Release 不属于公开下载。

Linux 使用[安装指南](linux-distribution.md)。
Windows 需完整解压 ZIP，当前未提供 Authenticode 签名；
Android 名称带 `android-test` 的 APK 使用测试证书，不保证能覆盖不同证书的既有安装。
升级前先备份，签名不一致时不要为覆盖安装而直接卸载唯一的数据副本。

## 已知边界

- PDF 文本选择依赖文本层或 OCR 结果；扫描页、复杂公式、矩阵和多栏版式需要人工校对。
- Linux OCR 使用额外安装的 Tesseract 与语言数据；基础阅读不依赖 OCR。
- Markdown 文件树与单文件大纲分开，公式和图表只支持实现覆盖的语法，必要时显示源码。
- AI 的来源与回答需要核对，不能以检索命中代替答案准确性；使用自己的服务配置并确认上下文范围。
- 备份包含数据库与封面，不包含全部原书文件或 API key；详见[隐私说明](privacy.md)。

## 反馈与参与

请使用 [Issue 模板](https://github.com/DCAM-03/pagesage/issues/new/choose)，注明版本、
构建号、平台、复现步骤与脱敏截图。尽量提供自编的最小样本，不提交私人书籍、数据库、
访问凭证或未脱敏日志。安全漏洞按[安全说明](../SECURITY.md)私下报告。

源码与文档采用 [Apache-2.0](../LICENSE)，第三方组件遵循[各自许可](licenses.md)。
