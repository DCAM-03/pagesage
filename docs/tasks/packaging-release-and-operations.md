# TASK-24：打包、发布、版本、许可和运维材料

## 目标

建立 Android 和 Windows 的可发布流程，包括版本号、签名、打包、隐私说明、开源许可、更新日志、发布检查和本地诊断材料。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/05-technical-architecture.md`、`docs/07-roadmap.md`。
- 不做：自动更新系统、云端崩溃上报默认开启、应用商店账号操作。
- 约束：发布包包含图片与字体资源；不把测试书籍打入生产包。（WebView renderer 静态资源已随 S7 删除，不再需要打包。）

## 功能范围

- Android APK/AAB 构建。
- Windows release build。
- 版本号和构建号。
- Android 签名配置。
- Windows 图标和发布包。
- 图片与字体资源打包校验；确认没有残留 renderer 静态资源。
- 开源许可清单。
- 隐私说明。
- 更新日志。
- 发布前检查清单。
- 本地日志和诊断导出。

## 实现任务

- [ ] 统一 app version 和 build number。
- [ ] 配置 Android release signing，密钥不入库。
- [ ] 配置 Android `flutter build apk` 和 `flutter build appbundle`。
- [ ] 配置 Windows `flutter build windows`。
- [x] 确认 Epub/PDF 渲染所需的资源已随包处理（PDF 渲染器已无静态资源）。
- [ ] 确认图片资源和图标被 release 包包含。
- [ ] 生成开源许可清单。
- [x] 编写隐私说明，明确本地优先、AI 上下文范围、API key 安全存储。
- [ ] 编写更新日志模板。
- [ ] 编写发布检查清单：测试、手动验证、样本验证、隐私、删除规则。
- [ ] 生产包不包含测试书籍和 debug reset 入口。
- [ ] 提供本地诊断导出，默认脱敏。
- [ ] 记录构建环境：Flutter、Dart、Android SDK、Visual Studio。
- [ ] Windows 发布包选择 zip 或安装包策略。

## 涉及模块和文件

- `pubspec.yaml`
- `android/app/build.gradle` 或对应 Gradle 配置
- `android/`
- `windows/`
- `assets/images/`
- `docs/release-checklist.md`
- `docs/privacy.md`
- `docs/changelog.md`
- `docs/licenses.md`

## 数据与接口

- 版本信息应在关于页显示。
- 诊断导出不包含 API key、AI payload、书籍正文和完整上下文。
- 发布包不包含测试数据。
- Debug reset 仅 debug 构建可用。

## UI 与交互

- 关于页显示版本号、构建号、开源许可、隐私说明入口。
- 本地诊断导出需要用户主动触发。
- 生产环境危险调试入口隐藏。
- Windows 发布包应能在干净机器上启动（不再依赖 WebView2 运行时）。

## 验收标准

- [ ] Android release APK 可构建。
- [ ] Android AAB 可构建。
- [ ] Windows release build 可构建。
- [ ] 发布包中包含图片与字体资源。
- [ ] 关于页显示版本和许可入口。
- [ ] 隐私说明存在并与产品行为一致。
- [ ] 测试书籍不在生产包中。
- [ ] 发布前检查清单完成。

## 测试与验证

- `flutter doctor -v`
- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter build apk`
- `flutter build appbundle`
- `flutter build windows`
- 手动验证：安装 Android 包、运行 Windows release 包、打开 EPUB/PDF、检查资源和关于页。

## 依赖与风险

- 依赖：TASK-18 隐私安全，TASK-22 资源，TASK-23 质量门禁。
- 风险：签名密钥和发布凭据不能入库。
- 风险：图片/字体资源遗漏会导致界面缺图或回退字体。
