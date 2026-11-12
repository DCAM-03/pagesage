# 参与 PageSage

欢迎提交可复现的问题、文档改进和聚焦具体问题的 Pull Request。
PageSage 目前处于早期测试阶段，当前支持范围见 [README](README.md)，
实现与验证状态见[实现记录](docs/implementation-status.md)。

## 开始之前

- 功能建议请说明阅读场景和实际困难；较大的改动先用 Issue 对齐范围。
- Bug 请附版本、操作系统、复现步骤、预期与实际结果，尽量使用自编的最小样本。
- 安全漏洞请按照 [SECURITY.md](SECURITY.md) 私下报告，不在公开 Issue 上传凭证或个人资料。
- 请勿提交私人书籍、数据库、真实 API key、签名材料、未脱敏日志或无权再分发的样本。

## 开发环境

使用 CI 固定的 Flutter 3.44.2，Dart 约束见 `pubspec.yaml`。
安装与平台构建步骤见 [README 开发指南](README.md#开发指南)。
主项目和 `poc_pdf_canvas` 的锁文件都需要保留：

```bash
flutter pub get --enforce-lockfile
(cd poc_pdf_canvas && flutter pub get --enforce-lockfile)
flutter doctor -v
```

## 代码与文档

- 保持 Presentation → Application → Domain 的依赖方向；UI 不直接调用 DAO。
- 沿用 Riverpod、Drift 和稳定的阅读 locator；已发布 schema 变更必须提供迁移，不能清库替代。
- 考虑异步取消、切书与卸载后的请求失效，释放自己创建的计时器、订阅和文件资源。
- 保持本地优先与源文件保护，API key 只进入系统安全存储。
- 文档以中文为主，代码标识使用英文。行为变更同步必要规格，不把历史计划当作当前实现。
- 文档入口见 [docs/README.md](docs/README.md)。自动化代理另遵循根目录 `AGENTS.md`。

## 验证与 Pull Request

提交前先运行改动涉及的命名测试，再扩大到受影响的调用方：

```bash
dart format <修改的Dart文件>
flutter analyze --no-pub
flutter test --no-pub test/相关测试.dart --concurrency=4
python3 -m unittest discover -s test/tool -p '*_test.py'
```

最后一条用于修改打包或 CI 工具的情况。完整回归用于发布检查或影响较广的改动，
不要求每次文档修改都运行 Flutter 测试。

PR 说明写清问题、修改后的行为、验证命令与结果，以及尚未验证的平台或场景。
组件测试、离屏截图和构建成功不能替代真实设备验收。请保持改动集中，不夹带无关重构。
维护者本地安装脚本不会作为外部贡献者的强制环境要求。

## 贡献许可

提交用于合入的贡献时，按照 [Apache-2.0](LICENSE) 第 5 节授权；
如果包含第三方代码或素材，请保留原许可并说明来源。没有额外的 CLA 要求。
