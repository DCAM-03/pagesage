# PageSage 项目与第三方许可

## 项目许可

PageSage 自有代码与文档采用 [Apache License 2.0](../LICENSE)，项目声明见
[NOTICE](../NOTICE)。选择该许可是为了允许社区修改、商业使用与再分发，同时提供明确的贡献者专利授权条款。
完整权利与义务以许可证原文为准；该许可不授予项目商标权，也不涵盖用户导入的书籍。

第三方软件、字体和平台 SDK 不因项目采用 Apache-2.0 而改变原许可。
本文件是许可索引；具体文本以锁定版本携带的 LICENSE/NOTICE、
平台包内 Flutter `NOTICES.Z` 和相应上游条款为准。

完整依赖清单见 [`generated/third-party-licenses.md`](generated/third-party-licenses.md)。更新依赖后运行：

```powershell
dart run tool/generate_third_party_licenses.dart
```

## 主要依赖

- Flutter SDK：BSD-3-Clause。
- Riverpod：MIT。
- go_router：BSD-3-Clause。
- Drift：MIT。
- sqlite3 Dart 包：MIT；随包 SQLite 原生实现为 public domain，见 [SQLite 版权说明](https://www.sqlite.org/copyright.html)。
- file_picker：MIT。
- flutter_secure_storage：BSD-3-Clause。
- archive：MIT；其中衍生实现的声明见上游 `LICENSE-other.md`，
  随项目副本为 `assets/licenses/archive-LICENSE-other.txt`。
- dart_pdf_editor / pdf_document / pdf_graphics / pdf_cos：Apache-2.0。
- url_launcher：BSD-3-Clause。

以上条目已按本机锁定包核对；不是全部依赖的统一授权声明。`archive` 的第三方声明
通过 `flutter.licenses` 一并收集；升级 `archive` 时需核对并更新随项目的补充声明副本。
Android 的 Google ML Kit OCR SDK
另受 [ML Kit 条款](https://developers.google.com/ml-kit/terms)约束，不能视为项目自有
Apache-2.0 代码。Windows 系统 OCR 与 Linux 可选 Tesseract 也保留各自的系统/上游许可；
Linux 包不附带 Tesseract 和语言数据。

## 发布要求

- 发布前重新检查 `pubspec.lock` 中所有直接和传递依赖。
- Linux 和 Windows 归档根目录包含项目 `LICENSE`、`NOTICE` 与字体许可副本。
- 所有平台通过 Flutter `NOTICES.Z` 携带项目许可、项目声明和两款内置字体许可；
  Android 在 APK/AAB 内收集，不能修改已签名包来补文件。
- Linux 和 Windows 归档另外包含生成的第三方依赖索引；索引不能替代完整许可文本。
- `test/tool/release_readiness_test.dart` 会检查生成清单覆盖 `pubspec.lock` 中所有非 SDK 包，并检查 Android APK/AAB 与 Windows 构建产物包含 `NOTICES.Z`。
- Google ML Kit 等原生 SDK 的平台授权需单独复核，Flutter 包清单不能代表全部原生依赖。
- 不能把 API key、用户书籍正文、AI 请求正文或本地数据库内容放入许可或诊断文件。

## 内置阅读字体

- **LXGW WenKai Lite（霞鹜文楷 Lite）** — SIL Open Font License 1.1  
  来源：https://github.com/lxgw/LxgwWenKai-Lite  
  许可副本：`assets/fonts/licenses/LXGWWenKaiLite-OFL.txt`

- **Atkinson Hyperlegible** — SIL Open Font License 1.1  
  来源：https://github.com/googlefonts/atkinson-hyperlegible  
  许可副本：`assets/fonts/licenses/AtkinsonHyperlegible-OFL.txt`

这两份文件在原文前加字体名称，供 Flutter 许可证页面分组，不改动原授权正文。
