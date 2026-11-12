# PageSage 路线图与任务拆分

版本：0.1  
日期：2026-06-13  
状态：开发路线图（历史里程碑规划）

当前平台分发、已实现能力与验证范围见[测试版说明](beta.md)和
[实现记录](implementation-status.md)。下列初始里程碑保留规划背景，不代表当前实现状态。

## 1. 里程碑总览

| 阶段 | 目标 | 重点 |
| --- | --- | --- |
| M0 | 项目初始化 | Flutter 工程、基础结构、CI 雏形 |
| M1 MVP | 基础阅读闭环 | 导入 EPUB/PDF/Markdown、阅读、保存进度 |
| M2 Alpha | 阅读管理闭环 | 分类、书签、笔记、搜索 |
| M3 Beta | 智能和导出 | AI 问答、导出 |
| M4 v1.0 | 稳定发布 | 性能、备份、打包、辅助功能 |
| M5 UX | 现代化体验 | 设计系统、阅读器沉浸、桌面工作台、移动抽屉、AI 透明化 |

## 2. M0 项目初始化

目标：创建可运行的 Flutter 项目，并建立基础工程规范。

当前状态：

- Flutter 工程已在仓库根目录创建。
- Android 和 Windows 平台目录已生成。
- 已有最小书库空状态页面和 widget test。
- **状态校正（2026-11-08）**：本节的 unchecked 项是 2026-06-13 的初始 backlog，不代表当前待办。Riverpod / go_router / 分层目录 / 日志服务 / 错误模型均已在代码中落地；PDF.js Spike 已被 2026-10-21 的 Flutter Canvas 渲染迁移取代，见 `docs/10-pdf-renderer-migration.md`。仍需人工勾选的验收集中在 `docs/implementation-status.md`、`docs/v1-experience-freeze.md` 与 `docs/testing-ui-ux-checklist.md`。

任务：

- [x] 创建 Flutter 工程。
- [x] 保留 `docs/` 文档目录。
- [x] 配置 Android 和 Windows。
- [x] 配置 Riverpod。
- [x] 配置 go_router。
- [x] 配置 lint。
- [x] 建立目录结构。
- [x] 建立基础主题。
- [x] 建立日志服务。
- [x] 建立错误模型。

验收：

- `flutter run -d windows` 可运行。
- `flutter run -d <android-device>` 可运行，待 Android APK 首次构建完成后验证。
- 书库空状态页面显示。
- 文档目录未被覆盖。

## 3. M1 MVP

目标：用户可以导入 EPUB/PDF/Markdown，打开阅读，关闭后恢复进度。

### 3.1 数据库基础

任务：

- 接入 Drift。
- 建立 books 表。
- 建立 reading_progress 表。
- 建立 app_settings 表。
- 实现 BookDao。
- 实现 ProgressDao。

验收：

- 新增书籍记录。
- 查询书库。
- 保存和读取进度。

### 3.2 文件导入

任务：

- 接入 file_picker。
- 实现 FileRepository。
- 实现 hash 计算。
- 支持复制文件到应用目录。
- 支持 EPUB/PDF/Markdown 格式识别。
- 支持 Markdown 文件夹作为一本书原地读取：侧栏保留文件/子目录树，当前文件单独显示大纲。
- 重复导入提示。

验收：

- EPUB/PDF/Markdown 可导入。
- 重启后书籍仍存在。
- 重复文件可识别。
- 移除 Markdown 文件夹书不删除用户目录。

### 3.3 书库 UI

任务：

- 空状态。
- 网格视图。
- 列表视图，桌面。
- 书籍卡片。
- 导入按钮。
- 基础排序。

验收：

- 导入后书籍出现在书库。
- 点击书籍进入阅读器。

### 3.4 EPUB Spike

任务：

- 接入 Flutter-native EPUB 解析和渲染。
- 建立 Dart renderer 事件。
- 打开本地 EPUB。
- 回传 locationChanged。
- 支持 goTo 位置。

验收：

- EPUB 可打开。
- 翻页或滚动后 Dart 收到位置。
- 保存后可恢复。

### 3.5 PDF Spike

任务：

- 放入 PDF.js 静态资源。
- 创建 PDF viewer。
- 建立 JS bridge。
- 打开本地 PDF。
- 回传页码和滚动位置。
- 支持 goTo 页码。

验收：

- PDF 可打开。
- 页码可保存和恢复。

### 3.6 阅读设置 MVP

任务：

- 字号。
- 背景。
- 明暗主题。
- EPUB 行高。
- 设置持久化。

验收：

- 修改设置实时生效。
- 重启后设置保留。

## 4. M2 Alpha

目标：形成完整阅读管理能力。

### 4.1 分类和标签

任务：

- categories 表。
- tags 表。
- book_tags 表。
- 分类树 UI。
- 移动书籍到分类。
- 标签添加和筛选。

验收：

- 分类和标签重启后保留。
- 筛选准确。

### 4.2 书签

任务：

- bookmarks 表。
- 当前页添加书签。
- 书签面板。
- 书签跳转。
- 书签备注。

验收：

- 书签可添加、删除、跳转。

### 4.3 书内搜索

任务：

- EPUB 书内搜索。
- PDF 书内搜索。
- 结果列表。
- 点击结果跳转。

验收：

- 当前书内关键词可搜索。
- 结果跳转准确。

### 4.4 划线和笔记

任务：

- annotations 表。
- notes 表。
- 文本选择菜单。
- 高亮渲染。
- 笔记面板。
- 笔记列表页。

验收：

- 划线重启后仍显示。
- 笔记可编辑并跳回原文。

### 4.5 全局搜索

任务：

- search_chunks 表。
- search_chunks_fts。
- EPUB 文本提取。
- PDF 文本提取。
- 笔记和书签索引。
- 搜索页。
- 结果跳转。

验收：

- 搜索正文、笔记、书签。
- 索引失败不影响阅读。

## 5. M3 Beta

目标：加入 AI 和导出。

### 5.1 AI 设置

任务：

- AI Provider 设置页。
- API Key 安全存储。
- OpenAI-compatible Provider。
- 模型名配置。
- 连接测试。

验收：

- 配置后可发起测试请求。
- 密钥不出现在普通日志。

### 5.2 划词 AI

任务：

- 选中文本进入 AI 面板。
- 快捷动作。
- ContextBuilder。
- 流式输出。
- 取消请求。
- 保存为笔记。

验收：

- AI 回答可保存。
- 保存后可搜索。
- 请求可取消。

### 5.3 导出

任务：

- 单本书笔记导出 Markdown。
- 全部笔记导出 Markdown。
- 书签导出 CSV。

验收：

- 导出文件包含位置、原文、笔记。

## 6. M4 v1.0

目标：发布稳定版本。

任务：

- 性能优化。
- 大书库测试。
- 大 PDF 测试。
- 错误恢复。
- 数据库备份。
- 快捷键。
- 辅助功能。
- Windows 打包。
- Android 签名。
- 隐私说明。
- 许可证清单。

验收：

- `flutter doctor -v` 环境下可稳定构建。
- 常见样本无阻塞问题。
- 用户数据可备份。
- 发布包可安装。

## 6.1 M5 UI/UX 现代化

目标：把 PageSage 从默认 Flutter 控件拼装感升级为安静、现代、专业、适合长期阅读和知识沉淀的跨平台工具。

来源：

- `docs/08-ui-ux-redesign-plan.md`
- `docs/09-design-system.md`
- `docs/tasks/ui-ux-modernization.md`
- `docs/testing-ui-ux-checklist.md`

任务：

- [x] 制定 UI/UX 现代化总方案。
- [x] 制定现代化设计系统草案。
- [x] 制定可执行任务清单和 UI/UX 测试验收清单。
- [x] 在 Flutter 中落地设计 token 和公共组件。
- [x] 重构 App Shell：桌面侧栏、移动底栏、顶部命令区、任务状态入口。
- [x] 重构书库：卡片、列表、筛选、详情、空状态和索引状态。
- [x] 重构阅读器：沉浸工具栏、状态栏、目录、Notebook、搜索和 AI 面板。
- [x] 重构搜索、笔记、Notebook 和 AI 面板的信息层级。
- [x] 重构设置和任务中心。
- [ ] 完成响应式、键盘、可访问性和主题验收。
- [ ] 完成 Windows 和 Android 真实 EPUB/PDF 样本验证。

验收：

- 应用第一屏不再呈现默认 Flutter Demo 观感。
- 书库、阅读器、搜索、笔记、AI、设置、任务中心使用统一视觉语言。
- compact、medium、expanded 响应式检查通过。
- 浅色、暗色、护眼、高对比主题可读。
- Windows 和 Android 至少各完成一次真实阅读闭环验证。
- UI/UX 验收记录写入或引用 `docs/testing-ui-ux-checklist.md`。

## 7. 风险优先级

| 风险 | 阶段 | 应对 |
| --- | --- | --- |
| Windows PDF WebView 与移动 PDF WebView 差异 | M1 | 提前做 PDF renderer spike |
| EPUB CFI 恢复不稳定 | M1 | 保存 href/chapter/progress 作为备用 |
| PDF 文本层缺失 | M2 | 明确提示，OCR 后续 |
| AI 隐私担忧 | M3 | 上下文范围确认 |
| FTS 中文分词效果一般 | M2 | 先用基础 FTS，后续评估 tokenizer |
| MOBI/AZW 兼容范围膨胀 | 后续 | 当前版本明确暂缓，不接入 Calibre |
| UI 只局部换皮导致不一致 | M5 | 先落地 token 和公共组件，再逐页迁移 |
| 阅读器沉浸模式影响可访问性 | M5 | 同步验证键盘、焦点、语义和屏幕阅读器 |
| 桌面和移动体验互相牵制 | M5 | 分别定义 desktop workspace 和 mobile drawer 模式 |

## 8. 第一周建议任务

1. 完善 `lib/` 分层目录结构。
2. 接入 Riverpod 和 go_router。
3. 建立基础主题和导航。
4. 接入 Drift。
5. 实现 books 和 reading_progress。
6. 实现书库导入按钮和文件选择。
7. 验证 PDF WebView 在 Android 和 Windows 可用。
8. 放入最小 Flutter-native EPUB renderer。
9. 放入最小 PDF renderer。

## 9. Definition of Done

每个功能完成必须满足：

- 有基本错误处理。
- 数据重启后不丢失。
- Android 和 Windows 至少手动验证一次。
- 关键逻辑有单元测试或可重复手动测试步骤。
- 不破坏现有文档。
- 不引入未说明的大型依赖。

UI/UX 改造额外满足：

- 有截图或手动验收记录。
- 长标题、长标签、窄屏和高对比主题不破坏布局。
- 所有 icon-only 按钮有 tooltip 和语义。
- AI 请求前上下文范围可见。
