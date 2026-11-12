# PageSage 项目总览

版本：0.1  
日期：2026-07-03  
状态：详细规格入口，含 UI/UX 现代化文档入口  

## 1. 项目简介

PageSage 是一个本地优先的跨平台智能阅读器，当前首版面向 EPUB、PDF 与 Markdown 的书籍管理与深度阅读。它不仅提供基础阅读体验，还提供全文搜索、分类、书签、划线、笔记，以及对选中文本进行 AI 问答、解释、总结和翻译的能力。

首发目标平台：

- Android
- Windows

后续目标平台：

- iOS
- macOS
- Linux

## 2. 产品一句话

PageSage 是一个可以管理、搜索、标注和询问书籍内容的本地智能阅读器。

## 3. 核心价值

1. 统一书库  
   用户可以把 EPUB、PDF 和 Markdown 放入同一个书库，按分类、标签、阅读状态管理。

2. 舒适阅读  
   用户可以调整字号、行距、背景、主题、阅读模式，并自动记忆每本书的阅读进度。

3. 可检索  
   书名、作者、正文、目录、书签、笔记和 AI 回答都可以被全局搜索。

4. 可沉淀  
   用户在阅读中产生的划线、书签、笔记、AI 回答会沉淀成可复习、可导出的知识库。

5. 可控 AI  
   AI 请求会明确展示将发送的上下文范围，默认不会自动上传书籍内容。

## 4. 文档地图

建议阅读顺序：

1. [01-product-requirements.md](01-product-requirements.md)  
   产品目标、用户画像、MVP 范围、成功指标、非目标范围。

2. [02-feature-spec.md](02-feature-spec.md)  
   每个功能模块的入口、状态、流程、异常和验收标准。

3. [03-interaction-spec.md](03-interaction-spec.md)  
   移动端、桌面端、阅读器、菜单、快捷键和关键任务流程。

4. [04-ui-design-system.md](04-ui-design-system.md)  
   视觉方向、颜色、字体、组件、布局、响应式和可访问性规范。

5. [05-technical-architecture.md](05-technical-architecture.md)  
   Flutter 架构、模块划分、渲染层、AI 抽象、本地任务和错误处理。

6. [06-data-model.md](06-data-model.md)  
   SQLite/Drift 数据表、FTS5 搜索表、定位模型和迁移策略。

7. [07-roadmap.md](07-roadmap.md)  
   MVP、Alpha、Beta、v1.0 和 UI/UX 现代化里程碑。

8. [08-ui-ux-redesign-plan.md](08-ui-ux-redesign-plan.md)  
   现代化 UI/UX 改造目标、页面范围、阶段路线、测试和最终效果。

9. [09-design-system.md](09-design-system.md)  
   现代化设计系统：色彩、排版、间距、组件、响应式、可访问性和 AI 视觉规则。

10. [testing-ui-ux-checklist.md](testing-ui-ux-checklist.md)  
   UI/UX 改造阶段的截图、响应式、主题、真实样本、键盘和可访问性验收清单。

11. [assets-plan.md](assets-plan.md)  
   App 图标、空状态、默认封面、商店宣传图等图片资源规划。

12. [v1-experience-freeze.md](v1-experience-freeze.md)  
   v1.0 体验冻结清单：必须做 / 明确延后、扫描 PDF 策略、手测红线。

13. [13-image-annotations.md](13-image-annotations.md)  
   图片批注与插图文档：图片锚点、批注存储扩展、PDF 识别边界和分批计划。

原始总纲保留在 [product-technical-document.md](product-technical-document.md)，作为早期启动稿参考。

2026-11-10 Linux 优先的下一批六项功能见 [统一规格](specs/linux-reader-six-features-2026-11-10/README.md) 与 [联合验收](specs/linux-reader-six-features-2026-11-10/07-validation-and-acceptance.md)。该入口是待实施规划，不改变本页历史平台验证记录，也不表示功能已经完成。

## 5. 首版技术决策

| 方向 | 决策 |
| --- | --- |
| 客户端 | Flutter + Dart |
| 首发平台 | Android + Windows |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 数据库 | SQLite |
| ORM | Drift |
| 全文搜索 | SQLite FTS5 |
| EPUB 阅读 | Flutter-native renderer |
| PDF 阅读 | `pdf_graphics` + Flutter Canvas（见 `10-pdf-renderer-migration.md`） |
| Markdown 阅读 | 复用 EPUB 文档模型与 Flutter-native renderer（见 `tasks/markdown-reading.md`） |
| MOBI/AZW | 暂缓，不进入当前首版实现 |
| AI | Provider 抽象，支持 OpenAI-compatible API 和本地模型 |
| 数据策略 | 本地优先，AI 上下文范围可见 |

## 6. 当前开发环境

已验证：

- Flutter 3.44.2
- Dart 3.12.2
- Android SDK 36.0.0
- Visual Studio 2022 Windows desktop toolchain
- `flutter doctor -v` 无问题
- Flutter 工程已在仓库根目录创建，已生成 Android 和 Windows 平台目录
- `flutter pub get` 成功
- `dart format .` 成功
- `flutter analyze` 无问题
- `flutter test` 通过
- `flutter build windows` 成功

已配置：

- `PUB_HOSTED_URL=https://pub.flutter-io.cn`
- `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
- `ANDROID_HOME=C:\Software\Android\SDK`
- `ANDROID_SDK_ROOT=C:\Software\Android\SDK`

待安装或后续确认：

- MOBI/AZW 与 Calibre 转换能力暂缓
- Android debug APK 首次构建需要下载 Gradle 9.1.0 all distribution，本次未在 10 分钟内完成，后续需重新验证
- 发布 iOS/macOS 时需要 macOS + Xcode

## 7. 项目边界

首版必须做：

- 书库
- EPUB/PDF/Markdown 导入
- 阅读器
- 阅读进度
- 分类
- 书签
- 基础设置
- SQLite 数据持久化

首版尽量做：

- 全文搜索
- 笔记
- 划线
- AI 划词问答

首版不做：

- 云同步
- 用户账号系统
- 商城或在线书源
- DRM 破解
- 扫描版 PDF OCR
- 多人协作
- MOBI/AZW 导入与 Calibre 转换

## 8. 开发原则

1. 先跑通完整链路，再打磨细节。  
   书库导入、打开阅读、保存进度、再次恢复，是最小闭环。

2. 所有用户数据必须有稳定存储模型。  
   不把进度、书签、笔记只存在内存或 WebView 状态里。

3. 阅读器和业务状态解耦。  
   EPUB/PDF/Markdown 渲染层只负责呈现和回传事件，业务数据由 Dart 层统一保存。

4. AI 不能阻塞基础阅读。  
   没有配置 AI 时，应用仍然是完整阅读器。

5. 平台差异通过平台层隔离。  
   文件选择、原生 PDF 渲染、外部命令、窗口行为都放到平台适配层。
