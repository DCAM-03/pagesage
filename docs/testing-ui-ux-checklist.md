# PageSage UI/UX 测试与验收清单

版本：0.1  
日期：2026-07-03  
状态：UI/UX 现代化验收清单  

## 1. 使用方式

每完成一个 UI/UX 改造阶段，都应按本清单记录验证结果。涉及阅读器、平台、响应式或可访问性时，不能只依赖单元测试，需要真实设备或桌面窗口手动验证。

本地 EPUB/PDF 验收样本见 `docs/manual-samples.md`。运行 `dart run tool/generate_manual_samples.dart` 后会生成到 `.codex-run/samples/`，这些文件只用于本地验证，不进入生产资源包。

记录格式建议：

```text
日期：
提交或版本：
平台：
验证人：
样本：
结果：
阻塞问题：
```

## 2. 自动化检查

- [x] `dart format .`
- [x] `flutter analyze`
- [x] `flutter test`
- [x] 新增或更新相关 widget test。
- [x] 新增或更新核心状态/控制器测试。
- [x] 文档链接和任务索引无失效引用。

记录：

```text
日期：2026-07-04
提交或版本：本地工作树，UI/UX 现代化阶段 1 与书库第一版
平台：Windows 开发环境自动化检查
验证人：Codex
样本：widget 空书库状态、现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 89 项通过。
阻塞问题：尚未完成 Windows/Android 截图、真实 EPUB/PDF 样本、主题和可访问性手动验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，书库移动筛选面板
平台：Windows 开发环境自动化检查
验证人：Codex
样本：移动端书库筛选 chips + 底部筛选面板代码路径、现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 89 项通过。
阻塞问题：尚未完成 Android 360px/412px 截图和触控实机验证；尚未用真实分类、标签、多标签样本做人工检查。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器移动沉浸控制第一版
平台：Windows 开发环境自动化检查
验证人：Codex
样本：阅读器 compact 断点 UI 代码路径、现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 89 项通过。
阻塞问题：尚未在 Android 真机或 360px/412px 截图验证自动隐藏、底部控制条、EPUB/PDF 触控滚动、文本选择和底部抽屉交互。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器桌面 SidePanel 统一
平台：Windows 开发环境自动化检查
验证人：Codex
样本：阅读器目录面板、右侧上下文搜索/Notebook/AI Tab 代码路径、现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 89 项通过。
阻塞问题：尚未完成 Windows 1440px/1024px/768px 截图；尚未用真实 EPUB/PDF 验证目录跳转、面板拖拽宽度、上下文 Tab 与阅读位置稳定性。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读设置预设与分层面板
平台：Windows 开发环境自动化检查
验证人：Codex
样本：阅读设置面板 UI 代码路径、ReaderSettings 现有序列化测试、现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 89 项通过。
阻塞问题：尚未用真实 EPUB/PDF 验证字号、行高、页边距、PDF 缩放、主题切换后的阅读位置稳定性；尚未完成移动端窄屏截图。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器状态栏与 EPUB 正文排版
平台：Windows 开发环境自动化检查
验证人：Codex
样本：阅读器状态栏字号/缩放显示、EPUB 连续/分页正文宽度、段距、标题、代码块和图片占位代码路径；新增 EPUB 分页指标测试
结果：dart format . 通过；flutter analyze 通过；flutter test 90 项通过。
阻塞问题：尚未用真实 EPUB 样本验证长段落、代码块、图片占位、标注选择和移动端窄屏阅读；尚未完成 Windows/Android 截图和真实 PDF 样本验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，PDF 集中快捷工具栏
平台：Windows 开发环境自动化检查
验证人：Codex
样本：阅读器 PDF 桌面浮动工具条、移动底部工具条、页码跳转、缩放、适宽、整页、搜索和书签代码路径；现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 90 项通过。
阻塞问题：尚未用真实 PDF 样本验证页码跳转、缩放、适宽/整页、搜索、书签持久化和移动端触控；尚未完成 Windows 1440px/1024px/768px 与 Android 360px 截图。
```

```text
日期：2026-07-04
提交或版本：本地工作树，文本选择浮层重做
平台：Windows 开发环境自动化检查
验证人：Codex
样本：EPUB/PDF 文本选择事件后的桌面浮层和移动底部面板代码路径；高亮、笔记、复制、AI、下划线、本书搜索动作复用现有处理逻辑；现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 90 项通过。
阻塞问题：尚未用真实 EPUB/PDF 样本验证划词矩形定位、移动端文本选择、复制剪贴板、AI 上下文预览、标注持久化和键盘 Esc 关闭；尚未完成截图验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，搜索页分组、预览和结果动作
平台：Windows 开发环境自动化检查
验证人：Codex
样本：搜索页 PageHeader、分组结果、来源/位置 chip、mark 命中高亮、桌面右侧预览、复制片段、保存为笔记、对片段提问代码路径；现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 90 项通过。
阻塞问题：尚未用真实书库验证搜索结果分组准确性、FTS 高亮、右侧预览、AI 未配置提示、保存笔记后的搜索可见性；尚未完成桌面/移动截图和键盘导航验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Notebook 统一视觉
平台：Windows 开发环境自动化检查
验证人：Codex
样本：阅读器 Notebook 书签、标注、笔记、AI 记录聚合条目视觉；笔记页桌面左列表右预览和移动底部详情现有代码路径；现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 90 项通过。
阻塞问题：尚未用真实书籍验证书签、标注、摘录笔记、AI 记录同时存在时的排序、跳转、复制、删除和保存为笔记；尚未完成窄屏和桌面截图验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，AI 面板上下文和状态重做
平台：Windows 开发环境自动化检查
验证人：Codex
样本：AI 面板固定上下文摘要、上下文范围 chip、解释/总结/提炼要点/翻译/生成问题快捷动作、生成中状态、错误状态、取消状态和保存为 Notebook 代码路径；现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 90 项通过。
阻塞问题：尚未用真实 AI Provider 验证未配置、API Key 缺失、网络错误、请求取消、流式输出、保存为笔记后 Notebook/Search 视觉一致性；尚未完成真实书籍上下文范围人工核对。
```

```text
日期：2026-07-04
提交或版本：本地工作树，AI 服务状态和错误边界测试
平台：Windows 开发环境 unit test
验证人：Codex
样本：test/features/ai/ai_chat_service_test.dart；fake AiSettingsRepository、fake AiProvider、fake AiConversationRepository；禁用 AI、Provider 配置缺失、API Key 缺失、空回答、流式 chunk、取消保留 partial answer、禁用状态下连接测试
结果：新增 AiChatService 状态测试，证明禁用 AI 时不会调用 provider 且不会保存对话；Provider baseUrl/model 缺失时不会读取 API Key；API Key 缺失时不会调用 provider；provider 返回空白回答时不会保存；流式 chunk 会逐段回调并保存完整回答；取消请求会抛出 AiChatCancelledException 并保留已生成部分；testConnection 在 AI 功能关闭但配置完整时仍可执行 provider 连接测试。单独运行 `flutter test test/features/ai/ai_chat_service_test.dart` 7 项通过。
阻塞问题：该记录覆盖 AI 应用服务状态机，不等于真实 AI Provider 网络错误、无效 API Key、模型不存在、真实流式 HTTP、Reader AI 面板 UI、Notebook/Search 保存后视觉一致性或真实书籍上下文人工核对完成；这些仍需真实 Provider 或可控集成环境验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，设置页响应式分组
平台：Windows 开发环境自动化检查
验证人：Codex
样本：设置页桌面左分组右详情、移动分组入口和二级详情页、隐私与数据操作卡片代码路径；现有单元/组件测试
结果：dart format . 通过；flutter analyze 通过；flutter test 90 项通过。
阻塞问题：尚未用 Windows 1440px/1024px/768px 和 Android 360px 验证设置页导航、表单保存、AI 密钥显示/隐藏、数据导出/备份入口和返回栈；尚未做屏幕阅读器验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，任务中心入口与协作式取消
平台：Windows 开发环境自动化检查
验证人：Codex
样本：主导航任务入口、桌面命令区任务状态、任务中心汇总、导入/索引/导出/备份取消 token、导入分块复制、索引取消清理、导出/备份 .part 清理代码路径；新增任务取消和索引取消单元测试
结果：dart format . 通过；flutter analyze 通过；flutter test 92 项通过。任务中心已在桌面侧栏、移动底部导航和桌面命令区显示活动任务数量；可取消任务会触发 TaskCancelToken，导入复制和索引在阶段边界停止，导出/备份会清理目标临时文件；恢复数据库任务不显示取消操作，避免中途破坏数据库一致性。
阻塞问题：尚未用真实大 EPUB/PDF、长时间导出和大备份压缩做人工取消验证；尚未完成 Windows 1440px/1024px/768px、Android 360px 截图和屏幕阅读器验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，icon-only 按钮语义审计
平台：Windows 开发环境静态审计
验证人：Codex
样本：lib 下所有 IconButton 和 PopupMenuButton 静态扫描；阅读器 PDF 工具栏、移动阅读器按钮、文本选择操作按钮、面板拖拽条等自定义交互控件人工代码检查
结果：所有 IconButton 和 PopupMenuButton 均带 tooltip；自定义 icon-only 或图标主导操作已使用 Tooltip + Semantics 或可见文字标签；本轮未发现缺失 tooltip 的裸图标按钮。
阻塞问题：尚未用 TalkBack 或 Windows Narrator 实际朗读验证语义树；尚未做字体放大后的可访问性人工检查。
```

```text
日期：2026-07-04
提交或版本：本地工作树，icon-only tooltip 自动化守卫
平台：Windows 开发环境静态测试
验证人：Codex
样本：test/tool/release_readiness_test.dart；lib 下所有 Dart 文件；IconButton、IconButton.filledTonal、PopupMenuButton 构造调用；阅读器 PDF 快捷工具按钮
结果：新增 release readiness 测试 `icon-only controls keep explicit tooltips`，递归扫描 `lib/` 下所有 `IconButton` 和 `PopupMenuButton` 构造调用，要求构造参数中包含 `tooltip:`，防止后续新增裸 icon-only 操作。阅读器 PDF 快捷工具按钮原先由外层 Tooltip + Semantics 提供语义，本轮同步给内部 `IconButton.filledTonal` 增加 `tooltip`，让控件自身也满足自动化规则。单独运行 `flutter test test/tool/release_readiness_test.dart` 8 项通过。
阻塞问题：该记录证明静态层面没有缺失 tooltip 的 IconButton/PopupMenuButton，不等于 TalkBack、Windows Narrator、焦点顺序、语义树朗读文案、触控目标或系统字体放大的人工可访问性验收完成。自定义非 IconButton 的图标操作仍需通过代码审计和屏幕阅读器复验。
```

```text
日期：2026-07-04
提交或版本：本地工作树，键盘焦点与方向键列表导航
平台：Windows 开发环境自动化检查和代码审计
验证人：Codex
样本：阅读器 CallbackShortcuts、EPUB 渲染器翻页键、书库分类树方向键、搜索结果列表方向键、笔记列表方向键、对话框/底部抽屉默认 Esc 关闭路径；搜索和笔记列表新增 Up/Down 焦点迁移
结果：dart format . 通过；flutter analyze 通过；flutter test 92 项通过。阅读器保留 Ctrl+F、Ctrl+Shift+F、Ctrl+B、Ctrl+G、Ctrl+Plus/Minus/0 和 Esc；搜索结果与笔记列表支持方向键移动焦点，Enter/Space 继续走现有激活路径。
阻塞问题：尚未完成真实 Windows 键盘走查，包括 Tab 视觉顺序、弹窗焦点限制、所有快捷键和实际 Esc 关闭层级；尚未在 Android 外接键盘场景验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器桌面快捷键焦点入口和行为回归
平台：Windows 开发环境 widget test
验证人：Codex
样本：ReaderPage 1280px x 800px、受控 PDF fake renderer、recording BookmarkRepository、Ctrl+F、Esc、Ctrl+B、Ctrl+G
结果：新增测试 `desktop reader keyboard shortcuts open panels and actions`，先暴露 ReaderPage 虽有 CallbackShortcuts 但页面自身没有 autofocus Focus 节点时，桌面快捷键不会进入快捷键查找链的问题；已将 ReaderPage 的 Scaffold 包进 `Focus(autofocus: true)`，使阅读器打开后无需额外点击即可响应页面级快捷键。测试验证 Ctrl+F 打开桌面右侧“本书搜索”上下文栏，Esc 关闭上下文栏，Ctrl+B 在当前 PDF 第 3 页保存书签并显示“已添加书签”，Ctrl+G 打开“跳转页码”对话框。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 138 项通过。
阻塞问题：该记录证明受控 widget 环境中的阅读器快捷键行为，不等于真实 Windows 键盘完整走查；仍需人工验证 Tab 视觉顺序、弹窗焦点限制、Ctrl+O、Ctrl+Shift+F、Ctrl+Plus/Minus/0、Left/Right、PageUp/PageDown、真实 PDF/EPUB renderer 焦点竞争，以及 Android 外接键盘场景。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器桌面全局搜索和 PDF 缩放快捷键回归
平台：Windows 开发环境 widget test
验证人：Codex
样本：ReaderPage 1280px x 800px、GoRouter 测试壳、受控 PDF fake renderer、recording SettingsRepository、Ctrl+Shift+F、Ctrl+Plus、Ctrl+Minus、Ctrl+0
结果：新增测试 `desktop reader keyboard shortcuts navigate search and zoom PDF`。测试先覆盖 ReaderPage 在 GoRouter 环境中按 Ctrl+Shift+F 能从阅读器跳转到 `/search` 并渲染 SearchPage；随后覆盖 PDF 阅读器中 Ctrl+Plus 将 pdfScale 从 1.2 保存为 1.3 并显示“缩放 130%”，Ctrl+Minus 保存回 1.2 并显示“缩放 120%”，Ctrl+0 保存 pdfScale=1、pdfZoomMode=actual 并显示“已恢复默认阅读比例”。修复 Ctrl+Shift+F 在测试键盘事件下不稳定的问题：保留显式 Ctrl+Shift+F 绑定，并增加字符级 `CharacterActivator('F', control: true)` 兜底，同时根 Focus 显式处理 Ctrl+Shift+F，确保桌面键盘入口能到达全局搜索。
阻塞问题：该记录证明受控 widget/GoRouter 环境中的快捷键行为，不等于真实 Windows 前台窗口、真实 PDF.js/EPUB renderer 焦点竞争、物理键盘布局差异、Tab 顺序、Left/Right/PageUp/PageDown 翻页或 Android 外接键盘人工验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，高对比主题命中与标注修复
平台：Windows 开发环境自动化检查和代码审计
验证人：Codex
样本：AppTheme.highContrast、ReaderThemePreset.contrast、EPUB 搜索命中、EPUB 标注颜色、全局搜索 mark 片段高亮代码路径
结果：dart format . 通过；flutter analyze 通过；flutter test 92 项通过。应用高对比主题使用黑白文字、黑色边界和蓝色强调；EPUB 高对比阅读主题下搜索命中改为不透明黄色，标注色改为更实的浅色；全局搜索命中在高对比环境下使用不透明黄色背景，不再依赖低透明度 warning 色块。
阻塞问题：尚未完成浅色、暗色、纸张、护眼、墨水屏、高对比主题截图；尚未用真实 EPUB/PDF 和系统高对比设置做人工可读性验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，主题与阅读器配色 WCAG 对比度回归测试
平台：Windows 开发环境 unit test
验证人：Codex
样本：test/app/theme/app_theme_contrast_test.dart；AppTheme.light/dark/eyeCare/highContrast；ReaderThemePreset 全部预设；AppColorScheme statusInfo/statusWarning/aiAccent 语义色
结果：新增对比度测试覆盖应用主题的 surface、pageBackground、surfaceSubtle、accentSubtle、error、warning、info、AI accent 文字组合，以及阅读器全部预设的正文和链接颜色组合，要求普通文本对比度 >= 4.5。修复暗色主题下直接使用亮色 warning/AI token 导致状态色前景对比不足的问题，组件改用主题感知的 statusWarning、statusInfo 和 aiAccent。单独运行 `flutter test test/app/theme/app_theme_contrast_test.dart` 15 项通过。
阻塞问题：该记录只证明 token 级颜色组合满足自动化 WCAG AA 计算；不等于真实页面截图、半透明高亮叠加、系统高对比模式、Windows Narrator、TalkBack 或真实 EPUB/PDF 阅读场景可读性人工验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，长文本、窄屏和字体缩放布局修复
平台：Windows 开发环境自动化检查和 widget test
验证人：Codex
样本：AppPageHeader 360px 宽、1.5 倍字体、长标题和多操作按钮；TaskCenterPage 360px 宽、1.4 倍字体、长文件路径和长任务消息；现有单元/组件测试
结果：dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 94 项通过。页面标题区在窄屏或字体放大时会把操作区换到标题下方并用 Wrap 排列；任务中心长标题和长消息限制为两行省略，状态与操作按钮换行排列，不再挤在同一行。
阻塞问题：该记录只覆盖新增自动化样本和相关代码路径；尚未完成 Windows 1440px/1024px/768px/600px、Android 360px/412px 的真实截图；尚未用系统字体放大、真实长书名、多标签、长搜索词和屏幕阅读器做完整人工走查。
```

```text
日期：2026-07-04
提交或版本：本地工作树，发布前文档引用和截图准备检查
平台：Windows 开发环境静态检查和运行中应用截图尝试
验证人：Codex
样本：docs 下所有 Markdown 本地链接；assets/images/store/ 发布截图目录；运行中的 Windows PageSage 窗口
结果：docs 下 Markdown 本地链接检查通过，未发现失效的相对链接；assets/images/store/ 已存在并被 pubspec.yaml assets 配置包含。尝试通过桌面区域截图、窗口句柄截图和 PrintWindow 采集 PageSage 窗口，但桌面区域截图捕获到前台 Edge，PrintWindow 只能捕获窗口外壳和空白内容，因此未保留任何发布截图产物。
阻塞问题：发布截图仍未完成；需要在可控前台窗口或真实设备上手动采集新版 UI 截图，至少覆盖书库、阅读器、搜索、Notebook、AI、设置和任务中心，并覆盖 Windows 1440px/1024px/768px、Android 360px 和主要主题。
```

```text
日期：2026-07-04
提交或版本：本地工作树，非空书库窄屏长标题布局修复
平台：Windows 开发环境 widget test
验证人：Codex
样本：PageSageApp 360px 宽、1.4 倍字体、非空书库、超长中文书名、长作者、EPUB/PDF 混合、索引 failed/running 状态
结果：新增测试先发现移动端书库网格卡片中的默认封面占位在小尺寸和字体放大时发生 RenderFlex bottom overflow；已将 _BookCover 占位改为约束感知，小封面或字体放大时只显示紧凑图标，大封面继续显示格式文字。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 95 项通过。
阻塞问题：该记录证明非空书库窄屏长标题和默认封面占位的自动化样本已修复；仍未覆盖真实设备触控、多标签真实数据、Windows 多宽度截图、Android 360px/412px 实机截图和系统字体设置人工走查。
```

```text
日期：2026-07-04
提交或版本：本地工作树，搜索页长搜索词和长结果窄屏覆盖
平台：Windows 开发环境 widget test
验证人：Codex
样本：PageSageApp 360px 宽、1.4 倍字体、从书库进入搜索页、超长中文搜索词、长搜索结果标题、长高亮片段、EPUB locator、长标签数据源
结果：新增搜索页 widget test 通过，覆盖 SearchBar 输入、筛选栏、索引状态提示、搜索结果标题省略、RichText 高亮片段渲染和结果操作菜单所在卡片布局；dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 96 项通过。本轮未发现搜索页窄屏大字体 RenderFlex overflow。
阻塞问题：该记录只覆盖受控 fake 数据和 widget 渲染；尚未用真实 FTS 索引、真实长标签/分类/书名、Windows 多宽度截图、Android 实机输入法和系统字体放大做人工验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，笔记页标题区现代化和长笔记窄屏覆盖
平台：Windows 开发环境 widget test
验证人：Codex
样本：NotesPage 使用 AppPageHeader 替代默认 AppBar；PageSageApp 360px 宽、1.4 倍字体、长书名筛选数据、长摘录笔记标题、长原文摘录、长笔记内容、移动端笔记列表
结果：笔记页顶部已改为统一 PageHeader 和“新建笔记”命令按钮，加载/错误态也使用同一标题区；笔记卡片标题限制为 2 行省略，尾部类型标签增加最大宽度和省略。新增 widget test 通过，覆盖移动端从底部导航进入笔记页、长笔记卡片渲染和标题区显示；dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 97 项通过。
阻塞问题：该记录只覆盖移动端受控 fake 数据；尚未用真实 Notebook 数据、桌面左列表右预览、多标签筛选、编辑/删除/跳转原文和屏幕阅读器做人工验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，设置移动二级页标题区现代化
平台：Windows 开发环境 widget test
验证人：Codex
样本：SettingsPage 360px 宽、1.4 倍字体、移动端设置分组列表、阅读设置二级页、返回设置按钮、ReaderSettings 默认项
结果：设置移动二级页已用 AppPageHeader + tooltip 返回按钮替代默认 AppBar，标题、副标题和返回操作与主页面标题区规范一致。新增 widget test 通过，覆盖从底部导航进入设置、打开阅读分组、二级页标题区和默认字号控件显示；dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 98 项通过。
阻塞问题：该记录只覆盖阅读分组和受控 fake 设置数据；尚未用真实 AI 设置、分类/标签维护、导出/备份/恢复入口、返回栈、Windows 多宽度和 Android 真机做人工验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，任务详情窄屏长文本布局修复
平台：Windows 开发环境 widget test
验证人：Codex
样本：TaskCenterPage 360px 宽、1.4 倍字体、长源路径、长目标路径、长任务消息、任务操作菜单、任务详情底部面板
结果：任务详情 _DetailRow 在窄屏或字体放大时改为 label/value 垂直布局，避免固定 72px 标签列挤压长路径和长消息；widget test 已打开任务操作菜单并进入“查看详情”，覆盖详情底部面板的来源、目标和任务详情显示；dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 98 项通过。
阻塞问题：该记录只覆盖受控长文本样本；尚未用真实导入、索引、导出、备份、恢复任务和实际取消/失败错误详情做 Windows/Android 人工验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，短窗口大字体底部溢出修复
平台：Windows 开发环境 widget test + Windows debug build
验证人：Codex
样本：PageSageApp 360px x 640px、1.5 倍字体、移动端书库底部导航、非空书库卡片、笔记页新建笔记弹窗
结果：移动端 MainShell 底部导航在字体放大时提高高度，避免短窗口中 NavigationBar 标签触发 bottom overflow；笔记编辑弹窗改为受最大高度约束的可滚动内容，短窗口下压缩原文摘录和正文输入框行数，确保“内容”和“保存”操作仍可见。新增 widget test 覆盖短窗口书库底部导航和笔记新建弹窗，相关测试通过；Windows Debug 版已重新构建并启动。
阻塞问题：该记录覆盖受控 widget 场景和 Windows debug 构建，不等于 Android 真机输入法弹出、系统字体缩放、真实触控、屏幕阅读器或所有弹窗/底部抽屉的人工验收完成；搜索、设置、阅读器和 AI 面板仍需继续做真实短窗口走查。
```

```text
日期：2026-07-04
提交或版本：本地工作树，设置页短窗口大字体表单和弹窗修复
平台：Windows 开发环境 widget test
验证人：Codex
样本：PageSageApp 360px x 640px、1.5 倍字体、移动端设置 AI 分组、分类与标签分组、新建标签弹窗；设置页删除所有本地数据、删除分类、新建/编辑标签弹窗代码路径
结果：AI 设置底部操作从固定 Row 改为可换行 Wrap，短窗口大字体下“连接测试”和“保存 AI 设置”仍可见；设置页危险操作、删除分类、新建/编辑标签弹窗统一使用受高度约束的可滚动内容，避免长说明、颜色 chip 和表单字段在短窗口中挤压操作按钮。新增 widget test 覆盖移动端 AI 设置和新建标签弹窗，单独运行 `flutter test test/widget_test.dart --name "mobile settings AI and tag"` 通过。
阻塞问题：该记录覆盖受控 fake 数据和 Flutter widget 布局，不等于 Android 真机输入法弹起、系统字体放大、真实分类/标签维护、清空数据危险操作、Windows Narrator/TalkBack 或真实触控人工验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，搜索页短窗口大字体结果操作修复
平台：Windows 开发环境 widget test
验证人：Codex
样本：PageSageApp 360px x 640px、1.5 倍字体、移动端搜索页、索引失败状态横幅、长搜索结果、搜索结果操作菜单、“对片段提问”弹窗
结果：移动端大字体下主导航高度进一步提高；搜索结果列表 compact 底部留白增加，滚动后结果操作不被底部导航遮挡；索引状态横幅在窄屏下使用纵向状态说明和可换行操作按钮；“对片段提问”、笔记详情和 AI 记录弹窗使用受高度约束的可滚动内容。新增 widget test 覆盖短窗口搜索、索引失败横幅、结果操作菜单和 AI 提问弹窗，单独运行 `flutter test test/widget_test.dart --name "search result actions fit"` 通过。
阻塞问题：该记录证明受控搜索结果在 widget 环境中可滚动访问操作并打开弹窗；不等于真实 FTS 索引、真实键盘/输入法、Android 真机触控、真实 AI Provider、保存笔记后的 Notebook/Search 视觉一致性或屏幕阅读器人工验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器移动短窗口大字体底部控制和 AI 面板修复
平台：Windows 开发环境 widget test
验证人：Codex
样本：ReaderPage 360px x 640px、1.5 倍字体、受控 EPUB fake renderer、长书名、长章节标题、移动端阅读器底部控制条、Notebook 底部抽屉、AI 底部面板
结果：移动阅读器底部状态区从固定 Row 改为位置文本与状态 chip 分层换行，减少长章节标题和字体放大时的横向挤压；底部动作按钮改为稳定 52px 宽高触控单元，360px 下目录、搜索、书签、Notebook、AI、设置均可见可点；阅读设置、EPUB/PDF 目录、Notebook 和 AI 底部面板统一使用 90% 屏高的 scroll-controlled sheet；AI 面板改为内容区滚动、底部发送操作固定可见，短窗口下仍能看到“上下文范围”和“发送”。新增 widget test `mobile reader controls fit short large-text windows` 覆盖打开 Notebook 和 AI 面板；`dart format .` 通过且 0 个文件变更；`flutter analyze` 通过；`flutter test` 137 项通过。
阻塞问题：该记录覆盖受控 fake renderer 和 Flutter widget 布局，不等于 Android 真机触控、系统字体缩放、输入法弹起、真实 EPUB/PDF WebView 渲染、真实文本选择、真实 AI Provider、屏幕阅读器或 Windows/Android 真实截图验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，本地 EPUB/PDF 手动验收样本生成器
平台：Windows 开发环境自动化检查
验证人：Codex
样本：tool/generate_manual_samples.dart 生成到 .codex-run/samples/ 的 standard.epub、long-text.epub、image.epub、no-toc.epub、large.epub、standard-text.pdf、large-text.pdf、image-only.pdf、broken.pdf
结果：新增 docs/manual-samples.md 说明生成方式、样本用途和验收流程；新增 test/tool/generate_manual_samples_test.dart，验证标准 EPUB、长文本 EPUB、无目录 EPUB 能被 EpubDocumentLoader 读取，标准文本 PDF 能被 PdfTextExtractorService 提取 3 页文本，无文本层 PDF 返回 hasText=false；已本地生成 9 个样本文件。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 99 项通过。
阻塞问题：该记录证明本地样本库可重复生成，不等于真实人工验收完成；尚未在运行中的 PageSage 里逐个导入、打开、搜索、标注、保存进度、重启恢复；尚未用真实扫描版 PDF、带 outline PDF 或 Android 设备做人工检查。
```

```text
日期：2026-07-04
提交或版本：本地工作树，PDF 边界样本和 renderer server 自动化检查
平台：Windows 开发环境 unit test
验证人：Codex
样本：tool/generate_manual_samples.dart 生成的 standard-text.pdf、image-only.pdf、broken.pdf；PdfTextExtractorService；PdfRendererServer；test/renderers/pdf/pdf_renderer_server_test.dart；test/tool/generate_manual_samples_test.dart
结果：generate_manual_samples_test 现在不仅验证标准文本 PDF 可提取 3 页文本、image-only.pdf 返回 hasText=false，还验证 broken.pdf 触发解析失败，不再只证明损坏样本文件存在。新增 pdf_renderer_server_test，验证本地 PDF renderer server 对 /book.pdf 返回 application/pdf 和 accept-ranges，支持 bytes range 206、非法 range 返回 416 和 content-range，文件缺失时返回 404 与“PDF file not found”。单独运行 `flutter test test/renderers/pdf/pdf_renderer_server_test.dart test/tool/generate_manual_samples_test.dart` 2 项通过。
阻塞问题：该记录覆盖 PDF 文本提取边界和 renderer server 文件服务边界，不等于 PDF.js WebView 实际渲染、无文本层 UI 禁用态、损坏 PDF 阅读器错误面板、页码跳转、缩放、搜索、触控滚动或真实 PDF 人工验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器 PDF capability 和渲染失败 UI 状态测试
平台：Windows 开发环境 widget test
验证人：Codex
样本：ReaderPage、readerRendererHostProvider 测试注入点、RendererCapabilityChanged、RendererFailed、fake PDF book、fake renderer host
结果：新增 readerRendererHostProvider，默认仍使用真实 EPUB/PDF renderer，测试中可注入 fake renderer 事件。新增 widget test 覆盖 PDF renderer 回传 textSelection=false/search=false/reason=“此 PDF 没有可选择文本”时，ReaderPage 显示低噪声状态提示；覆盖 RendererFailed('PDF 文件结构不完整') 时，ReaderPage 显示“无法渲染书籍”错误面板、错误信息和“重试”操作，点击重试后显示“正在重新打开”。同时修复 ReaderPage dispose/lifecycle 期间直接使用 ref.read(readerSessionControllerProvider) 的 Riverpod 3 安全问题，改为 didChangeDependencies 缓存 ReaderSessionController。单独运行 `flutter test test/widget_test.dart` 9 项通过。
阻塞问题：该记录证明 ReaderPage 对 renderer capability/error 事件的 Flutter UI 状态处理，不等于真实 PDF.js WebView 在 Windows/Android 上触发这些事件、真实无文本层 PDF 禁用搜索/划词、损坏 PDF 文件打开失败流程或人工截图验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，受控 UI 截图生成脚本
平台：Windows 开发环境 widget 渲染
验证人：Codex
样本：test/ui_screenshots_test.dart 的受控书库、搜索、笔记、设置、任务、EPUB 阅读器 fake 数据；tool/capture_ui_screenshots.ps1；.codex-run/ui-screenshots/ 下 16 张 PNG
结果：新增截图包装脚本，先确保本地 EPUB/PDF 样本存在，再逐张运行截图测试、等待 PNG 非空并清理 Flutter test 残留进程。已生成 desktop-1440-library、desktop-1024-search、desktop-1024-notes、desktop-768-settings、desktop-768-tasks、desktop-600-library-large-text、mobile-360-library-large-text、mobile-360-notes-large-text、mobile-412-library-large-text、theme-dark-library、theme-high-contrast-search、reader-epub-desktop、reader-theme-paper-epub、reader-theme-green-epub、reader-theme-ink-epub、reader-theme-contrast-epub 共 16 张 PNG；使用 .NET 读取尺寸均符合命名视口且文件非空。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 100 项通过。
阻塞问题：本记录证明受控 fake 数据页面截图可重复生成，不等于真实前台应用截图或商店发布截图；仍未覆盖 Android 真机、Windows 真实窗口全路径、PDF WebView 页面、完整应用浅色主题全页面截图、夜间阅读主题截图和人工视觉审查。
```

```text
日期：2026-07-04
提交或版本：本地工作树，受控 PDF 阅读器和移动 AI 面板截图补充
平台：Windows 开发环境 widget 渲染截图 + 自动化检查
验证人：Codex
样本：test/ui_screenshots_test.dart；tool/capture_ui_screenshots.ps1；.codex-run/ui-screenshots/reader-pdf-desktop.png；.codex-run/ui-screenshots/mobile-360-reader-ai-large-text.png
结果：截图测试为 ReaderPage 注入 fake renderer 事件，使阅读器外壳、PDF 工具条、状态栏、左右 SidePanel 和移动 AI bottom sheet 能稳定截图，不再停留在真实 renderer 加载态。新增 reader-pdf-desktop 1440x960 受控截图，覆盖 PDF 桌面三栏、PDF 快捷工具条和右侧上下文面板；新增 mobile-360-reader-ai-large-text 360x640、1.5 倍字体受控截图，覆盖移动阅读器 AI 面板和固定底部发送操作。修复 AppSidePanel 使用带背景 DecoratedBox 包裹 ListTile 时触发的 Flutter ink 可见性断言，改为 Material 承载背景、DecoratedBox 只画边框；阅读器 bottom sheet 高度从 90% 调整为 86%，避免 showDragHandle、SafeArea 和大字体组合下再次挤压。使用 .NET 读取两张 PNG 尺寸均符合命名视口且文件非空；目视检查两张截图均非空白，移动 AI 面板底部“发送”可见。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 137 项通过。
阻塞问题：该记录仍属于 Flutter widget 渲染和 Ahem 测试字体截图，不等于真实 Windows 前台窗口截图、Android 真机截图、PDF.js WebView 实际渲染、真实触控、系统字体缩放、屏幕阅读器或商店发布截图完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，受控 UI 联系表生成器
平台：Windows 开发环境截图工具链 + 静态检查
验证人：Codex
样本：tool/build_ui_contact_sheet.ps1；tool/capture_ui_screenshots.ps1；.codex-run/ui-screenshots/contact-sheet.png；test/tool/release_readiness_test.dart
结果：新增联系表生成脚本，读取 .codex-run/ui-screenshots 下除 contact-sheet.png 外的全部 PNG，按固定缩略图宽度和文件名标签输出 contact-sheet.png；capture_ui_screenshots.ps1 在逐张截图完成后自动调用该脚本。当前联系表由 14 张受控截图生成，包含新增 reader-pdf-desktop 和 mobile-360-reader-ai-large-text；生成结果尺寸为 1106 x 4762，文件非空。新增 release_readiness_test 静态检查，要求截图工具链包含 reader-pdf-desktop、mobile-360-reader-ai-large-text 和 build_ui_contact_sheet.ps1，防止关键响应式视图从默认截图流程中丢失。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 139 项通过。
阻塞问题：联系表仍由 Flutter widget 截图组成，使用测试字体，不能替代真实 Windows/Android 前台截图、商店发布截图、真实 PDF.js WebView 渲染、真实触控或人工视觉最终验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，受控 UI 截图联系表人工审查
平台：Windows 开发环境 widget 渲染截图人工审查
验证人：Codex
样本：.codex-run/ui-screenshots/contact-sheet.png，包含书库、搜索、笔记、设置、任务、移动窄屏、深色书库、高对比搜索、EPUB 阅读器外壳共 12 张受控截图
结果：联系表人工检查未发现书库、搜索、笔记、设置、任务、移动 360/412 和 600px 书库截图存在明显重叠、错位、大面积空白或按钮溢出；深色书库和高对比搜索的结构可辨识，状态 chip 与主要操作区域没有明显遮挡。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 100 项通过。
阻塞问题：Flutter widget screenshot 默认使用 Ahem 测试字体，文本呈方块，不能作为最终文字视觉质量、字体渲染或商店截图证据；EPUB 阅读器截图仍停留在加载态，只能证明阅读器外壳和侧栏结构，不能证明 EPUB 正文、主题、标注或滚动体验；仍需真实 Windows/Android 前台窗口和真实 EPUB/PDF 人工验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，真实 Windows 前台窗口截图尝试
平台：Windows 运行中 PageSage 桌面应用
验证人：Codex
样本：tool/capture_windows_app_screenshot.ps1；flutter run -d windows 启动的 PageSage 窗口；.codex-run/windows-screenshots/windows-1440-current-topmost.png 与 windows-1440-fresh-run.png；Dart Widget Inspector
结果：新增 Windows 前台窗口截图脚本，使用 Win32 ShowWindow、MoveWindow、SetWindowPos、SetForegroundWindow 和 CopyFromScreen 捕获真实窗口区域，并写入 JSON 元数据。脚本能捕获 1440x960 PageSage 窗口外壳；Widget Inspector 显示运行中 Flutter 树已渲染到 MainShell、LibraryPage、书库列表和真实文本节点；flutter analyze/test 外的运行时错误检查未发现 runtime errors。dart format . 通过且 0 个文件变更；flutter analyze 通过；flutter test 100 项通过。
阻塞问题：CopyFromScreen 捕获到的 PageSage 内容区域仍是白屏，只显示窗口标题栏和底层 Edge 侧边缘；Flutter CLI `flutter screenshot -d windows` 返回 Windows 不支持截图。因此当前仍没有可接受的真实 Windows 前台应用截图，发布截图验收不能通过。需要用户可见前台手动截图、Windows Graphics Capture/平台插件截图方案，或在真实设备上人工采集。
```

```text
日期：2026-07-04
提交或版本：本地工作树，本地 EPUB/PDF 导入与进度持久化数据闭环
平台：Windows 开发环境自动化检查
验证人：Codex
样本：tool/generate_manual_samples.dart 生成的 standard.epub 与 standard-text.pdf；真实 ImportUseCase、DriftBookRepository、DriftSearchRepository、DriftTaskRepository、SearchIndexer；临时文件型 SQLite 数据库
结果：新增 test/features/import/import_use_case_test.dart 覆盖生成样本导入、复制到 PageSageData/library、原始文件保留、EPUB/PDF book 记录写入、导入索引任务完成、保存 EPUB chapter/href/offset 进度和 PDF page/scroll/zoom 进度、关闭并重新打开数据库后重新读取 book 和 reading_progress。单独运行 `flutter test test/features/import/import_use_case_test.dart` 通过，2 项测试通过。
阻塞问题：该记录只证明本地数据路径的 MVP 闭环，不证明真实阅读器渲染、用户操作导航、前后台生命周期自动保存或 Windows/Android 真实应用重启恢复；仍需在运行中的 PageSage 中导入、打开、滚动/翻页、关闭应用并重新打开同一本 EPUB/PDF 做人工验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，桌面导入命令与 Ctrl+O 快捷键修复
平台：Windows 开发环境 widget test
验证人：Codex
样本：MainShell 桌面命令栏、全局 CallbackShortcuts、ReaderPage Ctrl+O、LibraryPage 导入意图监听、fake FilePickerService
结果：桌面命令栏“导入”和全局 Ctrl+O 现在都会发起同一个导入意图，由书库页复用现有 pickAndImportMany、重复文件处理和导入结果提示；阅读器 Ctrl+O 也会返回书库并触发导入，不再只是导航到书库。新增 widget test 覆盖点击导入图标与 Ctrl+O 后打开 EPUB/PDF 多选文件选择请求；`flutter test test/widget_test.dart` 通过，6 项测试通过；`flutter analyze` 通过。
阻塞问题：该记录证明快捷键和命令栏能触发文件选择请求，不等于真实 Windows 文件选择器、重复导入弹窗、导入后打开书籍和焦点恢复的完整人工验收；仍需 Windows 键盘全路径走查和 Android 外接键盘验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，设置页关于、隐私说明和许可说明入口
平台：Windows 开发环境 widget test
验证人：Codex
样本：SettingsPage 移动端设置分组、“关于”二级页、隐私说明弹窗、开源许可说明弹窗、Flutter 许可证入口；docs/privacy.md 与 docs/licenses.md 的发布规则摘要
结果：设置页新增“关于”分组，移动端和桌面端导航都可进入；关于页显示版本、本地优先定位、隐私说明入口、开源许可说明入口和 Flutter 许可证入口。新增 widget test 覆盖移动端进入设置、打开关于页、打开隐私说明弹窗并看到“默认不会自动上传整本书”、打开开源许可说明弹窗并看到 pubspec.lock 发布复核要求；`flutter test test/widget_test.dart` 通过，7 项测试通过。
阻塞问题：该记录证明入口和说明文本可见，不等于正式发布包已生成完整第三方许可清单；仍需发布前以 pubspec.lock 生成完整 licenses、检查 Android/Windows 包内许可文本，并进行真实设置页截图验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，发布资源边界和文档链接自动化检查
平台：Windows 开发环境 widget/unit test
验证人：Codex
样本：docs 下所有 Markdown 相对链接；pubspec.yaml assets；assets/renderer/pdf/；assets/images/brand、empty-states、covers、store；.gitignore；assets 目录中的 EPUB/PDF 文件扫描
结果：新增 test/tool/release_readiness_test.dart，验证 docs Markdown 本地相对链接均可解析；pubspec.yaml 包含 PDF renderer 和图片资源目录；PDF renderer 的 viewer.html、viewer.css、bridge.js、pdf.min.js、pdf.worker.min.js 均存在且非空；pubspec 不包含 .codex-run、manual-samples、.epub 或 .pdf；.gitignore 保持 .codex-run/；assets 下没有 EPUB/PDF 样本文件。单独运行 `flutter test test/tool/release_readiness_test.dart` 通过。
阻塞问题：该记录证明生产资源声明和样本边界的静态检查，不等于 Android/Windows release 包已实际构建并人工打开验证；仍需发布前构建包、确认 renderer assets 在包内、采集新版 UI 截图。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Windows debug 构建和打包资源检查
平台：Windows 开发环境 build + unit test
验证人：Codex
样本：flutter build windows --debug；build/windows/x64/runner/Debug/data/flutter_assets；PDF renderer assets；品牌、空状态和默认封面图片资源
结果：首次构建失败原因是运行中的 PageSage PID 88016 锁定 WebView2Loader.dll；关闭该窗口后 `flutter build windows --debug` 成功生成 build/windows/x64/runner/Debug/pagesage.exe。随后检查构建产物中的 flutter_assets，确认 assets/renderer/pdf/viewer.html、viewer.css、bridge.js、pdf.min.js、pdf.worker.min.js，以及 assets/images/brand/app-icon-source.svg、assets/images/empty-states/library-empty.svg、assets/images/covers/default.svg 均存在且非空。test/tool/release_readiness_test.dart 新增 Windows build output 检查，在本地已有 build 产物时会验证关键资源；单独运行 `flutter test test/tool/release_readiness_test.dart` 通过，2 项测试通过。
阻塞问题：该记录证明 Windows debug 构建和资源打包链路，不等于 Windows release 包、Android APK/AAB 或真实安装包人工验收；仍需 release 构建、Android 构建、真实打开 EPUB/PDF、发布截图和包内完整许可清单验证。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Android debug APK 构建和打包资源检查
平台：Windows 开发环境 Android debug build + unit test
验证人：Codex
样本：flutter build apk --debug；build/app/outputs/flutter-apk/app-debug.apk；APK 内 assets/flutter_assets；PDF renderer assets；品牌、空状态和默认封面图片资源
结果：Flutter 3.44.2 模板默认 AGP 9.0.1 会触发 flutter_inappwebview_android 1.1.3 的 getDefaultProguardFile('proguard-android.txt') 兼容错误；已将 android/settings.gradle.kts 的 com.android.application 调整为 8.13.2，并将 android/gradle/wrapper/gradle-wrapper.properties 调整为 Gradle 8.13。Android 官方 AGP 8.13.2 说明支持 Kotlin 2.3、默认 Gradle 8.13、最高 API level 36.1，符合当前项目 compileSdk 链路。随后 file_picker 在 Windows 跨盘 Pub cache 场景下触发 Kotlin 增量缓存相对路径错误，已在 android/gradle.properties 增加 kotlin.incremental=false 作为项目级构建 workaround。`flutter build apk --debug` 成功生成 app-debug.apk；新增 test/tool/release_readiness_test.dart 的 Android APK 检查，验证 APK 包含 assets/renderer/pdf/viewer.html、viewer.css、bridge.js、pdf.min.js、pdf.worker.min.js，以及品牌、空状态、默认封面图片资源，且 APK 内没有 .epub/.pdf 测试书籍。dart format . 通过；flutter analyze 通过；flutter test 106 项通过；单独运行 release_readiness_test 3 项通过。
阻塞问题：该记录证明 Android debug APK 构建和关键资源打包链路，不等于 Android 真机安装、Android 360px/412px 截图、Android release/AAB、真实 EPUB/PDF 阅读闭环或商店发布验收完成。当前 Gradle 8.13 会收到 Flutter “soon be dropped” 警告；file_picker 仍会收到 Built-in Kotlin 迁移警告，后续应在 flutter_inappwebview/file_picker 适配 AGP 9 和 Built-in Kotlin 后回到 Flutter 默认模板或升级到新的兼容构建线。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Android release APK 构建和资源边界检查
平台：Windows 开发环境 Android release build + unit test
验证人：Codex
样本：flutter build apk --release；build/app/outputs/flutter-apk/app-release.apk；test/tool/release_readiness_test.dart；APK 内 assets/flutter_assets
结果：`flutter build apk --release` 成功生成 app-release.apk，大小约 67.9MB。构建输出提示 MaterialIcons tree-shaking 生效；提示 Gradle 8.13 后续会被 Flutter 停止支持；提示 file_picker 仍使用插件侧 Kotlin Gradle Plugin，未来需要 Built-in Kotlin 迁移；Java 编译有 source/target 8 过时警告。release_readiness_test 已扩展为同时检查 Android debug 和 release APK，验证两种 APK 都包含 PDF renderer、品牌图片、空状态图片、默认封面图片，并确认包内没有 .epub/.pdf 测试书籍。`flutter test test/tool/release_readiness_test.dart` 4 项通过。
阻塞问题：该记录证明 Android release APK 可以构建且关键资源边界正确，但当前 release build 仍使用 debug signingConfig，不能作为正式商店签名包；尚未构建 AAB；尚未在 Android 真机/模拟器安装运行、采集 360px/412px 截图或完成真实 EPUB/PDF 阅读闭环；Gradle/Kotlin 兼容警告仍需在依赖升级后清理。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Android AAB 与 Windows release 构建资源检查
平台：Windows 开发环境 Android appbundle build + Windows release build + unit test
验证人：Codex
样本：flutter build appbundle --release；build/app/outputs/bundle/release/app-release.aab；flutter build windows --release；build/windows/x64/runner/Release/pagesage.exe；test/tool/release_readiness_test.dart
结果：`flutter build appbundle --release` 成功生成 app-release.aab，大小约 66.7MB；`flutter build windows --release` 成功生成 build/windows/x64/runner/Release/pagesage.exe。release_readiness_test 已扩展为检查 Windows Debug/Release 构建输出、Android debug/release APK 和 Android release AAB；当对应产物存在时，验证 PDF renderer、品牌图片、空状态图片、默认封面图片均已打包且非空，并确认 Android APK/AAB 内没有 .epub/.pdf 测试书籍。`flutter test test/tool/release_readiness_test.dart` 5 项通过。
阻塞问题：该记录证明 Android AAB 和 Windows release 包可以构建且关键资源存在，但仍不是完整发布验收：Android release/AAB 仍沿用 debug signingConfig；尚未在 Android 真机/模拟器安装运行；Windows release 尚未人工打开真实 EPUB/PDF；仍缺新版真实截图、屏幕阅读器验收、完整第三方许可清单生成和真实阅读闭环。构建仍有 Gradle 8.13 即将不受 Flutter 支持、file_picker Built-in Kotlin 迁移、Windows WebView 插件 CMake/C++ 编译警告。
```

```text
日期：2026-07-04
提交或版本：本地工作树，第三方许可清单和包内许可文本检查
平台：Windows 开发环境 doc generation + unit test
验证人：Codex
样本：tool/generate_third_party_licenses.dart；docs/generated/third-party-licenses.md；docs/licenses.md；pubspec.lock；Android debug/release APK；Android release AAB；Windows Debug/Release flutter_assets/NOTICES.Z
结果：新增许可清单生成工具，从 pubspec.lock 和 .dart_tool/package_config.json 生成 docs/generated/third-party-licenses.md，当前覆盖 128 个非 SDK 第三方依赖，列出 package、version、dependency、source 和本地包根 LICENSE/NOTICE 文件名，不写入本机绝对路径。docs/licenses.md 已指向生成清单和生成命令。release_readiness_test 新增检查：生成清单覆盖 pubspec.lock 中所有非 SDK package；生成清单不包含本机绝对路径或 API-key-like 值；Windows Debug/Release、Android debug/release APK、Android release AAB 均包含非空 NOTICES.Z；Android 包仍无 .epub/.pdf 测试书籍。`flutter test test/tool/release_readiness_test.dart` 6 项通过。
阻塞问题：该记录证明许可清单已可重复生成且包内 Flutter 许可文本存在，但仍需发布负责人在正式签名包生成后复核上游许可文本、NOTICES 内容和商店合规要求；当前不替代法律审查，也不证明真实安装包人工验收完成。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Android 模拟器响应式首屏截图
平台：Android Emulator Pixel_9a，emulator-5554，Android 16 API 36
验证人：Codex
样本：build/app/outputs/flutter-apk/app-debug.apk；dev.pagesage.app；.codex-run/android-screenshots/android-emulator-library.png；android-emulator-library-360dp.png；android-emulator-search-412dp.png；android-emulator-notes-412dp.png；android-emulator-tasks-412dp.png；android-emulator-settings-412dp.png；contact-sheet.png
结果：`flutter devices` 识别到 Android 模拟器；`adb install -r build/app/outputs/flutter-apk/app-debug.apk` 成功；通过 `adb shell monkey -p dev.pagesage.app` 启动后当前焦点为 `dev.pagesage.app/.MainActivity`。采集默认 1080 x 2424、density 420 的 412dp 档书库截图；临时设置 `wm size 945x2121` 采集约 360dp 档书库截图后恢复原始尺寸；通过底部导航触控切换并采集搜索、笔记、任务、设置 412dp 档截图。Android 联系表由 6 张截图生成，尺寸 468 x 6000，文件非空。目视检查：空书库主动作可见，底部导航不遮挡主要内容，搜索/笔记/任务/设置页面均成功渲染并能通过底部导航切换。
阻塞问题：该记录来自 Android 模拟器，不等于真实 Android 手机；只覆盖空书库和主导航页面，不覆盖真实导入 EPUB/PDF、阅读器真实 WebView、文本选择、输入法弹起、TalkBack、系统字体缩放、360/412 下阅读器底部抽屉或发布商店截图。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Android 模拟器真实导入与阅读器验证
平台：Android Emulator Pixel_9a，emulator-5554，Android 16 API 36，1080 x 2424，density 420
验证人：Codex
样本：.codex-run/samples/standard.epub；.codex-run/samples/standard-text.pdf；dev.pagesage.app debug build；.codex-run/android-screenshots/android-reader-epub.png；android-reader-pdf-final.png；android-reader-pdf-controls.png；window-before-epub.xml；window-epub-reader.xml；window-pdf-reader-final.xml；window-pdf-reader-controls.xml
结果：通过只在非 release 且显式 `--dart-define=PAGESAGE_VERIFY_IMPORT_PATHS=...` 时启用的验证入口调用真实 `ImportUseCase.importPath`，在 Android 应用私有目录中导入标准 EPUB 和标准文本 PDF；书库 UI 显示 2 本书，私有书库目录出现 EPUB/PDF 副本。打开 PDF 后真实 PDF.js WebView 渲染出第 2 页，错误面板消失，页面文本可见；书库返回后 PDF 进度显示 50%，证明 Android 真实阅读位置已保存。打开 EPUB 后真实 EPUB 阅读器显示章节正文、上一章/下一章控件和隐藏式阅读控制。修复了 Android PDF renderer 初始化时过早调用 JS bridge 导致 `Cannot read properties of undefined (reading 'applyAnnotations')` 的问题；修复 Android release/main manifest 缺少网络权限和本地 cleartext loopback 配置导致 PDF renderer server 无法稳定加载的问题；修复移动 PDF HTML 工具栏窄屏挤压问题；移动阅读器底部 `Notebook` 标签改为 `笔记`，避免窄屏省略。
阻塞问题：该记录来自 Android 模拟器，不等于真实 Android 手机；导入入口为受控验证入口，不替代系统文件选择器人工导入；尚未完成 EPUB/PDF 文本选择、标注、笔记、AI 底部抽屉、目录/搜索底部抽屉、输入法弹出、TalkBack、系统字体缩放、横屏/平板、关闭进程后重新打开恢复位置的完整人工验收。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Android 模拟器阅读器深水区补验
平台：Android Emulator Pixel_9a，emulator-5554，Android 16 API 36，1080 x 2424，density 420
验证人：Codex
样本：.codex-run/samples/standard.epub；.codex-run/samples/standard-text.pdf；dev.pagesage.app debug build；.codex-run/android-screenshots/android-epub-selection-attempt2.png；android-epub-highlight-added.png；android-epub-notebook-with-annotation.png；android-epub-annotation-menu.png；android-epub-annotation-saved-note.png；android-pdf-controls-deep.png；android-pdf-toc-fast.png；android-pdf-after-toc-jump-page1.png；android-pdf-bookmark-added.png；android-pdf-search-open.png
结果：EPUB 真实正文长按可弹出 PageSage 选中文本底部面板，面板包含高亮、笔记、复制、AI、下划线和搜索操作；点击高亮后正文出现黄色标注并提示“已添加标注”；Notebook 底部抽屉显示同一本书的书签、标注和由标注菜单“保存为笔记”生成的笔记条目。PDF 真实 PDF.js 阅读器可从第 3 页恢复并显示第 3/3 页、100%、120% 等状态；PDF 底部工具显示跳转页码、缩小、放大、适合宽度、适合页面、搜索 PDF 和添加书签；PDF 页码抽屉显示第 1、2、3 页且当前第 3 页高亮，点击第 1 页后真实跳转到 PDF 第 1 页；点击添加书签后控制条状态变为“取消书签”。此前 `android-restart-library.png` 和 `android-restart-pdf-restored.png` 已证明 force-stop 后重新打开 PDF 可恢复到保存页附近。
阻塞问题：该记录仍来自 Android 模拟器，不等于真实 Android 手机。PDF/EPUB 搜索抽屉可打开，EPUB renderer 搜索高亮曾出现在正文中，但模拟器 Gboard 反复弹出 “Try out your stylus” 引导，阻止关键词稳定进入 PageSage 搜索输入框，因此搜索结果列表、保存搜索结果为笔记、PDF 搜索命中列表暂不勾选。PDF Notebook 抽屉在本轮受控制条自动隐藏和 snackbar 干扰未稳定截图，但 PDF 书签状态已由“取消书签”证明。AI 面板和正式发布签名按当前用户指示暂缓，不作为本轮打包阻塞项。
```

```text
日期：2026-07-04
提交或版本：本地工作树，Android 模拟器 PDF 本书搜索补验
平台：Android Emulator Pixel_9a，emulator-5554，Android 16 API 36，1080 x 2424，density 420
验证人：Codex
样本：.codex-run/samples/standard-text.pdf；dev.pagesage.app debug build；.codex-run/android-screenshots/android-search-keyevent.png；android-pdf-search-result-menu.png；android-pdf-search-save-note-2.png
结果：在模拟器 secure settings 中临时关闭 `stylus_handwriting_enabled`、`stylus_handwriting_default_enabled` 和 `stylus_handwriting_pref` 后，PDF 本书搜索输入框可以通过硬键盘 keyevent 输入 `pagesage`；搜索抽屉显示 `1/3` 分页结果、三条可见结果卡片和“跳转”按钮，PDF 正文中的命中词以黄色高亮显示。搜索结果操作菜单可打开，显示“保存为笔记”和“对片段提问”两项；AI 相关“对片段提问”按当前用户指示暂缓。
阻塞问题：该记录仍来自 Android 模拟器；保存搜索结果为笔记执行后未捕获到明确“已保存为笔记”提示或可见 Notebook 新条目，因此不把该动作记为完成。关闭 stylus handwriting 是模拟器验收环境处理，不代表真实手机输入法行为已覆盖；仍需真实设备或无该引导的输入法再次验证 EPUB/PDF 搜索输入、结果保存为笔记和输入法弹起布局。
```

```text
日期：2026-07-04
提交或版本：本地工作树，本书搜索结果保存为笔记回归
平台：Windows 开发环境 widget test
验证人：Codex
样本：ReaderPage 1280px x 1000px、受控 EPUB fake renderer、fake SearchRepository、recording NoteRepository、Ctrl+F 本书搜索、搜索结果保存为笔记
结果：本书搜索结果操作从底部易受遮挡的 PopupMenu 改为结果行内直接 icon 操作，“保存搜索结果为笔记”和“对搜索结果片段提问”均带 tooltip，减少一次点击并避免结果靠近面板底部时菜单不可点。新增 widget test `reader in-book search result saves as excerpt note`，验证 Ctrl+F 打开本书搜索、输入关键词后出现结果、点击“保存搜索结果为笔记”会创建 NoteType.excerpt 笔记，bookId、title、locator、sourceText 正确，snippet 中 `<mark>` 被清理，并显示“已保存为笔记”。单独运行 `flutter test test/widget_test.dart --name "reader in-book search result saves"` 通过。
阻塞问题：该记录证明受控 Flutter widget 环境中的保存闭环和菜单 UX 修复，不等于 Android 真机、真实 EPUB/PDF renderer、真实输入法、系统文件导入样本、Notebook 可见新条目截图或全局搜索页“保存片段为笔记”的完整人工验收完成。此前 Android 模拟器 PDF 搜索保存为笔记未稳定捕获的记录仍需在真机或无输入法引导干扰的环境复验。
```

```text
日期：2026-07-04
提交或版本：本地工作树，全局搜索结果保存片段为笔记回归
平台：Windows 开发环境 widget test
验证人：Codex
样本：SearchPage 1024px x 760px、fake SearchRepository、recording NoteRepository、受控搜索结果、搜索片段保存为笔记
结果：全局搜索结果将“保存搜索片段为笔记”和“对搜索片段提问”提升为结果行内直接 icon 操作，二者均带 tooltip；更多菜单只保留打开来源、复制片段和重建本书索引等次级动作，避免保存/提问被 popup 菜单点击区域影响。新增 widget test `global search result saves snippet as excerpt note`，验证输入关键词后出现搜索结果，点击“保存搜索片段为笔记”会创建 NoteType.excerpt 笔记，bookId、title、locator、sourceText 正确，snippet 中 `<mark>` 被清理，并显示“已保存为笔记”。同时更新短窗口大字体搜索动作测试，改为直接点击“对搜索片段提问”；单独运行 `flutter test test/widget_test.dart --name "global search result saves|search result actions fit"` 通过。
阻塞问题：该记录证明受控 fake 搜索结果中的保存闭环和搜索结果动作 UX 修复，不等于真实 FTS 索引、真实书库分组准确性、Notebook 可见新条目、Android 真机输入法、屏幕阅读器或真实 Windows/Android 截图验收完成。AI 真实 Provider 仍按当前用户指示暂缓。
```

```text
日期：2026-07-04
提交或版本：本地工作树，阅读器主题受控样张截图补验
平台：Windows 开发环境 widget 渲染截图 + 人工目视检查
验证人：Codex
样本：tool/capture_ui_screenshots.ps1；test/ui_screenshots_test.dart；.codex-run/ui-screenshots/reader-theme-paper-epub.png；reader-theme-green-epub.png；reader-theme-ink-epub.png；reader-theme-contrast-epub.png；contact-sheet.png
结果：默认截图流程已纳入纸张、护眼、墨水屏和高对比四个阅读器主题，并在 release_readiness_test 中增加静态检查，防止关键主题截图从默认工具链中丢失。原先主题截图只显示背景和加载指示器，已改为受控阅读器主题样张，稳定展示主题背景、正文、链接和高亮标注。重新生成 4 张主题 PNG 和 18 张截图联系表，文件非空；目视检查未发现主题样张大面积空白、loading 停留、正文/链接/高亮遮挡或明显溢出。
阻塞问题：该记录仍属于 Flutter widget 渲染截图，使用测试字体，不等于真实 EPUB renderer 正文、Android 真机、Windows 前台窗口、系统高对比模式、屏幕阅读器或商店发布截图验收完成。浅色/暗色全页面真实主题走查、PDF 阅读器主题影响、主题切换后阅读位置稳定性仍需后续人工验证。
```


```text
日期：2026-07-16
提交或版本：本地工作树，P0–P4 工程推进（封面/壳层/发布工具）
平台：Windows 开发环境自动化检查
验证人：Claude
样本：widget_test、export 备份单测、metadata_extractor 封面单测、主题对比度测试
结果：flutter analyze（相关路径）无 error；关键自动化测试通过。
阻塞问题：完整手动双端真实样本闭环、大库性能与 Android 实机仍待人工勾选 m4-release-checklist。
```

## 3. 响应式截图

### 3.1 Windows

窗口宽度：

- [ ] 1440px。
- [ ] 1024px。
- [ ] 768px。
- [ ] 极窄窗口，约 600px。

页面：

- [ ] 书库。
- [ ] 阅读器 EPUB。
- [ ] 阅读器 PDF。
- [ ] 搜索。
- [ ] 笔记。
- [ ] 设置。
- [ ] 任务中心。
- [ ] AI 面板。

检查：

- [ ] 无文字重叠。
- [ ] 无按钮溢出。
- [ ] 面板宽度合理。
- [ ] 当前选中态清晰。
- [ ] 主要操作可见。

### 3.2 Android

视口：

- [x] 手机 360px 宽。
- [x] 手机 412px 宽。
- [ ] 平板或横屏，若有设备。

检查：

- [x] 底部导航不遮挡主要内容。
- [x] 阅读器工具栏可隐藏。
- [ ] 底部抽屉可完成目录、搜索、Notebook 和 AI。
- [ ] 触控目标不小于 48 x 48。
- [ ] 长标题和长标签不撑破布局。

## 4. 主题检查

主题：

- [ ] 浅色。
- [ ] 暗色。
- [ ] 纸张。
- [ ] 护眼。
- [ ] 墨水屏。
- [ ] 高对比。

页面：

- [ ] 书库。
- [ ] 阅读器 EPUB。
- [ ] 阅读器 PDF。
- [ ] 搜索结果。
- [ ] Notebook。
- [ ] AI 面板。
- [ ] 设置。

检查：

- [ ] 正文对比度可读。
- [ ] 标注不影响文字识别。
- [ ] 搜索命中高亮可见。
- [ ] 禁用状态和错误状态不只依赖颜色。
- [ ] 焦点样式清晰。

```text
日期：2026-07-04
提交或版本：本地工作树，Android release APK 系统文件选择器导入验收
平台：Android 模拟器 Pixel_9a / emulator-5556
验证人：Codex
样本：D:\Chaos\Downloads\穷查理宝典 .epub；D:\Chaos\Downloads\穷查理宝典 .pdf；模拟器内路径 /sdcard/Download/pagesage-charlie.epub 和 /sdcard/Download/pagesage-charlie.pdf
结果：重新构建并安装 release APK 后，从空书库点击“导入 EPUB/PDF”进入 Android DocumentsUI 系统文件选择器；在 Downloads 中选择 pagesage-charlie.epub 后返回 PageSage，书库显示 1 本《穷查理宝典（珍藏版）（1+2册）》且出现“已导入”提示；再次通过同一系统文件选择器选择 pagesage-charlie.pdf 后返回 PageSage，书库显示 2 本，包含 PDF 和 EPUB 两张书籍卡片。截图和 UI dump 保存在 `.codex-run/android-screenshots/picker-*.png` 与 `window-*.xml`。
阻塞问题：本记录证明 Android 模拟器系统文件选择器导入 EPUB/PDF 成功，不等于真实 Android 手机文件管理器、重复导入副本策略、删除不影响原文件、导入后完整阅读闭环、长时间索引完成状态或真实触控人工验收全部完成。
```

## 5. 书库验收

数据状态：

- [ ] 空书库。
- [x] 1 本书。
- [ ] 20 本书。
- [ ] 长标题。
- [ ] 无封面。
- [x] EPUB 和 PDF 混合。
- [ ] 多标签。
- [ ] 索引 pending/running/failed/done。

操作：

- [x] 导入 EPUB/PDF。
- [ ] 重复导入。
- [ ] 仍然导入副本。
- [ ] 打开已有书籍。
- [ ] 切换网格、列表、紧凑列表。
- [ ] 排序。
- [ ] 按格式、分类、标签、收藏、已读筛选。
- [ ] 右键或长按菜单。
- [ ] 删除书籍不删除原文件。

验收：

- [ ] 卡片比例稳定。
- [ ] 列表可快速扫描。
- [ ] 详情面板信息层级清晰。
- [ ] 状态 chip 清楚且低噪声。
- [ ] 空状态只有明确主动作。

## 6. 阅读器 EPUB 验收

样本：

- [x] 标准 EPUB。
- [ ] 大型 EPUB。
- [ ] 带图片 EPUB。
- [ ] 带目录 EPUB。
- [ ] 无目录 EPUB。
- [ ] 含代码块或长段落 EPUB。

操作：

- [x] 打开。
- [ ] 翻页或滚动。
- [ ] 目录跳转。
- [ ] 搜索。
- [x] 添加书签。
- [x] 选中文本。
- [x] 高亮。
- [x] 创建笔记。
- [ ] 打开 AI 面板。
- [ ] 修改字号、行高、页边距、主题。
- [ ] 关闭应用再打开。

验收：

- [ ] 正文不贴边。
- [x] 工具栏不长期遮挡正文。
- [ ] 改字号后当前位置不明显丢失。
- [ ] 目录当前章节高亮。
- [ ] 标注重启后仍显示。
- [ ] 保存进度能恢复到同一章节或附近。

## 7. 阅读器 PDF 验收

样本：

- [x] 标准文本 PDF。
- [ ] 大 PDF。
- [ ] 扫描版无文本层 PDF。
- [ ] 带 outline PDF。
- [ ] 无 outline PDF。
- [ ] 损坏 PDF。

操作：

- [x] 打开。
- [ ] 滚动。
- [x] 页码跳转。
- [ ] 缩放。
- [ ] 适合宽度。
- [ ] 适合页面。
- [x] 搜索。
- [ ] 选中文本。
- [x] 添加书签。
- [x] 保存进度并重启恢复。

验收：

- [x] 页面居中。
- [ ] 缩放后不明显错位。
- [x] 页码显示正确。
- [ ] 无文本层时搜索和 AI 划词禁用且原因明确。
- [ ] 损坏 PDF 有可恢复错误 UI。

## 8. 搜索验收

范围：

- [ ] 书名。
- [ ] 作者。
- [ ] EPUB 正文。
- [ ] PDF 文本层。
- [ ] 书签。
- [ ] 笔记。
- [ ] AI 回答。

操作：

- [ ] 输入后 debounce。
- [ ] 清空。
- [ ] 类型筛选。
- [ ] 格式筛选。
- [ ] 分类筛选。
- [ ] 标签筛选。
- [ ] 书籍范围筛选。
- [ ] 点击结果跳转。
- [ ] 复制片段。
- [ ] 保存片段为笔记。
- [ ] 对片段提问。

验收：

- [ ] 结果分组清晰。
- [ ] 命中词高亮。
- [ ] 来源和位置可见。
- [ ] 索引失败不影响打开书籍。
- [ ] 无结果状态提供下一步。

## 9. Notebook 和笔记验收

Notebook 条目：

- [ ] 书签。
- [ ] 标注。
- [ ] 摘录笔记。
- [ ] 手写笔记。
- [ ] AI 回答。

操作：

- [ ] 按类型筛选。
- [ ] 按书籍筛选。
- [ ] 按标签筛选。
- [ ] 编辑笔记。
- [ ] 删除笔记。
- [ ] 跳转原文。
- [ ] 复制内容。

验收：

- [ ] 类型标识清晰。
- [ ] 来源书籍和位置清晰。
- [ ] 桌面左列表右预览可用。
- [ ] 移动详情页可用。
- [ ] 删除关联内容有确认。

## 10. AI UX 验收

状态：

- [ ] AI 未启用。
- [ ] 未配置 Base URL 或模型。
- [ ] 未保存 API Key。
- [ ] 连接测试成功。
- [ ] 网络失败。
- [ ] API Key 无效。
- [ ] 模型不存在。
- [ ] 上下文过长。
- [ ] 请求取消。

操作：

- [ ] 选中文本打开 AI 面板。
- [ ] 选择上下文范围。
- [ ] 使用快捷动作。
- [ ] 自定义提问。
- [ ] 发送前确认上下文。
- [ ] 流式回答。
- [ ] 取消请求。
- [ ] 复制回答。
- [ ] 重试。
- [ ] 保存为笔记。

验收：

- [ ] 默认不发送整本书。
- [ ] 上下文范围可见。
- [ ] 发送内容长度有提示。
- [ ] 错误提供下一步。
- [ ] API Key 不出现在日志、错误详情、导出文件。

## 11. 键盘验收

快捷键：

- [ ] `Ctrl+O` 导入。
- [ ] `Ctrl+F` 书内搜索。
- [ ] `Ctrl+Shift+F` 全局搜索。
- [ ] `Ctrl+B` 添加或取消书签。
- [ ] `Ctrl+G` 页码跳转。
- [ ] `Ctrl+Plus` 放大。
- [ ] `Ctrl+Minus` 缩小。
- [ ] `Ctrl+0` 重置缩放。
- [ ] `Esc` 关闭面板或弹窗。
- [ ] `Left/Right` 翻页。
- [ ] `PageUp/PageDown` 翻页。

焦点：

- [ ] Tab 顺序符合视觉顺序。
- [ ] 当前焦点可见。
- [ ] 弹窗内焦点被限制。
- [ ] 列表可用方向键移动。
- [ ] Enter 可打开当前选中项。

```text
日期：2026-07-04
提交或版本：本地工作树，空状态和封面图片语义回归
平台：Windows 开发环境 widget test 和代码审计
验证人：Codex
样本：AppEmptyState 公共组件、SearchPage 搜索起始/无结果空状态、TaskCenterPage 无任务空状态、LibraryPage 书籍封面和封面占位图
结果：AppEmptyState 统一提供“空状态：标题。说明”的语义摘要，装饰性空状态图标从语义树排除，操作按钮仍作为独立可聚焦控件；搜索页起始和无结果状态改用公共空状态组件；任务中心无任务状态不再使用空占位 action；书库封面 Image.file 和占位封面增加书名/格式相关语义。新增 `test/app/widgets/app_empty_state_test.dart` 覆盖有主动作和纯信息空状态的语义标签，单独运行 2 项通过；`flutter analyze` 通过。
阻塞问题：该记录证明公共空状态和书库封面代码路径具备明确语义，不等于 TalkBack 或 Windows Narrator 实际朗读、焦点顺序、系统字体放大、真实书库图片加载失败路径或 Android 真机可访问性验收完成。
```

## 12. 可访问性验收

- [x] 所有 icon-only 按钮有 semantic label。
- [x] 不熟悉图标有 tooltip。
- [x] 图片和空状态有合理语义。
- [ ] 状态不用颜色单独表达。
- [ ] 高对比主题可读。
- [ ] 减少动画后无必须依赖动画的信息。
- [ ] 字体放大后主路径可用。
- [ ] TalkBack 或 Windows Narrator 可读出主要操作。

## 13. 发布前 UI/UX 验收

- [ ] 发布截图来自新版 UI。
- [x] 隐私说明与 AI 面板行为一致。
- [x] 许可说明入口可见。
- [x] 完整第三方许可清单已生成并通过自动化覆盖检查。
- [x] 生产包不包含测试书籍。
- [x] 发布包包含 renderer 静态资源。
- [x] 发布包包含必要图片资源。
- [ ] Android 和 Windows 各完成一次真实阅读闭环。
