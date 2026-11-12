# 公开仓库准备

日期：2026-11-12

状态：已公开；本地验证、提交推送与私密漏洞报告配置完成

## 目标与边界

- 为 PageSage 自有代码与文档选择 Apache-2.0，保留第三方组件、字体和平台服务各自的授权。
- 完善公开版 README、贡献指南、安全反馈与问题模板。
- 保留 `docs/` 中的架构、规格、安装与脱敏评测记录，提供当前说明与历史记录的区分入口。
- 补齐发行包的项目许可和字体许可，修正应用内的错误许可说明。
- 私有备份后清理脱敏前的 GitHub Actions 运行、日志与附件；保留当前脱敏提交的运行。
- 不再次重写 Git 历史；仓库可见性按用户明确授权切为公开，不发布正式版本。

## 验证计划

基线：工作区干净；根目录尚无项目许可证；README 仍有私有下载措辞；
`archive` 的本地实际许可为 MIT，但文档和应用内显示 Apache-2.0；
旧 Actions 运行仍引用脱敏前提交。

| 待证明内容 | 验证方式 |
| --- | --- |
| 标准许可完整 | 与 Apache 官方文本逐字核对 |
| 文档导航、公开模板有效 | 本地链接检查、YAML 解析、差异检查 |
| Linux / Windows 包携带授权文本 | `test/tool/linux_distribution_test.dart`、`test/tool/platform_distribution_test.py` 实际归档断言 |
| 应用内许可说明与发行资源一致 | 设置页组件测试、`test/tool/release_readiness_test.dart`、静态分析、构建后检查 `NOTICES.Z` |
| 旧 Actions 清理完成 | 仓库外私有备份及校验、删除后的 API 清单复核 |
| 本地安装对应修改 | 静默运行 `tool/install_linux.sh` 并核对产物；不启动窗口 |

## 结果

### 交付

- 新增标准 `LICENSE`（Apache-2.0）与项目 `NOTICE`；许可证与 Apache 官方下载文本字节一致。
  不在所有源码文件批量添加头部。
- README 改为公开版入口，补 `docs/beta.md`、`docs/README.md`、`CONTRIBUTING.md`、
  `SECURITY.md`、两类 Issue Form 和 PR 模板。
- 保留 `docs/`，区分规格、当前状态、历史任务与脱敏评测；同步 Linux 现有分发状态，
  更新隐私文档的 Markdown 文件夹例外与备份内容边界。
- 修正 `archive` 许可为 MIT，移除已不用的 `sqlite3_flutter_libs` 条目。
  许可生成器补识别 `LICENSE-` / `NOTICE-` 补充声明，并重新生成依赖索引。
- Flutter 收集项目声明、两款字体 OFL 和 `archive` 的衍生实现声明；原字体授权正文保留。
  `archive` 副本仅规范换行与空白并添加分组名称，正文词序与锁定版本一致。
- Linux / Windows 归档携带项目及字体等声明；Windows 使用仓库当前许可覆盖旧 bundle
  中同名文件，避免重复 ZIP 条目。APK/AAB 打包拒绝缺少 `NOTICES.Z` 的输入。
- 应用关于页同步项目许可、第三方许可与 Markdown 文件夹隐私说明。
- 仓库外私有归档后，从当前源码树移除 11 张旧品牌实验图片及 2 份附属文件，
  共约 10.75 MB 图片；保留当前图标预览、生产资源与 README 截图。
  未为体积清理再次重写历史，不能把当前树精简量当作历史克隆缩减量。

### 验证

证据目录：被忽略的 `.local-data/public-preparation/`，汇总为 `results.json`。

| 验证 | 结果 |
| --- | --- |
| `flutter pub get --enforce-lockfile` | 通过，未新增依赖 |
| 修改 Dart 文件格式检查、`flutter analyze --no-pub` | 通过，无分析问题 |
| 上述 5 个命名 Flutter 测试文件 | 33 PASS / 2 SKIP；缺少对应平台产物的检查按原测试跳过，不计为通过 |
| `python3 -m unittest discover -s test/tool -p '*_test.py' -v` | 21 PASS，含缺失 APK/AAB 许可、Windows 缺失/旧许可反例 |
| `shellcheck tool/package_linux.sh` | 通过 |
| Markdown 本地链接与 Issue Form YAML | 99 份 Markdown 的文本链接有效，3 份 YAML 可解析 |
| 本轮 35 份修改/新增文本的 Gitleaks 扫描 | 无命中；此前全历史清理证据未因本次文档工作替代或扩大 |
| Linux 静默构建安装 | 通过；安装目录与 release bundle 的 `diff -qr` 无差异，未启动或停止应用 |
| 实际 Linux `NOTICES.Z` | 包含完整项目许可、NOTICE、两款字体与 archive 补充声明 |
| 实际 Linux 分发归档 | 6 份许可/索引副本逐项一致，SHA-256 校验通过，无书籍或用户数据库 |

本次为定向验证，不宣称重新运行全仓回归；Windows ZIP 用合成 bundle 验证归档行为，
没有把它当成 Windows 真机运行。Android 本轮验证打包反例与共享许可输入，
没有声称重建并验收了新的 APK/AAB。

### GitHub 清理与公开边界

- 先在仓库外私有目录备份 12 份旧运行日志 ZIP 与 11 份附件 ZIP，
  逐份检查 ZIP CRC、记录 SHA-256，再删除 12 次脱敏前运行及所属附件。
- 删除后 API 复核只保留当前脱敏提交 `3acd2f7` 的两条运行；
  留下的附件也均属于该提交。Actions cache 查询为 0，没有 Release 需要清理。
- 不把 GitHub API 清理当作撤销外部旧克隆或清除所有托管缓存的保证。
- 私有状态下启用 Private vulnerability reporting 曾返回 404；
  按用户明确授权切为公开后，已启用并通过 API 核对 `enabled: true`。
- 公开准备以 `45bff5d` 提交并推送到 `main`。随后用户明确要求完成公开，
  已将 `DCAM-03/pagesage` 切为 `PUBLIC`，并通过无身份凭证的 GitHub API 请求验证：
  `private: false`、`visibility: public`、许可证 `Apache-2.0`。
- 本轮未打 tag 或发布 Release；公开仓库不等于发布稳定二进制版本。
