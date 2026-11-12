# TASK-25：UI/UX 现代化改造

## 目标

将 PageSage 从默认 Flutter 控件拼装感升级为安静、现代、专业、适合长期阅读和知识沉淀的跨平台阅读工具。改造必须覆盖视觉系统、核心页面、阅读器、AI 交互、响应式、可访问性和测试验收。

## 来源与边界

- 来源：`docs/08-ui-ux-redesign-plan.md`、`docs/09-design-system.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`。
- 约束：保持本地优先；AI 请求必须展示上下文范围；不得引入云同步、账号、在线书城、MOBI/AZW 或 Calibre 集成。
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

## 2026-11-10：桌面阅读器工具栏收口

- 范围：保留目录、搜索、书签、Notebook、AI 和设置的直接入口，按导航、记录与工具分组；快速主题移入“更多阅读操作”。
- PDF 浮动条仅保留页码、缩放、适宽/适页和按能力显示的 OCR，搜索和书签由主工具栏统一承担；保留“更多”中的 PDF 操作作为浮动条收起后的备用入口。
- 标签根据工具栏实际可用宽度及文字缩放决定是否显示；目录/工具面板/书签显示对应选中状态。窄 PDF 区域的收起按钮固定，键盘操作且焦点留在工具条内时不自动隐藏；转回鼠标后恢复自动收起。
- 已证明：600/900/1024/1440px、长书名、大字体下无溢出；EPUB/Markdown/PDF 的 Notebook、搜索、书签和主题菜单接线可用；PDF 没有重复的搜索/书签按钮，横向滚动不挤走收起入口；键盘保持、焦点离开及切回鼠标后的自动隐藏正确。
- 反例：补测复现了键盘焦点留在 PDF 工具条后，改用鼠标点击并移出却无法收起的问题；现在分别记录输入方式与焦点，修复后两种输入用例通过。旧页签恢复测试改为精确点击工具栏，避免误点 Notebook 内同名 AI 分类。
- 验证：`flutter test test/features/reader test/widget_test.dart test/domain/books/reader_settings_test.dart --concurrency=4 --reporter expanded` 133 项通过；`flutter analyze` 通过。
- 离屏：`flutter test test/features/reader/reader_chrome_test.dart --dart-define=CAPTURE_READER_WORKBENCH=true --concurrency=1 --reporter expanded` 9 项通过，生成并检查 6 张 `build/workbench-captures/reader-toolbar-*.png`，涵盖浅/暗色、最高 2 倍文字设置和 220px PDF 工具条。捕获为控件装载本机中文字体，避免测试字体方框，不改变应用字体配置。
- 证据：`/tmp/pagesage-reader-toolbar-{input,regression,analyze,visual,install}.log`；真实应用窗口及真实书籍阅读未在本轮验收，组件与离屏结果不替代正文渲染/进度恢复证明。
- 安装：静默运行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 成功，release bundle 与 `$HOME/.local/opt/pagesage` 全目录对比一致；两侧 `libapp.so` SHA256 均为 `d124251c4a07fb025a523353e80c13877eee2936622ed12495aa6c4a7c8e2a64`。安装前后均无运行实例，未启动窗口。

## 2026-11-10：阅读设置入口统一

- 设置页与阅读器共用字体选择器，均提供系统/内置/自定义字体名称；文案明确全局作用范围及 EPUB/Markdown 与 PDF 的区别。
- 阅读分类入口展示保存后的字号、模式、阅读主题和字体，加载/错误状态独立；保留自定义字体值和未应用草稿。
- 设置与阅读器相关回归最终 153 项通过，分析无问题；真实字体离屏用例 13 项通过并检查 7 张最终图片，修正窄屏大字号的字体说明截断。具体命令、反例及未验收边界见 [阅读设置任务](reader-settings-and-appearance.md#2026-11-10阅读设置入口一致性)。

## 2026-11-10：AI 设置表单与反馈

- 连接地址、模型、密钥与操作按钮集中展示，高级参数折叠，减少初次配置的滚动和视觉层级；沿用现有主题和控件，不替换设置页整体结构。
- 统一未保存、保存中和失败反馈，处理中阻止冲突操作；失败输入可重试，桌面切换分类和窄屏返回不丢设置页会话内的草稿。
- 相关回归 83 项通过，静态分析无问题；离屏涵盖 390/900/1440px、浅/暗色和 1.5/2 倍文字，已检查 8 张截图。真实窗口与真实接口未验收，细节和安装结果见 [AI 设置任务](ai-settings-and-providers.md#2026-11-10设置表单与交互打磨)。

## 2026-11-11：窄屏 PDF 工具条与 OCR 任务状态

- 范围：继续局部打磨 PDF 阅读操作、任务中心与设置二级页，沿用现有主题和控件，不增加依赖或修改数据结构。
- PDF 工具条：窄布局保留「识别可见页」直接入口，将「识别范围」「识别整本」放入「更多识别操作」；页码与收起按钮保持固定，范围与整本操作仍调用原有流程。
- 任务中心：说明文字纳入文字识别，汇总补充「已暂停」「部分完成」；进度明确标记为「已处理」，部分完成使用现有警告色并保留状态文字，避免把已处理 100% 当作全部识别成功。暂停任务保留继续入口，部分完成任务保留失败页重试入口。
- 设置页：窄屏二级页保留带返回按钮的标题，移除重复分组标题；桌面分类与详情结构不变。
- 验证基线与反例：原定向测试通过，但真实字体离屏执行暴露默认数据库依赖和 `path_provider` 插件异常。任务中心测试改用独立内存 SQLite 并关闭连接；AI 表单测试显式覆盖配置列表与设置控制器，并禁止访问默认数据库。长路径详情用例补充实际滚动，避免把尚未构建的列表条目当作丢失。仅在截图主题中指定已加载的 Chip 字体，消除测试字体方框。
- 行为验证：`flutter test test/features/reader/reader_chrome_test.dart test/features/tasks/task_center_page_test.dart test/features/settings/reader_settings_test.dart test/features/settings/ai_settings_card_test.dart --dart-define=CAPTURE_READER_WORKBENCH=true --concurrency=4 --reporter expanded` 最终 38 项通过，无数据库警告或插件异常；覆盖窄工具条各入口回调、部分完成 100% 的独立统计、暂停状态及相应操作菜单、大字体详情滚动与设置交互。
- 布局验证：检查 11 张离屏截图，包含 220px PDF 工具条、390px/1.5 倍文字的暂停任务与菜单、部分完成任务与菜单，以及 390/900/1440px 的 AI/阅读设置关键状态，最高 2 倍文字，浅/暗色均有覆盖。没有发现本轮界面的横向溢出、状态遮挡或重复标题。截图位于 `build/workbench-captures/`，不替代真实窗口验收。
- 工程验证：本轮涉及的 6 个 Dart 文件格式检查通过，`flutter analyze` 无问题，`git diff --check` 通过。日志：`/tmp/pagesage-ui-validation-final.log`、`/tmp/pagesage-ui-analyze-final.log`、`/tmp/pagesage-ui-format-final.log`。
- 安装：`CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 静默构建并安装成功，完整 release bundle 与 `$HOME/.local/opt/pagesage` 对比一致；两侧 `lib/libapp.so` SHA-256 均为 `97d8a2bf1488a8174c0447b46956a5319f3a0b2aa9bbe45e7a16304741467d59`。日志：`/tmp/pagesage-ui-install-final.log`、`/tmp/pagesage-ui-install-hashes.log`。安装前后无 PageSage 进程，未启动窗口。真实窗口和 Windows/Android 本轮未验收。

## 依赖与风险

- 依赖：TASK-01、TASK-04、TASK-05、TASK-13、TASK-14、TASK-16、TASK-21。
- 风险：只做局部换色会让界面更不一致，必须先集中 token 和公共组件。
- 风险：阅读器沉浸模式可能牺牲键盘和可访问性，需要同步验收。
- 风险：桌面和移动差异较大，不能只用一个响应式布局硬套。
- 风险：AI 面板若过度突出，会违背阅读优先和本地优先体验。
