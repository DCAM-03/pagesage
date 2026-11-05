# PageSage 完整产品任务索引

状态：任务规划  
日期：2026-07-03  
适用范围：完整产品开发，不按阶段或里程碑拆分  

## 使用方式

本目录把 PageSage 需要实现的产品能力拆成可独立验收的 task 文档。后续开发时应优先打开对应 task，再对照源文档、代码现状和验收标准实施。

每个 task 文档包含：

- 目标。
- 来源与边界。
- 功能范围。
- 实现任务。
- 涉及模块和文件。
- 数据与接口。
- UI 与交互。
- 验收标准。
- 测试与验证。
- 依赖与风险。

## 权威来源

- `docs/00-overview.md`
- `docs/01-product-requirements.md`
- `docs/02-feature-spec.md`
- `docs/03-interaction-spec.md`
- `docs/04-ui-design-system.md`
- `docs/05-technical-architecture.md`
- `docs/06-data-model.md`
- `docs/07-roadmap.md`
- `docs/08-ui-ux-redesign-plan.md`
- `docs/09-design-system.md`
- `docs/testing-ui-ux-checklist.md`
- `docs/assets-plan.md`
- `AGENTS.md`

`docs/product-technical-document.md` 是早期启动稿，只作为背景参考。若它与上述权威文档冲突，以权威文档为准。

## 当前不拆分的能力

以下能力不进入当前完整产品任务集，除非产品路线被明确更新：

- MOBI/AZW 导入。
- Calibre `ebook-convert` 集成。
- 云同步。
- 账号系统。
- 在线书城。
- DRM 绕过。
- 扫描版 PDF OCR Phase 2+（选页/FTS/bbox/ONNX；Phase 0/1 当前页 OCR 已落地，见 TASK-26）。
- 多人协作批注。
- 浏览器 Web 版完整阅读器。

## 后置规划（不阻塞当前交付）

| 编号 | 文档 | 主题 |
| --- | --- | --- |
| TASK-26 | [pdf-ocr-optional.md](pdf-ocr-optional.md) | 扫描版 PDF 本地 OCR（用户触发、分阶段、文本层优先） |

## 任务清单

| 编号 | 文档 | 主题 |
| --- | --- | --- |
| TASK-01 | [foundation-architecture.md](foundation-architecture.md) | 工程基础、分层架构、导航和主题 |
| TASK-02 | [local-database-and-migrations.md](local-database-and-migrations.md) | Drift/SQLite 数据库、迁移、DAO |
| TASK-03 | [file-import-and-storage.md](file-import-and-storage.md) | 文件导入、应用书库目录、元数据和去重 |
| TASK-04 | [library-management.md](library-management.md) | 书库页面、书籍管理、排序筛选和详情 |
| TASK-05 | [reader-core-and-progress.md](reader-core-and-progress.md) | 阅读器外壳、定位模型、进度保存和恢复 |
| TASK-06 | [epub-reader.md](epub-reader.md) | EPUB 渲染、目录、选词和书内能力 |
| TASK-07 | [pdf-reader.md](pdf-reader.md) | PDF 渲染、页码、缩放、文本层和异常 |
| TASK-08 | [reader-settings-and-appearance.md](reader-settings-and-appearance.md) | 阅读设置、主题、字体和外观 |
| TASK-09 | [categories-and-tags.md](categories-and-tags.md) | 分类树、标签、多条件筛选 |
| TASK-10 | [bookmarks.md](bookmarks.md) | 书签数据、面板、备注和跳转 |
| TASK-11 | [annotations-and-highlights.md](annotations-and-highlights.md) | 划线、高亮、选区定位和渲染 |
| TASK-12 | [notes.md](notes.md) | 笔记、摘录、编辑、列表和回跳 |
| TASK-13 | [in-book-search.md](in-book-search.md) | EPUB/PDF 书内搜索 |
| TASK-14 | [global-search-and-indexing.md](global-search-and-indexing.md) | 全局搜索、FTS5、索引任务和结果跳转 |
| TASK-15 | [ai-settings-and-providers.md](ai-settings-and-providers.md) | AI Provider 设置、安全存储和连接测试 |
| TASK-16 | [selected-text-ai-workflows.md](selected-text-ai-workflows.md) | 划词 AI、上下文范围、流式回答和保存 |
| TASK-17 | [export-backup-and-restore.md](export-backup-and-restore.md) | Markdown/CSV 导出、备份和恢复 |
| TASK-18 | [privacy-security-and-deletion.md](privacy-security-and-deletion.md) | 隐私、安全、日志、危险删除 |
| TASK-19 | [task-center-and-background-jobs.md](task-center-and-background-jobs.md) | 任务队列、任务中心、重试和取消 |
| TASK-20 | [platform-integration-android-windows.md](platform-integration-android-windows.md) | Android/Windows 平台集成 |
| TASK-21 | [accessibility-keyboard-and-responsive.md](accessibility-keyboard-and-responsive.md) | 可访问性、快捷键、响应式 |
| TASK-22 | [assets-branding-and-release-materials.md](assets-branding-and-release-materials.md) | 图片资源、图标、默认封面和商店素材 |
| TASK-23 | [testing-quality-and-sample-library.md](testing-quality-and-sample-library.md) | 自动化测试、样本库、质量门禁 |
| TASK-24 | [packaging-release-and-operations.md](packaging-release-and-operations.md) | 打包、发布、版本、许可和运维材料 |
| TASK-25 | [ui-ux-modernization.md](ui-ux-modernization.md) | UI/UX 现代化改造、设计系统、页面重构和验收 |
| TASK-26 | [pdf-ocr-optional.md](pdf-ocr-optional.md) | 扫描版 PDF 本地 OCR（可选 / 后置规划，非当前实现） |
| TASK-29 | [image-annotations.md](image-annotations.md) | 图片批注（PDF 拖框吸附、批注存储与渲染、导出） |
| TASK-30 | [epub-images.md](epub-images.md) | EPUB 真实图片渲染（当前加载器丢弃 `<img>`，图片完全不显示） |
| TASK-31 | [markdown-reading.md](markdown-reading.md) | Markdown 阅读（P1 单文件，P2 目录当一本书） |

## 通用完成标准

每个 task 完成时至少满足：

- 不破坏本地优先原则。
- 不让 UI 直接调用 DAO。
- 不让 renderer 直接写业务数据。
- 用户数据重启后不丢失。
- 对危险操作有确认。
- 对失败状态有可恢复提示。
- `dart format .` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- 涉及平台或渲染时完成 Windows 和至少一个 Android 目标的手动验证。
