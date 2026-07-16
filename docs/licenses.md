# PageSage 依赖许可记录

本文件记录发布前需要复核的第三方依赖许可。正式发布包应以 `pubspec.lock` 和平台包内 Flutter `NOTICES`/`NOTICES.Z` 为准。

完整依赖清单见 [`generated/third-party-licenses.md`](generated/third-party-licenses.md)。更新依赖后运行：

```powershell
dart run tool/generate_third_party_licenses.dart
```

## 主要依赖

- Flutter SDK：BSD-3-Clause。
- Riverpod：MIT。
- go_router：BSD-3-Clause。
- Drift：MIT。
- sqlite3_flutter_libs：MIT。
- file_picker：MIT。
- flutter_inappwebview：Apache-2.0。
- flutter_secure_storage：BSD-3-Clause。
- archive：Apache-2.0。
- pdf_document / pdf_graphics / pdf_cos：Apache-2.0。

## 发布要求

- 发布前重新检查 `pubspec.lock` 中所有直接和传递依赖。
- Windows 与 Android 包内需要包含第三方许可文本。
- `test/tool/release_readiness_test.dart` 会检查生成清单覆盖 `pubspec.lock` 中所有非 SDK 包，并检查 Android APK/AAB 与 Windows 构建产物包含 `NOTICES.Z`。
- 不能把 API key、用户书籍正文、AI 请求正文或本地数据库内容放入许可或诊断文件。

## 内置阅读字体

- **LXGW WenKai Lite（霞鹜文楷 Lite）** — SIL Open Font License 1.1  
  来源：https://github.com/lxgw/LxgwWenKai-Lite  
  许可副本：`assets/fonts/licenses/LXGWWenKaiLite-OFL.txt`

- **Atkinson Hyperlegible** — SIL Open Font License 1.1  
  来源：https://github.com/googlefonts/atkinson-hyperlegible  
  许可副本：`assets/fonts/licenses/AtkinsonHyperlegible-OFL.txt`
