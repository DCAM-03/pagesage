# TASK-25：UI/UX 现代化改造

## 目标

将 PageSage 从默认 Flutter 控件拼装感升级为安静、现代、专业、适合长期阅读和知识沉淀的跨平台阅读工具。改造必须覆盖视觉系统、核心页面、阅读器、AI 交互、响应式、可访问性和测试验收。

## 来源与边界

- 来源：`docs/08-ui-ux-redesign-plan.md`、`docs/09-design-system.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`。
- 约束：保持本地优先；AI 仍然必须用户主动触发；不得引入云同步、账号、在线书城、MOBI/AZW 或 Calibre 集成。
- 不做：本任务不改变业务范围，不重写数据库，不引入新的大型 UI 框架。

## 功能范围

- 设计 token 和主题。
- App Shell 和主导航。
- 书库视觉和交互。
- 阅读器沉浸体验。
- 搜索、Notebook、笔记、AI 面板。
- 设置和任务中心。
- 响应式、键盘、可访问性。
- 截图和真实样本验收。

## 实现任务

### 阶段 0：文档和设计系统

- [x] 新增 UI/UX 重设计总方案。
- [x] 新增现代化设计系统文档。
- [x] 新增 UI/UX 现代化任务清单。
- [x] 新增 UI/UX 测试验收清单。
- [x] 更新交互规格、视觉规范、路线图和任务索引。

### 阶段 1：设计 token 和 App Shell

- [x] 在 Flutter 中集中实现颜色、文字、间距、圆角、状态 token。
- [x] 重构 `app_theme.dart`，覆盖浅色、暗色、护眼、高对比基础主题。
- [x] 建立公共组件：PageHeader、CommandBar、EmptyState、StatusBanner、SidePanel、FilterBar。
- [x] 桌面端左侧导航升级为现代侧栏，加入任务中心入口。
- [x] 移动端底部导航精简，阅读器 route 隐藏主导航。
- [x] 顶部命令区支持全局搜索、导入、任务状态。
- [x] 页面标题区替代默认沉重 AppBar。

### 阶段 2：书库现代化

- [x] 重做书籍网格卡片：固定封面比例、标题两行、作者一行、进度细线、格式角标。
- [x] 重做列表和紧凑列表：提高扫描效率，展示分类、标签、格式、进度、最近打开。
- [x] 桌面端左侧分类和系统筛选视觉统一。
- [x] 桌面端右侧书籍详情面板重做。
- [x] 移动端筛选改为 chips + 底部筛选面板。
- [x] 空书库状态重做，只保留导入 EPUB/PDF 主动作。
- [x] 导入中、索引中、索引失败状态统一为低噪声 status chip。
- [x] 长标题、多标签、无封面、损坏封面状态不撑破布局。

### 阶段 3：阅读器沉浸体验

- [x] 阅读器顶部栏和底部栏改为可自动隐藏。
- [x] 桌面端目录面板、阅读区、上下文面板使用统一 SidePanel 规范。
- [x] 右侧上下文面板统一搜索、Notebook、AI Tab。
- [x] 移动端目录、搜索、Notebook、AI 改为底部抽屉。
- [x] EPUB 正文最大行宽、边距、段距和代码块样式重做。
- [x] PDF 工具栏重做，集中页码、缩放、适宽、搜索、书签。
- [x] 底部状态栏显示章节或页码、百分比、缩放或字号。
- [x] 文本选择浮层重做，提供高亮、笔记、复制、AI 和更多操作。
- [x] 阅读设置面板用预设 + 高级项分层，不把所有滑块平铺。

### 阶段 4：搜索、Notebook、笔记和 AI

- [x] 搜索页改为结果分组：书籍、正文、Notebook、AI。
- [x] 搜索结果显示来源、位置、命中片段和关键词高亮。
- [x] 桌面端搜索支持右侧预览。
- [x] 搜索结果支持复制、保存为笔记、对片段提问。
- [x] Notebook 统一书签、标注、笔记、AI 记录视觉。
- [x] 笔记页桌面端左列表右预览，移动端列表进入详情。
- [x] AI 面板顶部固定显示选中文本摘要和上下文范围。
- [x] AI 快捷动作使用分组按钮或菜单：解释、总结、翻译、提炼要点、生成问题。
- [x] AI 未配置、上下文过长、网络错误、请求取消状态重做。
- [x] AI 回答保存后在 Notebook 和搜索中视觉一致。

### 阶段 5：设置、任务、可访问性和发布收尾

- [x] 设置页移动端拆分为分组二级页。
- [x] 设置页桌面端改为左分组右详情。
- [x] 任务中心加入主导航，任务状态在命令区可见。
- [x] 可取消长任务必须真正停止可取消流程并清理临时文件。
- [x] 所有 icon-only 按钮补 semantic label 和 tooltip。
- [x] Tab 顺序、Esc 关闭、方向键列表导航检查。
- [x] 高对比主题覆盖应用、阅读器、标注、搜索命中。
- [x] 长文本、窄屏、缩放字体下无重叠。
- [x] 隐私说明和许可说明入口在设置页可见。
- [ ] 发布截图和文档引用更新为新版 UI。

## 涉及模块和文件

- `lib/app/theme/app_theme.dart`
- `lib/app/responsive/`
- `lib/features/app_shell/presentation/`
- `lib/features/library/presentation/`
- `lib/features/reader/presentation/`
- `lib/features/search/presentation/`
- `lib/features/notes/presentation/`
- `lib/features/settings/presentation/`
- `lib/features/tasks/presentation/`
- `lib/features/ai/`
- `assets/images/`
- `docs/03-interaction-spec.md`
- `docs/04-ui-design-system.md`
- `docs/testing-ui-ux-checklist.md`

## UI 与交互验收标准

- [ ] 应用第一屏具备统一现代视觉，不像默认 Flutter Demo。
- [ ] 书库能清楚表达书籍、进度、格式、分类、标签和状态。
- [ ] 阅读器正文或 PDF 页面不被长期遮挡。
- [ ] 桌面端三栏工作区可高效使用。
- [ ] 移动端可以用底部抽屉完成复杂阅读操作。
- [ ] 搜索结果可扫描、可预览、可跳回原文。
- [ ] AI 发送前上下文范围清晰可见。
- [ ] 空、加载、错误、未配置、无文本层、索引失败等状态完整。
- [ ] 浅色、暗色、护眼、高对比主题均可读。
- [ ] 长标题、长标签、长搜索词不撑破布局。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- Windows 1440px、1024px、768px 截图。
- Android 手机 360px 截图。
- 浅色、暗色、护眼、高对比主题截图。
- 真实 EPUB：导入、打开、翻页、目录、书签、标注、笔记、保存进度、重启恢复。
- 真实 PDF：导入、打开、滚动、页码跳转、缩放、搜索、保存进度、重启恢复。
- 边界样本：无封面、长标题、多标签、PDF 无文本层、损坏文件、AI 未配置、索引失败。
- 键盘：Tab、Esc、方向键、Ctrl+F、Ctrl+Shift+F、Ctrl+B、Ctrl+G、Ctrl+Plus、Ctrl+Minus、Ctrl+0。
- 可访问性：tooltip、semantic label、焦点可见、对比度、非颜色状态表达。

详细步骤见 `docs/testing-ui-ux-checklist.md`。

## 依赖与风险

- 依赖：TASK-01、TASK-04、TASK-05、TASK-13、TASK-14、TASK-16、TASK-21。
- 风险：只做局部换色会让界面更不一致，必须先集中 token 和公共组件。
- 风险：阅读器沉浸模式可能牺牲键盘和可访问性，需要同步验收。
- 风险：桌面和移动差异较大，不能只用一个响应式布局硬套。
- 风险：AI 面板若过度突出，会违背阅读优先和本地优先体验。
