# TASK-31：Markdown 阅读

状态：**P1–P20 已实现**（P1–P5 于 2026-11-05，P6 于 2026-11-08，P7 于 2026-11-08，P8–P20 于 2026-11-09 至 2026-11-11），待用户在安装版里手测验收；权威文档与质量门禁持续同步。

## 目标

让 PageSage 能像读一本 EPUB 那样读 Markdown 文件：导入书库、排版阅读、目录跳转、保存进度、全文搜索。第二阶段支持把**一个目录**当作一本书来读（笔记库、文档仓库）。

## 来源与边界

- 来源：用户 2026-11-05 明确要求「加个阅读 markdown 的功能」。
- **范围变更**：`AGENTS.md` 与 `docs/00`–`07` 原本把阅读格式限定为 EPUB / PDF。Markdown 不在原路线内，本次是产品路线的有意扩展；2026-11-05 已更新 `AGENTS.md` 的格式约束，2026-11-08 又补上目录书例外、locator、搜索索引与验收文字，同步到 `README.md`、`docs/00`–`07` 与 `pubspec.yaml`。除格式之外，仍遵守本地优先、AI 请求上下文范围明确、不自动上传整本书、不做云同步等产品约束。
- P1 只做**单个 `.md` / `.markdown` 文件当一本书**。
- P2 做**目录当一本书**（按路径排序成章节，目录内的相对图片正常工作）。已实现：**原地读取，不复制**（用户 2026-11-05 决定）。
- P13 起，Mermaid/PlantUML/Graphviz 围栏与 HTML 采用**可读边界**；P14 起，数学公式改用本地纯 Dart TeX 排版，不再显示原始 LaTeX 源码。图表仍保留源码，HTML 只留安全可见文字；不执行脚本、不画矢量图、不加载远程资源、不使用 WebView。外链自动打开与阅读器编辑仍不做。当前页 / 当前章节 / 前后段落 / 全书 / 文件夹关联的 AI 上下文已通过共享文档模型与检索层接通；Markdown 划词标注仍沿用 EPUB 路径的已知边界。

## 设计取舍

- **复用阅读引擎，不另写一个阅读器。** Markdown 被解析成与 EPUB 相同的文档模型（章节 → 块 → 字符偏移），因此分页、连续滚动、目录、进度、搜索高亮、图片渲染全部直接复用。另写一个 Markdown 阅读器意味着这套行为要重做一遍，且两边会慢慢长歪。
- **P1 阶段行内强调暂不渲染。** `**粗体**`、`*斜体*`、行内代码当时只保留文字、去掉标记；P5 已在共享块模型中补上 `EpubInlineRun`，Markdown 与 EPUB 两个解析器共同受益。下文的 P5 是当前实现，早期取舍只作为历史记录保留。
- **标题、代码块、引用、列表、表格、图片是有结构的。** 这些是块级语义，正好落在现有块模型上：标题走 heading 样式，围栏代码走 code 样式（等宽 + 边框），引用走 quote 样式，列表项带项目符号，表格走 `EpubTableBlock`（保留行与单元格，由渲染层画成真正的表格），图片走图片块。
- **章节按一级标题切分。** 有 `#` 就一章一节；没有一级标题时整篇是一章，标题取 front matter `title:` 或文件名。目录由一级、二级标题生成。
- **图片只读本地。** 相对路径按文件所在目录解析，支持 `data:` URI；`http(s)` 图片不加载，理由同 EPUB：本地优先，一本书指向网络不该让读者等。
- **front matter 只用来取标题。** `---` 之间的 YAML 不进入正文，也不参与搜索；现阶段只认 `title:`，其余字段以后再说。
- **`package:markdown` 直接声明。** P1 实现时先复用 `flutter_markdown` 的传递依赖，随后在 `pubspec.yaml` 显式声明 `markdown: ^7.3.1`，避免阅读器依赖另一个包的依赖表；没有为 Markdown 引入渲染引擎或平台插件。

## 实现任务

### P1：单文件

- [x] `BookFormat.md`；格式识别（`.md` / `.markdown`，文本内容校验）；元数据（front matter 标题 → 首个一级标题 → 文件名）。
- [x] Markdown 解析器：Markdown → 章节/块/偏移，块类型复用现有模型并新增 quote。
- [x] 阅读器接入：格式分派、目录面板、进度恢复、图片块。
- [x] 全文搜索索引：Markdown 书籍按章节建索引。
- [x] 书库与搜索的格式标签、图标、筛选。
- [x] 导入：文件选择器允许 md；扫描文件夹时识别 md。

### P2：文件夹

- [x] 选目录导入为一本书；章节按相对路径排序。
- [x] 目录内图片按各自文件所在目录解析。
- [x] 文件夹新增/删除文件后的重新扫描策略：按目录指纹缓存解析结果（路径 / 大小 / 修改时间），每次打开/索引都重新遍历并比对；编辑器里加的文件下次打开就在，删除的章节自然消失，未变化的目录可命中缓存。

### P3：表格（2026-11-05）

- [x] 表格不再按「对齐的等宽文本」排版，而是保留行列结构：块模型新增 `EpubTableBlock`（行、单元格、是否有表头），渲染层用 `Table` 画等宽列、横线分隔、表头加粗。
- [x] 分页按**行**切分：一页放不下的表格会跨页，每页重复表头，列名不会和内容分家。
- [x] 容错：`package:markdown` 只在分隔行（`| --- | --- |`）的列数与表头列数相同时才认表格，手写笔记里两者经常对不上，整张表会被丢掉。解析前先把分隔行改写为表头的列数（逐列保留 `:` 对齐），围栏代码块内的内容不动。
- [x] 单元格文字仍写进章节文本，搜索、进度、划选偏移不受影响；单元格内部的行内样式由 P18 接入，搜索命中、批注高亮和临时聚焦由 P19 接入。

### P4：切换章节的性能（2026-11-05）

- [x] 连续模式的列表从「一章一行」改为「一章多行，每行 8 块」。之前一行就是整章，章节进入视野的那一帧要把整章几十个段落一次性排版；现在只排屏幕上的那几行。
- [x] 分页模式记住已测量过的章节（最多 10 章，按最近使用淘汰），切回读过的章节是查表；当前页停稳 400 ms 后，在后台预排下一章，往后切章也是查表。翻页/切章会取消预排，输入优先。
- [x] `_restoreInitialOffset` 与「上一章/下一章」改为按章节首行定位，不再假设「行号 = 章号」。

实测（debug 构建，1440×900，真实笔记库 53 章 / 304 K 字；同一台机器）：

| 场景 | 修改前 | 修改后 |
| --- | --- | --- |
| 连续模式切到下一章（单帧） | 160–250 ms，后续帧最坏 435 ms | 25–60 ms |
| 分页模式切到下一章（单帧） | 15–100 ms | 10–50 ms，读过/预排过的章节为查表 |
| 单章分页测量 | 最慢 61–75 ms | 不变（现在只在新章节第一次进入时发生） |

- 回归测试：`test/renderers/epub/epub_continuous_slicing_test.dart` 断言长章节只排版屏幕部分、滚动后仍能读到末尾；保存的章节位置在连续模式下落在正确章节。

### P5：行内样式与排版层级（2026-11-05）

目标是把阅读观感往 Typora 靠（只做阅读，不做编辑）。放在共享文本模型里，EPUB 同时受益。

- [x] 行内样式进块模型：`EpubInlineRun`（`start`/`end`/`style`，`style` 为 `strong` / `emphasis` / `code` / `strike` / `link`），偏移是**章节偏移**，与块、片段同一套坐标；正文文字保持书上原样，标记符不进文本，所以搜索、进度、划选偏移都不变。
- [x] Markdown 解析器：`_InlineDraft` 在写出文字的同时记下 `strong` / `em` / `del` / `code` / `a` 覆盖的范围，嵌套叠加（`***x***` 同时是粗体和斜体），列表项把 run 按前缀长度整体平移。
- [x] 渲染层：`Text.rich` 的 span 在「样式、批注、搜索命中、定位高亮」每一处边界切开，多个样式叠加合成（粗斜体保持两者；删除线链接同时有下划线）；代码为等宽字体加淡底，链接用主题链接色加下划线。span 缓存键加入 run 签名。
- [x] 标题层级：`EpubTextBlock.headingLevel`（1–6）由 Markdown 与 EPUB 解析器都填。字号倍数 1.62 / 1.36 / 1.16 / 1.06 / 1.0 / 0.96，上方留白随层级缩放；分页测量与渲染共用 `epubHeadingScale` / `epubHeadingSpacingFactor`，不会量出来一页、画出来另一页。
- [x] 分隔线：`EpubDividerBlock`（不占字符），Markdown 的 `---` 与 EPUB 的 `<hr>` 都记成这种块；渲染为整列宽 1 px、行高 18 的细线，独立成块，不参与分页切分。
- [x] 列表悬挂缩进：P6 用 `EpubTextBlock.listMarker` / `listIndent` 让标记留在章节文本与偏移里，渲染层的 `visibleText` 去掉 marker 并用独立的 marker 列绘制，正文坐标仍落在同一章节文本上；分页测量用同一缩进宽度。
- [x] 链接点击：P6 让 `EpubInlineRun.target` 穿过分页，渲染层点击安全外链发 `RendererExternalLinkRequested`，宿主确认后再打开。
- [x] 图片替代文字：P6 把 `EpubImage.alt` 画成图片块下方的视觉图注，不进入章节文本；占位图片不再重复显示 `alt`。

### P6：Typora 阅读细节对齐（2026-11-08）

范围只补上面三项阅读细节，不做 Markdown 编辑器、不换主题、不新增导出或图表能力：

- [x] 列表悬挂缩进：标记保留在章节文本与字符偏移里，视觉上独立成列，换行文字对齐到内容列；分页测量与连续模式使用同一套缩进。
- [x] 链接点击：点击有安全外链目标的文字只发出 `RendererExternalLinkRequested`，由宿主确认后打开；内部锚点、`javascript:` 与非链接文字不触发。
- [x] 图片 `alt` 图注：可用图片与占位图片下方都显示安静的视觉图注；`alt` 不进入章节文本、不参与搜索与偏移。

改代码前声明验证矩阵（改前实现状态：`DESIGN_ONLY`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 列表项元数据保留偏移 | `test/renderers/markdown/markdown_parser_test.dart` → `list markers stay in the chapter text and describe hanging layout` | `- 一项`、嵌套列表、`1. 编号` | 改前 `EpubTextBlock` 无 `listMarker`；改后正文仍是 `• 一项`，marker / indent / 样式 run 的章节偏移都指向原文字 | 普通段落不带列表元数据 |
| 链接目标穿过解析与分页 | `test/renderers/markdown/markdown_parser_test.dart` → `link targets travel with their inline runs`；`test/renderers/epub/epub_paginator_test.dart` → `link targets survive page fragmentation` | `[链接](https://example.com)`、危险协议与内部锚点链接 | 改前 run 无 target，分页片段无 target；改后安全外链保留完整 URI，其他目标为空 | 非链接 run、内部锚点、危险协议不携带外链目标 |
| 悬挂缩进按同一常量测量 | `test/renderers/epub/epub_paginator_test.dart` → `list styling shares one hanging-indent width`；`test/renderers/markdown/markdown_rendering_test.dart` → `list markers and wrapped lines align to separate columns` | 带列表元数据的手工文档 / 长列表项 Markdown 文件 | 改前分页测量按整段宽度，渲染无悬挂；改后 paginator 与 widget 使用同一个 `epubListHangingIndent`，widget 把 marker 与内容分到两列 | 连续模式的普通段落不加悬挂缩进 |
| 点击链接发宿主事件 | `test/renderers/markdown/markdown_rendering_test.dart` → `a safe external link asks the host before opening` | 含三个链接的 Markdown 文件，记录 `onEvent` | 改前点击链接只改样式、无事件；改后仅安全外链发一次带原始 URI 的 `RendererExternalLinkRequested` | 点击普通文字、内部锚点、`javascript:` 链接均不发事件 |
| 图片 `alt` 是视觉图注 | `test/renderers/markdown/markdown_rendering_test.dart` → `a picture caption is shown without entering chapter text`；`test/renderers/epub/epub_image_rendering_test.dart` → `an available picture shows its alt caption once` | `![一张图](pic.png)`、`![缺失](gone.png)` | 改前可用图片不显示 `alt`（占位块把 `alt` 当说明）；改后两者都在图片块内显示一次图注，章节文本仍不含 `alt`，搜索 / 进度偏移不变 | 空 `alt` 不显示空图注；EPUB 的 `figcaption` 仍是独立正文块 |
| 分页给图注留高度 | `test/renderers/epub/epub_paginator_test.dart` → `an image caption is included in the measured image height` | 有无 `alt` 的 `EpubImageBlock` | 改前两种图片测量高度相同；改后有 `alt` 时增加图注高度，页面不会溢出 | 无 `alt` 不增加高度 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 666 项通过 / 2 skipped；日志 `/tmp/pagesage-check-syntax-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |
| Read 模式 UI 机械检查 | `<HOME>/.codex/skills/impeccable/scripts/impeccable detect --json <changed UI targets>` | 渲染器文件 | UI 改完后一次 detector，无新增真实缺陷 | detector 通过不等于视觉验收通过 |
| 真实窗口排版复验 | `flutter test integration_test/reader_markdown_test.dart -d linux` | `.codex-run/samples/markdown-note.md` 与 `markdown-picture-note.md`，隔离虚拟 Wayland 会话中的 Linux 桌面窗口 | 2026-11-08 PASS：刷新 `build/integration-captures/markdown-01-prose.png`，确认悬挂列表、嵌套编号缩进、链接着色、引用与代码块；`markdown-02-picture-captions.png` 确认可用图与缺失图的 `alt` 图注 | 旧截图不能作为本次改动证据 |

结构契约：列表 marker 与内容留在同一个 `_EpubFragmentView` 中，由 `Row` 分列；图注留在同一个图片片段的 `Column` 内，位于图片或占位块下方；不新增独立卡片、浮动层或工具条。宿主确认链路复用 `ReaderPage._confirmOpenExternalLink`，渲染器不调用 `launchUrl`。`bash tool/check.sh` 仅作为 tooling evidence；真实窗口与安装版手测分别记录，不相互替代。

收口验证矩阵（2026-11-08，记录措辞与视觉证据缺口，不改产品行为）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号 | 负例 |
| --- | --- | --- | --- | --- |
| 真实窗口显示两类 `alt` 图注 | `integration_test/reader_markdown_test.dart` → `a Markdown picture shows its alt caption in the real window` | 现场生成可解码 PNG、缺失图片、含两类 `![alt]` 的 `.md` | 可用图与缺失图各显示一次安静图注；`alt` 和图片路径不进正文；截图 `markdown-02-picture-captions.png` 留痕 | 不把 widget 测试替代为真实窗口证据；不把占位说明重复成图注 |
| 文档措辞与最终实现一致 | `git diff --check`、`test/tool/release_readiness_test.dart` → `documentation links and release assets stay valid` | 本次改动的 Markdown | P5 历史说明不再声称三项未做；P5 列表实现描述与 `visibleText` / marker 列一致；无破链 | 不扩大到未请求的 backlog，也不重跑未受影响的产品门禁 |
| Read 模式机械检查 | `impeccable detect --json integration_test/reader_markdown_test.dart` | 更新后的 4.8.1 detector | 返回 `[]`，无新增真实缺陷 | detector 通过不替代真实窗口截图 |

实现状态：`IMPLEMENTED`；本切片验证证据：`RUNTIME_PASS` 后回写，安装版 `E2E` 仍 `BLOCKED`。

### P7：文件夹工作区（2026-11-08）

用户 2026-11-08 明确要求：不要把文件夹里的多个 Markdown 文件拼成一个大文档再渲染；像 Typora 一样，侧栏先给文件树，再给当前文件的大纲。导入入口也不该分成「导入」和「文件夹」两个按钮。

实现契约：

- 文件夹书仍只对应书库一条 `Book`，`libraryFilePath` 仍指向用户目录，不复制、不写入、删除书不删除目录。
- 新增 `MarkdownFolderManifest`：读取顺序的文件列表 + 保留子目录层级的面板树。它只做发现和 stat，不解析全部正文。
- 阅读器只加载**当前活动文件**：选中文件后再走现有单文件 `MarkdownDocumentLoader`，仍然复用 `EpubRendererView`，不另写 Markdown 阅读器。
- 文件夹书目录面板分两层：`文件` 是文件/子目录树，`大纲` 只显示当前文件标题。单文件书没有 `文件` 层，只显示文件内大纲。
- 文件夹 locator：`href` 是相对文件路径，`chapterIndex` / `chapterOffset` 是该文件内部坐标，`progress` 是全书进度（按文件大小加权）；`folderFileLocal: true` 标记新语义。旧版「合并文件夹」locator 在打开时做一次 best-effort 映射，不能静默跳到错误章节。
- 搜索索引仍覆盖整个文件夹，但每条结果必须带相对文件路径和文件内章节；AI 当前章节上下文按活动文件加载，整夹检索继续走索引。

改代码前声明验证矩阵（改前实现状态：`DESIGN_ONLY`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 单文件书只有文件内大纲 | `test/renderers/markdown/markdown_rendering_test.dart` → 单文件阅读器目录用例 | 一个含多级标题的 `.md` | 不出现 `文件` 标签；只列该文件标题，点击跳到对应章节 | 不把文件路径混进大纲 |
| 文件夹树保留子目录层级 | `test/renderers/markdown/markdown_folder_test.dart` → `a folder manifest keeps directories and files apart` | `a.md`、`sub/b.md`、`sub/deep/c.md` | 根下有文件节点与 `sub` 目录节点，`sub` 下再有 `b.md` 和 `deep`；不拍平成文件列表 | 隐藏目录、`node_modules` 不进入树 |
| 当前文件大纲只含该文件标题 | `test/renderers/markdown/markdown_folder_test.dart` → `a folder file outline only names its own headings`；阅读器 widget 用例 | 两个文件各含不同标题 | 选中 `b.md` 后大纲只有 `b.md` 的标题，没有 `a.md` 的标题 | 不把所有文件的 heading 合并 |
| 切换文件后正文与进度正确 | `test/widget_test.dart` → `a folder book restores its saved file and own outline`（切换文件断言） | `a.md`、`sub/b.md` | 点击文件后 renderer 收到该文件路径；正文只含该文件文字；保存的 locator 带相对路径和文件内章节 | 切文件后仍读到上一个文件 |
| 关闭重开回到上次活动文件 | `test/widget_test.dart` → `a folder book restores its saved file and own outline`（首次加载断言） | 保存 `b.md` 的 locator 后重建 reader | 首次加载 `b.md`，章节偏移与保存值一致 | 回到目录第一篇 |
| 搜索跳转落到正确文件/章节 | `test/core/search/search_indexer_test.dart` → `indexes a Markdown folder per file` | 两篇笔记含同一关键词 | 结果 locator 的 `href`、`chapterIndex` 分别指向命中文件与该文件内章节；`progress` 在全书范围内 | 不留下旧版合并 chapterIndex |
| AI 当前文件上下文正确 | `test/features/ai/ai_context_source_test.dart` → `a folder chapter is read from its own file` | 文件夹书 + 指向第二篇的 locator | 返回第二篇正文，不返回第一篇或整夹正文 | 文件夹书当前章节不触发整夹上传 |
| 导入只有一个入口 | `test/widget_test.dart` → `the import menu names the three import shapes` | 空书库与有书书库 | 头部与空状态都只有「导入」菜单；三个菜单项分别触发文件选择、目录扫描、整夹导入 | 不再保留独立「文件夹」按钮 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | `dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 全绿 | 任一聚焦测试失败即不接受全绿聚合 |
| Read 模式 UI 机械检查 | `impeccable detect --json <changed UI targets>` | 书库、阅读器、目录面板 | 返回 `[]`，无新增真实缺陷 | detector 通过不等于视觉验收通过 |
| 真实窗口文件夹阅读 | `flutter test integration_test/reader_markdown_test.dart -d linux`（在 `kwin_wayland --virtual` 离屏会话执行） | 现场生成含子目录的 Markdown 文件夹 | 侧栏出现 `文件` / `大纲`；顶层行不再重复名称；切文件后正文更新且仍停在 `文件`，显式点 `大纲` 才显示当前文件标题；截图 `markdown-03`–`06` | 旧截图不能作为本次改动证据；不得在用户桌面直接弹窗 |

结构契约：文件夹树只读 manifest，不读正文；大纲只读当前文件文档；阅读器一次只持有一个文件的 `EpubDocument`。不新增浮动卡片、嵌套卡片或第二套 Markdown 渲染器。导入菜单复用现有 picker/use case，不改变「目录原地读取」例外。

执行记录（2026-11-08）：

- `bash tool/check.sh` PASS：`dart format` 204 files / 0 changed、`flutter analyze` 0 issues、`flutter test` 528 passed / 2 skipped；日志在 `/tmp/pagesage-check-p7-ui-final-20261108.log`。
- UI 收口（2026-11-08）：代码块改为占满正文列宽的安静底色块，内部横向滚动，不再缩成按文字宽度的小框；列表项间距压缩到段间距的 0.3，向 Typora 的紧凑列表靠拢，分页测量与渲染共用 `epubBlockSpacing()`。文件树去掉顶层行重复的名称副标题，嵌套行只在副标题显示父目录；选中文件后保持「文件」页签，只有显式点「大纲」才切换。
- `impeccable detect --json lib/features/library/presentation/library_page.dart lib/features/reader/presentation/reader_page.dart lib/renderers/epub/epub_renderer_view.dart` 返回 `[]`。
- 离屏虚拟 Wayland 集成测试 3 项 PASS，未在用户桌面打开窗口；截图确认 `文件` / `大纲` 分层、子目录边界、当前文件正文与大纲切换。
- 共享渲染器离屏回归（2026-11-08，UI 收口后复跑）：`reader_s0_test.dart` 11/11、`reader_epub_image_test.dart` 1/1、`reader_markdown_test.dart` 3/3 PASS；每个集成文件使用独立 `kwin_wayland --virtual` 会话。
- 安装版 `E2E` 仍 `BLOCKED`：待用户在 `tool/install_linux.sh` 安装版手测，不能用自动化或内存日志替代。

实现状态：`IMPLEMENTED`；本切片验证证据：`TOOLING_PASS` + `RUNTIME_PASS`（离屏虚拟 Wayland），安装版 `E2E` 仍 `BLOCKED`。

### P8：任务列表与代码语言（2026-11-09）

用户要求继续把 Markdown 阅读向 Typora 靠齐。本切片只补两个不引入新依赖的阅读细节：

- **任务列表只留一个复选框。** 之前 `- [x] 项` 被解析成「圆点 + ☑ + 文字」，因为列表标记和 checkbox 各写了一次。现在 `li.task-list-item` 的第一个 checkbox 成为该列表项唯一的标记：章节文本是 `☑ 文字` / `☐ 文字`，`listMarker` 与 `taskChecked` 一起告诉渲染层画真正的复选框；普通项目符号和编号列表不变。
- **复选框图形不进入正文。** 选择、复制、搜索和进度仍使用章节文本里的原字符；渲染层用 `Icons.check_box_rounded` / `Icons.check_box_outline_blank_rounded` 画标记列，完成态与未完成态都有文字语义标签。
- **代码块显示语言标签。** 解析器从 `code.language-*` 取出 `dart`、`python` 等 fence 语言，写进 `EpubTextBlock.codeLanguage`，不写进章节文本；渲染器在代码面板右上角画一枚安静的标签，正文偏移、搜索和划选完全不受影响。
- **分页与绘制共用高度。** 语言标签占 18 px，代码面板上下内边距各 11 px；`epubCodeLanguageHeight` / `epubCodeBlockPadding` 同时供分页器和渲染器使用，带语言的代码块会比不带语言的同文代码块多 18 px，不会量出来一页、画出来溢出一行。
- **旧 book 的位置会轻微前移。** 任务项文本从「圆点 + 复选框 + 空格」变成单一标记，任务密集的书保存的章节字符偏移可能相差一两个字符；进度仍按章节与比例恢复，搜索在重新索引后使用新文本。本轮不迁移历史 locator，也不改动数据库。

改代码前声明验证矩阵（改前实现状态：`DESIGN_ONLY`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 任务项只有一个标记 | `test/renderers/markdown/markdown_parser_test.dart` → `task items carry one checkbox marker and their checked state` | `- [ ] 未完成`、`- [x] 已完成`、嵌套任务 | 改前文本是 `• ☑ 未完成`；改后是 `☐ 未完成` / `☑ 已完成`，`listMarker` 与 `taskChecked` 对齐，章节里没有 `•` | 普通 `- 项` 仍是 `• 项`，不应被识别为任务 |
| 复选框是视觉标记 | `test/renderers/markdown/markdown_rendering_test.dart` → `a task item draws one checkbox instead of a bullet` | 含完成 / 未完成任务的 Markdown | 改前渲染出圆点和 ☑ 文本；改后各有一个 checkbox 图标，正文不出现 `•`、`☐`、`☑` | 普通列表的圆点仍可见，不能被隐藏 |
| 代码语言不污染正文 | `markdown_parser_test.dart` → `a fenced code block keeps its language beside its text`；`markdown_rendering_test.dart` → 代码块用例 | ```` ```dart ```` 与无语言围栏 | 改前没有语言字段；改后 `codeLanguage == 'dart'`，标签可见，章节文本不含 `language-dart` 或围栏 | 无语言代码块不显示空标签 |
| 语言标签参与分页测量 | `test/renderers/epub/epub_paginator_test.dart` → `a code language label reserves measured room and travels with pages` | 同一段代码，分别无语言 / `dart` | 改前两页高度相同；改后带语言页高多 18 px，片段带着 `codeLanguage`，代码文本不变 | 测量高度不能被标签吃掉正文空间 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 634 passed / 2 skipped；日志 `/tmp/pagesage-check-typora-ocr-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |
| 真实窗口阅读 | `flutter test integration_test/reader_markdown_test.dart -d linux`（离屏 `kwin_wayland --virtual`） | 现场生成含任务项与 ```` ```dart ```` 的 Markdown | 2026-11-09 PASS 3/3：截图 `markdown-01-prose.png` 显示一个未完成、一个完成复选框与右上角 `dart` 标签，正文不含列表标记或围栏；日志 `/tmp/pagesage-md-integration.log` | 组件测试不能替代真实窗口截图；不得在用户桌面直接弹窗 |

实现状态：`IMPLEMENTED`；本切片验证证据：`TOOLING_PASS` + `RUNTIME_PASS`（离屏虚拟 Wayland），安装版 `E2E` 仍 `BLOCKED`。

### P9：脚注编号与脚注区（2026-11-09）

`package:markdown` 的 GFM 扩展已经能解析 `[^label]` 与 `[^label]: ...`，但旧阅读器把引用数字当普通正文、把定义当普通编号列表，还显示 `↩` 回链。本切片只补阅读排版，不新增脚注跳转：

- 引用数字成为独立的 `EpubInlineStyle.footnote` 行内 run：字号缩到正文的 0.72，使用链接色，并请求字体的 `sups` 特性；正文文字仍是 `1`，搜索、选区和偏移不变。
- 脚注引用内部的 `#fn-*` 锚点不再生成链接样式，避免正文出现一条伪外链。
- `section.footnotes` 前插入 `EpubDividerBlock`；定义列表的每个 `li` 走 `caption` 块，保留 `1.` / `2.` 标记与悬挂缩进，但整块以小一号、稍弱的说明文字呈现。
- GFM 生成的 `a.footnote-backref` 回链箭头不进入正文；读者仍可搜索和选中脚注文字，但点击引用跳回脚注留到内部锚点事件统一处理。

改代码前声明验证矩阵（改前实现状态：`DESIGN_ONLY`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 引用数字有脚注 run | `test/renderers/markdown/markdown_parser_test.dart` → `footnotes keep their reference numbers and hide the back arrows` | 两处 `[^why]` / `[^two]` 引用与定义 | 改前 run 只有 link；改后 `footnote` run 覆盖 `1`、`2`，章节文字仍是 `...脚注1...`，所有块偏移仍精确 | 普通 `[文字](#anchor)` 不应被当作脚注 |
| 脚注区有分隔且缩小 | 同文件断言 caption 块、`EpubDividerBlock` 与 `listMarker` | 两条脚注定义 | 改前定义是普通 paragraph 列表；改后定义是 caption 块，`1. ` / `2. ` 标记保留，分隔块存在 | 普通编号列表仍是 paragraph，不缩小 |
| 回链箭头不进入正文 | `markdown_parser_test.dart`、`markdown_rendering_test.dart` → `footnote references are set apart and the back arrows are hidden` | GFM 生成的 `a.footnote-backref` | 改前正文有 `↩`；改后解析文本与 widget 都找不到回链箭头 | 脚注正文里的普通文字不能被误删 |
| 引用视觉与正文区分 | 同上 widget 用例 | 18 px 正文字号 | 引用 span 字号小于 18、带 `FontFeature.superscripts()`；脚注块字号小于正文 | 普通段落不获得脚注颜色或字号 |
| 聚焦回归 | `flutter test test/renderers/markdown test/renderers/epub test/widget_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 PASS：119 项；日志 `/tmp/pagesage-footnote-regression.log` | 任一 Markdown / EPUB 用例失败即不接受 |
| 离屏截图 | `flutter test ... --dart-define=CAPTURE_READER_WORKBENCH=true --plain-name 'footnote references...'` | 真实生成的 `.md`，1200×800 | PASS：`build/workbench-captures/markdown-footnotes.png` 显示正文小号引用、分隔线与缩小脚注列表 | 截图不替代真实桌面或安装版验收 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 636 passed / 2 skipped；日志 `/tmp/pagesage-check-footnote-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |

实现状态：`IMPLEMENTED`；本切片验证证据：`TOOLING_PASS` + 离屏截图，安装版 `E2E` 仍 `BLOCKED`；真实窗口集成测试按当前项目规则未自行启动。

已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建与本地安装成功，日志 `/tmp/pagesage-install-footnote-20261109.log`；bundle `diff -qr` 无差异，构建与安装的 `libapp.so` SHA256 均为 `9d21725047c2c3fee09828a47b5d9a8e5787e318c6343e3714f23ff5ae276eee`。未启动、关闭或重启已运行的 PageSage，已有进程需用户重启加载新版。

### P10：脚注内部跳转（2026-11-09）

P9 解决了脚注的阅读排版，但引用仍不可点。P10 补齐 Typora 风格的脚注定位闭环，并把内部锚点与外链彻底分开：

- **脚注定义进章节锚点。** GFM 为定义 `<li>` 生成 `id="fn-*"`；解析器在写入定义块后记录 `fn-* -> 章节字符偏移`，同一个映射穿过 Markdown 文档加载器和文件夹逐文件加载器。引用 run 保留 `#fn-*` 目标，正文仍是原来的数字字符，搜索、选区、进度偏移不变。
- **内部目标不弹外链确认。** 渲染器接收 `footnote` run 的 `#fn-*` 目标，点击后只在当前文档的章节锚点里查找；命中时发 `RendererInternalLinkRequested(locator)`，未命中或普通 `#section` 不产生事件，也不会走 `RendererExternalLinkRequested` / 浏览器确认框。
- **宿主复用统一 jump。** 阅读器把内部 locator 交给现有 `_jumpTo`，分页模式按章节偏移选页；连续模式按块偏移选行，并给目标片段单独挂 key 做二次 `ensureVisible`，不会只跳到章节开头。文件夹书仍使用当前活动文件的相对路径与文件内坐标。
- **未来可复用。** 外链只接受 `http` / `https` / `mailto`；内部脚注目标只接受已知 `#fn-*` 锚点。没有为脚注新增第二套阅读器、弹层或导航栈。

改代码前声明验证矩阵（改前实现状态：`DESIGN_ONLY`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 引用携带内部目标 | `test/renderers/markdown/markdown_parser_test.dart` → `footnotes keep their reference numbers and hide the back arrows`、`a footnote target can land in a later chapter` | 同章两条脚注；第一章引用、第二章定义 | 改前 `footnote` run 无 target、`chapter.anchors` 为空；改后 target 为 `#fn-*`，定义所在章节的锚点等于定义块 `startOffset` | 普通 `[文字](#anchor)` 仍不携带内部目标 |
| 目标穿过分页 | `test/renderers/epub/epub_paginator_test.dart` → `footnote targets survive page fragmentation` | 超过一页的长正文，脚注引用落在后段 | 改前分页片段没有脚注 target；改后每个相关片段保留 `#fn-note` 与原章节偏移 | 分页不能改写 run 的起止偏移 |
| 点击发内部跳转而非外链 | `test/renderers/markdown/markdown_rendering_test.dart` → `a footnote reference jumps to its definition chapter` | 跨章脚注 | 改前点击引用无事件；改后只发一次 `RendererInternalLinkRequested`，locator 的 chapter / offset 指向定义章节与锚点 | 不产生 `RendererExternalLinkRequested` |
| 缺少锚点不误跳 | 同文件 → `a footnote without a matching anchor stays in place` | 保留 footnote run 但清空 `chapter.anchors` | 改前无内部目标；改后点击不崩溃、不发内部或外部事件 | 不把 `#fn-*` 当外链打开 |
| 连续模式精确落点 | 同文件 → `a saved footnote offset lands on its definition` | 第二章 48 段正文，保存 locator 指向脚注定义 | 改前只按章节首行定位，定义可能在视口外；改后目标片段可见 | 不能把“章节跳转”冒充“块偏移跳转” |
| 聚焦回归 | `flutter test test/renderers/markdown/markdown_parser_test.dart test/renderers/epub/epub_paginator_test.dart test/renderers/markdown/markdown_rendering_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 PASS：55 项；日志 `/tmp/pagesage-footnote-jump-focused-final-20261109.log` | 任一解析、分页或点击用例失败即不接受 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 641 passed / 2 skipped；日志 `/tmp/pagesage-check-footnote-jump-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |

实现状态：`IMPLEMENTED`；本切片验证证据：`TOOLING_PASS`；真实窗口与安装版 `E2E` 仍待用户验收。

已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建与本地安装成功，日志 `/tmp/pagesage-install-footnote-jump-20261109.log`；bundle `diff -qr` 无差异，构建与安装的 `libapp.so` SHA256 均为 `67daceac721b0e84c87c7d0627773cb083c465c16fe1775046189328854b649e`。未启动、关闭或重启已运行的 PageSage，已有进程需用户重启加载新版。

### P11：文件夹会话结构收口（2026-11-09）

P7 已把文件夹书改成「一次只打开一个文件」，但 manifest、活动文件、旧 locator 映射、文件切换、渲染器进度与事件坐标换算仍散落在 5000 余行的阅读页里。本切片只整理所有权，不改变阅读行为和产品边界：

- 新增 `MarkdownFolderSessionController`（`lib/features/reader/application/markdown_folder_session.dart`）持有当前书、manifest、活动文件与恢复 locator；异步加载以 `bookId` 和当前 Future 身份校验，换书不会让旧 manifest 回写。
- `MarkdownFolderSource` 作为 renderer 侧的窄接口，让 `MarkdownFolderLoader` 仍留在 `lib/renderers/markdown`，同时允许控制器测试注入延迟源；不改 manifest、文件树、文件内解析或数据库结构。
- 阅读页只保留 FutureBuilder 与 UI 编排。活动文件路径、目录面板、renderer host 参数、jump 切文件、renderer 进度换算、位置 / 选择 / 搜索事件归一化和 legacy jump 全部调用同一控制器。
- 结构测试覆盖保存文件恢复、切文件时保留目标文件与文件内坐标、全书 / 文件内进度互转、renderer 事件归一化、旧版合并章节映射、同书会话复用和换书竞态。

改代码前声明验证矩阵（改前实现状态：`IMPLEMENTED_IN_PAGE`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 会话状态有单一归属 | `test/features/reader/markdown_folder_session_test.dart` 控制器用例 | `a.md`、`sub/b.md` 临时目录；保存 `sub/b.md` 的 locator | 改前状态是阅读页五个可变字段；改后控制器给出同一 manifest、活动文件、文件内坐标 | 普通单文件书不进入文件夹会话 |
| 切文件不丢目标坐标 | 控制器用例 + `test/widget_test.dart` → `a folder book restores its saved file and own outline` | 从 `sub/b.md` 跳到 `a.md` 或反向选择 | 改前切文件逻辑散在 `_jumpTo` / `_openFolderFile`；改后 `selectFile` 保留 chapter / offset，widget 仍切到正确文档路径 | 重复选择当前文件不重置阅读器 |
| 坐标换算和事件归一化 | 控制器用例 | 文件夹进度 `0.75`、renderer 文件内进度 `0.5` | 改前换算方法只在阅读页可观察；改后互转等价，位置事件带文件相对路径与 `folderFileLocal: true` | 非 Markdown 事件、已归一化的 locator 不被重复换算 |
| 旧版定位与异步竞态 | 控制器用例 | 旧版 chapterIndex、受控延迟 manifest、同书重复 load、换书 load | 改前旧版映射与 FutureBuilder 状态耦合；改后旧版章节映射到正确文件，同书复用 Future，过期结果不覆盖新书会话 | 旧版索引越界不伪造目标文件 |
| 受影响回归 | `flutter test test/widget_test.dart test/renderers/markdown test/features/reader/markdown_folder_session_test.dart test/features/reader/reader_panels_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 PASS：90 项；日志 `/tmp/pagesage-folder-session-regression-20261109.log` | 文件夹阅读页、manifest、目录面板任一失败即不接受 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 648 passed / 2 skipped；日志 `/tmp/pagesage-check-folder-session-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |

实现状态：`IMPLEMENTED`；本切片验证证据：`TOOLING_PASS`；真实窗口与安装版 `E2E` 仍待用户验收。

已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建与本地安装成功，日志 `/tmp/pagesage-install-folder-session-20261109.log`；bundle `diff -qr` 无差异，构建与安装的 `libapp.so` SHA256 均为 `b65cfd522a70989eb44d10479698df992c1eb7cea9afd54c7dd7ca3b1bc76491`。未启动、关闭或重启已运行的 PageSage，已有进程需用户重启加载新版。

### P12：代码块语法高亮（2026-11-09）

用户要求继续把 Markdown 阅读向 Typora 靠齐。P8 已让代码块显示语言标签，本切片补上轻量语法着色，不引入编辑器、语法高亮包或 WebView：

- **词法信息是展示元数据。** `EpubCodeRun` 记录关键字、类型、字符串、数字、注释与字面量的章节字符范围；`EpubTextBlock.codeRuns` 穿过 `epubBlocks` 和分页片段。正文、搜索、进度、选区、批注仍共用同一个 `EpubChapter.text`，语言标签和不存在的 fence 都不进正文。
- **轻量语言词表。** `lib/renderers/common/code_syntax.dart` 覆盖 Dart、JavaScript/TypeScript、Python、Java/C/C++、Go、Rust、SQL、Shell、JSON、YAML 等常见 fence 与别名；无语言或未知语言只识别字符串和数字，不套用语言关键字词表。字符串和注释内部的词不会再被误判为关键字。
- **共享渲染链路。** 渲染器把语法范围和行内样式、批注、搜索命中、链接一起切成 `TextSpan`，语法颜色叠加在文字色上，批注底色与搜索底色仍可见。颜色随白昼、夜间与高对比主题切换，并对代码面板合成底色检查 WCAG AA 文本对比度。
- **不改数据库与 locator。** 本次没有 schema、JSON、渲染事件或阅读位置字段变化；EPUB 的手工 `<pre>` 代码块也复用同一展示规则，但此时没有章节语法 runs，保持原样。

改代码前声明验证矩阵（改前实现状态：`DESIGN_ONLY`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 词法范围不重叠、按章节定位 | `test/renderers/common/code_syntax_test.dart` → `runs stay sorted, disjoint and in chapter coordinates` | Dart 代码，`chapterOffset: 37` | 改前没有词法器；改后注释 / 关键字 / 数字 / 串落在原文范围，run 升序且互不覆盖 | 字符串里的 `// final 99` 不再生成注释或数字 |
| 多语言与未知语言降级 | 同文件 → `SQL words are matched without case sensitivity`、`supported aliases and unknown languages degrade quietly`、`an unlabelled fence still gets numbers and strings` | `SQL`、`py`、`brainfuck`、无语言 fence | 改前无语言识别；改后 SQL 大小写不敏感，别名生效，未知 / 无语言仍有字符串 / 数字而无关键字 | 未标语言的代码不套用关键词词表 |
| 解析后正文与偏移不变 | `test/renderers/markdown/markdown_parser_test.dart` → `fenced code gets syntax runs without changing its text` | 有语言 / 无语言两个代码块 | 改前 `codeRuns` 为空；改后两个代码块都有保守 runs，只有带语言代码块有关键字，`chapter.text` 仍含完整代码且不含 fence | 第二个代码块不因为语言缺省而生成关键字着色 |
| 分页保留语法范围 | `test/renderers/epub/epub_paginator_test.dart` → `code syntax runs keep their chapter offsets across pages` | 跨页 Dart 代码块，手工 chapter-offset runs | 改前片段没有 `codeRuns`；改后每个片段仍带原章节偏移与语言标签，正文拼接不丢字 | 分页不重写 run 的起止偏移 |
| 渲染着色与搜索底色共存 | `test/renderers/markdown/markdown_rendering_test.dart` → `a fenced code block colours syntax without changing words`、`syntax colours do not erase a search hit inside code` | Markdown 文件；连续模式；搜索 `final` | 改前代码只有单色；改后 `final` / `42` / 字符串各有主题色，普通标识符仍是正文色，搜索命中仍带底色 | 不显示 fence；语法颜色不覆盖搜索底色 |
| 所有主题可读性 | `test/renderers/common/code_syntax_test.dart` → `syntax colours meet WCAG AA on the code panel` | 10 个阅读主题合成代码面板底色 | 改前没有对比度证据；改后每种 token 对比度均 ≥ 4.5 | 任一主题低于阈值即不接受 |
| 聚焦回归 | `flutter test test/renderers/common/code_syntax_test.dart test/renderers/markdown/markdown_parser_test.dart test/renderers/markdown/markdown_rendering_test.dart test/renderers/epub/epub_paginator_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 PASS：74 项；日志 `/tmp/pagesage-syntax-focused-20261109.log` | 任一解析、分页、渲染或主题用例失败即不接受 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 667 项通过 / 2 skipped；日志 `/tmp/pagesage-check-syntax-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |

实现状态：`IMPLEMENTED`；本切片验证证据：`TOOLING_PASS`；真实窗口与安装版 `E2E` 仍待用户验收。

已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建与本地安装成功，日志 `/tmp/pagesage-install-syntax-20261109.log`；bundle `diff -qr` 无差异，构建与安装的 `libapp.so` SHA256 均为 `10a8058ba3d604ddba701712bcb467d67ac03398845bfadbd8d8da632c3baf96`。未启动、关闭或重启已运行的 PageSage，已有进程需用户重启加载新版。

### P13：数学、图表与 HTML 的可读边界（2026-11-09）

用户要求继续打磨 Markdown/Typora 阅读细节。P13 只收口「这些内容在纯文本阅读器里如何被安全、可读地呈现」，不引入公式排版引擎、Mermaid JS、WebView、HTML 执行或新依赖：

- **源码块边界。** 闭合的 `$$...$$` / `\[...\]` 显示数学、Mermaid / PlantUML / Graphviz / Dot 围栏显示图表源码，分别进入 `EpubBlockType.math` / `diagram`，带 `LaTeX` / `Mermaid` 安静标签。围栏和定界符不进正文；最长 20000 字符，超长截断。源码块按换行跨页，标签随片段保留。
- **行内边界。** `$...$` 与 `$$...$$` 保留表达式、去掉定界符，并以代码样式标记同一章节偏移上的 run；转义美元符与紧跟数字的货币金额不当作公式。
- **HTML 只留可见文字。** 行内和内嵌 HTML 去掉标签、注释、处理指令与远程 `src/href/srcset/poster`；`script`、`style`、`svg`、表单、媒体等危险标签整段移除，并以「已忽略 … 标签」说明。有限 HTML 实体解码为可见字符。
- **不丢原文。** 未闭合公式、围栏或未闭合 HTML 保留原行；普通代码围栏内的公式与图表标记不被改写。HTML 边界后的段落由自定义块语法解析，避免 Markdown 包把整块 HTML 当作不可解析的纯文本。
- **契约不变。** 展示变换仍写进唯一的 `EpubChapter.text`，块、行内 run、分页、搜索、选区、进度和 locator 共用同一套字符偏移；无 schema、JSON 或渲染事件变化。结构索引把公式 / 图表源码视作代码类块。

改代码前声明验证矩阵（改前实现状态：`DESIGN_ONLY`；验证证据：`UNVERIFIED`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 公式与图表保留源码和标签 | `test/renderers/markdown/markdown_boundaries_test.dart` → `display math becomes a labelled source block`、`a Mermaid fence becomes readable diagram source` | 闭合 `$$` 与 Mermaid 围栏 | 改前暴露原始定界符 / fence；改后为 `math` / `diagram` 块，正文与块偏移精确一致 | 无 `$$` / fence，普通代码仍为 code |
| 行内公式与偏移 | 同文件 → `inline math keeps its expression and chapter-offset run` | `$x^2$`、`$$y^2$$`、`\$10` | 改前 `$` 原样出现；改后表达式可读、带 code run，货币字符保留 | 转义金额不生成公式 run |
| HTML 安全可见文字 | 同文件 → `inline and embedded HTML keep only safe visible words`、`dangerous HTML blocks remove their source instead of showing it` | `<b>` / `<script>` / `<img src=…>` / `<a href=…>` / `<div>` / 注释 / `<style>` / `<svg>` | 改前原始标签、脚本文字和远程 URL 进入正文；改后只剩可见文字和忽略提示 | 不创建网络图片 Widget、不执行脚本、不显示远程 URL |
| 未闭合与代码围栏兼容 | 同文件 → `unclosed boundaries and code fences keep their original text` | 未闭合 `$$`、图表围栏、代码围栏内的 `$$` | 改前可能把代码围栏内内容吞成公式；改后普通围栏保持完整源码 | 不把未闭合围栏改写为边界块 |
| 输入预算 | 同文件 → `a very long math source stays bounded` | 20100 字符公式 | 改前没有上限；改后截断到 20000 字符并带省略号 | 不破坏后续块偏移 |
| 分页保留边界类型和标签 | `test/renderers/epub/epub_paginator_test.dart` → `math and diagram fragments keep their labels across line splits` | 30 行跨页 math / diagram 源码 | 改前新类型没有分页证据；改后各片段保留类型、标签和 continuation | 标签不丢，正文不丢 |
| 渲染不执行不安全内容 | `test/renderers/markdown/markdown_rendering_test.dart` → `math and diagrams are quiet labelled source panels` | Markdown 文件；连续模式 | 改前显示原始标签或脚本；改后为安静源码面板，无 `<script>` / `alert(1)` / 网络图片 Widget | 公式、Mermaid 标签各出现一次 |
| 内部标记不可被正文伪造 | 同文件 → `author-supplied boundary markers are ordinary text` | 作者手写 `<pagesage-safe-boundary …>` | 改前固定标签可能被误识别；改后每次解析使用随机 token，作者标记只作为普通文字 | 手写标记不产生 math 块 |
| 聚焦回归 | `flutter test test/renderers/markdown/markdown_boundaries_test.dart test/renderers/markdown/markdown_parser_test.dart test/renderers/markdown/markdown_rendering_test.dart test/renderers/epub/epub_paginator_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 初验 PASS：69 项；代码审查修复后 PASS：72 项，日志 `/tmp/pagesage-boundaries-focused13-postreview-20261109.log` | 任一解析、分页、渲染或安全用例失败即不接受 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 初验 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 677 项通过 / 2 skipped；代码审查修复后 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 680 项通过 / 2 skipped，日志 `/tmp/pagesage-check-boundaries-postreview-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |
| 发布准备 | `flutter test test/tool/release_readiness_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 初验 PASS：6 项、2 skipped（Android 产物不在本机）；代码审查修复后 PASS：6 项、2 skipped，日志 `/tmp/pagesage-release-readiness-boundaries-postreview-20261109.log` | Windows/Android 产物相关用例失败即不接受 |

实现状态：`IMPLEMENTED`；P13 初次验证为 `TOOLING_PASS`。2026-11-09 代码审查发现未知命名 HTML 实体会被误删，已改为保留原写法，并新增 `&copy;` / `&mdash;` 回归断言。修复后 Markdown 边界、解析、渲染与 EPUB 分页聚焦测试 72 项通过；`bash tool/check.sh` 的格式 0 改动、`flutter analyze` 0 问题、全仓 680 项通过 / 2 skipped；发布准备 6 项通过 / 2 skipped；目标文件格式检查与 `git diff --check` 通过。真实窗口与安装版 `E2E` 仍待用户验收。

修复后已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建与本地安装成功；bundle `diff -qr` 无差异，构建与安装的 `lib/libapp.so` SHA256 均为 `4db1294165ce8891062971e190e42fa5a833b101f7ab21854fc647ebb20d25e3`。未启动、关闭或重启已运行的 PageSage，已有进程需用户重启加载新版。

### P14：Markdown 数学公式排版（2026-11-09）

用户截图显示题目中的 `$...$` 公式仍以 `\displaystyle \lim...` 原文显示，部分独立公式被画成带 `LaTeX` 标签的灰色源码框。本切片修复「可读但不可读公式」的问题，不改写阅读坐标体系。后续截图复核又补修了两个边界：以 `\}` 结尾的行内公式被漏识别，以及分页把一条行内公式从中间切断。

- **本地渲染。** 新增 `flutter_math_fork: ^0.7.4`，使用随包分发的 KaTeX 字体绘制公式；没有 WebView、JS、远程字体或在线服务。第三方许可清单随 `pubspec.lock` 重新生成。
- **公式元数据。** `EpubTextBlock.mathSource` 保存独立公式的 TeX 源码，新增 `EpubInlineStyle.math` 与 `EpubInlineRun.mathSource` 保存行内公式；两者沿 `epubBlocks`、`EpubPageFragment` 与 `_EpubFragmentView` 传递，不进入 `EpubChapter.text`。搜索、进度、选区、批注、AI 引用和 locator 仍使用同一份章节字符。
- **常见笔记写法。** `MathSource` 去掉 `$` / `$$` / `\[` / `\(` 定界符，并把 `\frac1{x^2}`、`\dfrac12` 一类紧凑写法补成带花括号参数。无效或库无法构建的公式回退到原表达式文本，不显示解析错误或空白。
- **视觉与分页。** 独立公式居中、可横向滚动；行内公式作为 `WidgetSpan` 与正文基线对齐，并用 `SelectionContainer.disabled` 避免与父级选区冲突。分页器为公式的分数 / 极限 / 根号高度额外预留空间；图表和 HTML 边界保持 P13 行为。
- **边界补修。** 行内公式识别允许内容以 `\}` 等转义序列结尾，并把 `$$...$$` 限制在同一行，避免跨段误吞；分页切段时若落点位于一条行内公式内部，就把整条公式移到下一段，并为其高度预留空间，不再让两页各显示半条公式。

改代码前声明验证矩阵（改前实现状态：`IMPLEMENTED_BUT_WRONG_VISUAL`；验证证据：`SCREENSHOT_DEFECT`）：

| 行为 / 契约 | 最小检查 | 夹具 / 输入 | 预期信号与改前失败 | 负例 |
| --- | --- | --- | --- | --- |
| 紧凑 TeX 可解析 | `test/renderers/common/math_source_test.dart` | `\displaystyle \lim_{x\to0}\frac1{x^2}` | 改前公式源码泄漏；改后归一化成 `\frac{1}{x^2}` 并通过 TeX 解析器 | `\frac{1}{` 明确判为无效 |
| 独立公式携带源码且正文偏移不变 | `test/renderers/markdown/markdown_boundaries_test.dart` | 闭合 `$$` 公式 | `mathSource` 非空，章节 substring 与块文本一致 | 图表 / HTML 不产生公式源码 |
| 行内公式携带源码 | 同文件 → `inline math keeps its expression and chapter-offset run`、`inline math ending in an escaped brace stays whole`、截图同款公式 | `$x^2$`、`$$y^2$$`、`\displaystyle \frac1{x^2}`、`$D=\{(x,y)\mid x^2+y^2\le4,\ y\ge0\}$` | 公式 run 为 `math`，`mathSource` 可解析，可读表达式仍在章节文本里；以 `\}` 结尾的公式不再退回源码 | 转义金额不产生公式 run；跨行 `$$` 不合并成一条 |
| 连续模式画公式而非源码 | `test/renderers/markdown/markdown_rendering_test.dart` | 显示公式、行内公式、坏公式 | 正常样本出现 `Math` Widget 且不显示 `\displaystyle` / `\frac1`；坏公式显示原表达式且无异常 | 图表仍显示 Mermaid 源码，HTML 仍只显示安全文字 |
| 分页保留公式契约 | `test/renderers/epub/epub_paginator_test.dart` → `an inline formula is never cut between page fragments`、`math and diagram fragments keep their labels across line splits` | 30 行 math / diagram 源码；长段落中间夹一条行内公式 | 标签与 continuation 不丢；没有片段从公式中间开始或结束；公式高度预留不破坏分页 | 分页不把公式文字当成公式执行，也不把半条公式留在一页上 |
| 聚焦回归 | `flutter test test/renderers/common/math_source_test.dart test/renderers/markdown/markdown_boundaries_test.dart test/renderers/markdown/markdown_parser_test.dart test/renderers/markdown/markdown_rendering_test.dart test/renderers/epub/epub_paginator_test.dart test/renderers/epub/epub_annotation_rendering_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 PASS：80 项；日志 `/tmp/math_fix_focused2.log` | 任一解析、分页、渲染或安全用例失败即不接受 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | 当前工作区 | 2026-11-09 PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 687 项通过 / 2 skipped；日志 `/tmp/pagesage-check-math14b-20261109.log` | 任一聚焦测试失败即不接受全绿聚合 |
| 发布准备 | `flutter test test/tool/release_readiness_test.dart --concurrency=4` | 当前工作区 | 2026-11-09 PASS：6 项、2 skipped（Android 产物不在本机）；日志 `/tmp/pagesage-release-readiness-math14b-20261109.log` | 许可清单或资源检查失败即不接受 |

实现状态：`IMPLEMENTED`；本切片验证证据：`TOOLING_PASS`。已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，日志 `/tmp/pagesage-install-math14b-20261109.log`；bundle `diff -qr` 无差异，构建与安装的 `lib/libapp.so` SHA256 均为 `51cfd78049c35c40428a7ae9e56f7069408d91a397288d8ae683568b0684836a`。未启动、关闭或重启已运行的 PageSage，已有进程需用户重启加载新版。真实窗口与安装版 `E2E` 仍待用户验收。

### P14 补修：短章节阅读列塌缩（2026-11-09）

用户截图里同一页正文左边距约 130 px，而「则（ ）。」与四个选项左边距约 405 px。这不是换行，是连续模式下 `Center` + `ConstrainedBox(maxWidth: 760)` 的约束没有确定宽度：章节内容较短时，`ConstrainedBox` 退化为按最宽子项 shrink-wrap，随后被 `Center` 居中，读起来像整段文字突然缩进到页面中间。选项行本身比上一行窄，于是最明显的偏移落在选项上。

- **修复。** 连续模式的每个章节切片在 `ConstrainedBox` 内加 `SizedBox(width: double.infinity)`，先把可用宽度撑满再限制最大阅读宽度；分页模式的页列做同样处理。阅读列左边缘因此始终对齐，不再由当前最宽的一行决定。
- **回归。** 新增 `short prose after display math keeps the reader column`：显示公式之后接一行短正文「则（ ）。」，断言其 `dx` 与正文列一致（24 px）；修复前该行会被公式宽度 shrink-wrap 后居中。原有的外链、选区与分页用例继续通过。
- **证据。** Markdown 渲染 / EPUB 连续切片 / 分页聚焦 45 项通过，日志 `/tmp/pagesage_layout_tests.log`；`bash tool/check.sh` 格式 0 改动、`flutter analyze` 0 问题、全仓 688 项通过 / 2 skipped，日志 `/tmp/pagesage_check.log`；发布准备 6 项通过 / 2 skipped，日志 `/tmp/pagesage_release_readiness.log`。
- **安装。** 已静默重装，bundle `diff -qr` 无差异，构建与安装的 `lib/libapp.so` SHA256 均为 `635b0b5d8a66832b4ae25961a8ac33e51a775001b9447ae749a9adc460e6c9bc`。未启动、关闭或重启已运行的 PageSage，已有进程需用户重启一次加载新版。

### P15：表格列对齐、标题内链与连续模式点击区（2026-11-09）

继续向 Typora 阅读行为靠齐。这一轮处理三件用户能看到、也会实际影响点击的行为，不改章节文本、搜索、进度或 locator：

- **表格列对齐。** `package:markdown` 已把 `:---` / `:---:` / `---:` 写进每个单元格的 `align` 属性；解析器把它收进 `EpubTableBlock.alignments`，再沿 `EpubBlock`、分页片段和连续切片传到渲染层。单元格文字撑满列宽后按 `TextAlign.left` / `center` / `right` 排版，表头与续页表头沿用同一列对齐。未写对齐的列仍按左对齐。
- **标题内链。** 一至六级标题在解析时记录 GitHub 风格锚点：小写、去标点、空格转连字符，同名标题追加 `-1`、`-2`。普通 `[文字](#标题)` 现在保留 `#...` 目标并走现有内部跳转事件；解析时对百分号编码做一次解码，未知锚点安静忽略，不弹外链确认，也不伪造跳转。
- **连续模式不再覆盖正文。** 左右各 96 px 的翻页热区原先在连续滚动模式也叠在正文上，链接和选区在页面边缘会被挡住。现在连续模式移除这两块热区，翻页仍由滚动、键盘 PageUp/PageDown 与工具栏负责；分页模式保留左右点击翻页。
- **契约不变。** 表格对齐与标题锚点都是展示元数据，不进入 `EpubChapter.text`；标题锚点不占字符，表格文字仍参与搜索、选区、进度与 AI 引用。

| 行为 | 最小检查 | 结果 |
| --- | --- | --- |
| 表格列对齐进入模型 | `test/renderers/markdown/markdown_parser_test.dart` → `table delimiters keep each column alignment` | PASS：四列分别为 left / center / right / none |
| 连续与分页都按列对齐绘制 | `test/renderers/markdown/markdown_rendering_test.dart` → `table columns follow their delimiter alignment`、`paged tables keep their column alignment` | PASS：正文与表头 `TextAlign` 正确，分页路径不丢对齐 |
| 标题锚点生成与去重 | 同解析文件 → `headings get GitHub-style link anchors` | PASS：`getting-started`、中文标题、`重复标题-1` 均可查 |
| 标题链接发出内部跳转 | 同渲染文件 → `a heading link jumps inside the document` | PASS：落在目标标题偏移，且不产生外链事件 |
| 连续模式边缘链接可点 | 同上测试使用贴左边缘的链接 | PASS：移除翻页热区后链接可命中 |
| 聚焦回归 | `flutter test test/renderers/markdown/markdown_parser_test.dart test/renderers/markdown/markdown_rendering_test.dart test/renderers/epub/epub_paginator_test.dart test/renderers/epub/epub_continuous_slicing_test.dart --concurrency=4` | PASS：72 项，日志 `/tmp/pagesage_md_align_links4.log` |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 693 项通过 / 2 skipped，日志 `/tmp/pagesage_check_md_align.log` |
| 发布准备 | `flutter test test/tool/release_readiness_test.dart --concurrency=4` | PASS：6 项通过 / 2 skipped，日志 `/tmp/pagesage_release_md_align.log` |

实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。已静默执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，日志 `/tmp/pagesage_install_md_align.log`；bundle `diff -qr` 无差异，构建与安装的 `lib/libapp.so` SHA256 均为 `97252edbe30fb8387352a64fd5276f4b34f8f241c3d9d0f207ab15c3c690f289`。安装后已重启本地实例（PID `673981`，启动日志 `/tmp/pagesage_restart.log`）；真实阅读体验与 Windows/Android 仍未验证。

### P16：嵌套引用层级（2026-11-09）

继续向 Typora 阅读行为靠齐。旧实现把每一层 `>` 都收成同一个 `quote` 块，再统一画一根竖线，读者无法从缩进看出引用嵌套。本轮补齐 Markdown 与 EPUB 共用的展示层级，不改正文：

- **深度元数据。** 文本、表格、图片和分隔线块都带 `quoteDepth`，记录被几层 blockquote 包住；Markdown 与 EPUB 解析器都在进入 `blockquote` 时递增，退出自然恢复。深度不写入 `EpubChapter.text`，搜索、选区、进度、批注和 locator 偏移不变。
- **穿过排版层。** 深度沿 `EpubBlock`、`EpubPageFragment`、分页器和连续切片传递；分页测量按每层 16 px 缩窄文字列。标题、列表、表格、代码、图片、分隔线和独立公式等任意块只要位于引用内都使用同一预算。列表还会叠加自身的悬挂缩进，表格列宽按收窄后的可用宽度分配，避免绘制比测量宽而出现错误换行。
- **逐层竖线。** 渲染层对 `quoteDepth > 0` 的任意块按深度嵌套边框与 padding，每一层都保留自己的引用竖线；不再只处理 `quote` 块类型。单层引用保持原阅读层级的安静样式，不增加卡片或背景块。

| 行为 | 最小检查 | 结果 |
| --- | --- | --- |
| 解析器保留三层引用深度 | `test/renderers/markdown/markdown_parser_test.dart` → `nested quotes keep their depth` | PASS：文字依次为外层 / 内层 / 深层，深度为 1 / 2 / 3 |
| EPUB 解析器保留三层引用深度 | `test/renderers/epub/epub_document_loader_test.dart` → `nested EPUB blockquotes keep their depth` | PASS：三层 `<blockquote>` 文字深度为 1 / 2 / 3 |
| 分页不丢深度且列宽变窄 | `test/renderers/epub/epub_paginator_test.dart` → `nested quote depth survives pagination and narrows the text column` | PASS：片段深度为 1 / 2 / 3，三层测量宽度小于单层 |
| 分页中的非文本块保留深度 | `test/renderers/epub/epub_paginator_test.dart` → `non-text blocks in a quote carry their depth into pages` | PASS：引用内分隔线、图片、表格片段深度均为 2 |
| 真实渲染逐层右移 | `test/renderers/markdown/markdown_rendering_test.dart` → `nested Markdown quotes indent by level` | PASS：相邻两层正文起点都相差 16 px |
| 引用内表格不越出引用列 | `test/renderers/markdown/markdown_rendering_test.dart` → `a table inside a quote stays inside the quote column` | PASS：表头起点在引用正文右侧，表格右边界不越过阅读器 |
| 聚焦回归 | 上述四个文件 | PASS：82 项，日志 `/tmp/pagesage_quote_focus_final.log` |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | PASS：格式 0 改动、分析 0 问题、704 项通过 / 2 skipped，日志 `/tmp/pagesage_check_quote_final2.log` |

实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。已静默安装，bundle `diff -qr` 无差异，构建与安装 `libapp.so` SHA256 均为 `beccaccf0b9c260341765a73614f2e5c12180d34c50fca013e26844620631056`；安装后已重启本地实例（PID `1085852`）。真实窗口视检与 Windows/Android 仍未验证。

### P17：引用内标题不改变章节结构（2026-11-09）

继续补齐引用内混合内容的语义。旧实现只要遇到引用里的 `h1` 就调用 `_startChapter`，把一句被引用的标题错误地拆成新章节；引用里的 `h2` 还会进入当前章节的大纲。本轮只修结构边界，不改标题视觉：

- **引用内 `h1` 不再切章。** `quoteDepth > 0` 时交给普通标题块处理，保留一级标题字号、章节内锚点和引用层级；只有顶层 `h1` 才开启新章节。
- **引用内 `h2` 不写入章节目录。** 大纲子项只在 `quoteDepth == 0` 时收集，避免侧边栏出现不属于正文结构的引用标题。
- **偏移与检索不变。** 标题文字仍写入唯一章节文本；搜索、选区、进度、批注和 locator 继续使用原字符偏移。

| 行为 | 最小检查 | 结果 |
| --- | --- | --- |
| 引用标题不切章、不进大纲 | `test/renderers/markdown/markdown_parser_test.dart` → `headings inside quotes stay in the current chapter` | PASS：文档仍为两章；引用内 `h1` / `h2` 深度为 1 / 2，一级大纲无子项，块偏移与正文逐字一致 |
| 引用标题仍按引用缩进呈现 | `test/renderers/markdown/markdown_rendering_test.dart` → `quoted headings keep quote indentation without a new chapter` | PASS：引用正文比普通段落右移 16 px，标题仍在当前章内显示 |
| 聚焦回归 | Markdown 解析 / 渲染与 EPUB 分页三个文件 | PASS：78 项，日志 `/tmp/pagesage_quote_heading_focus.log` |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | PASS：格式 0 改动、分析 0 问题、706 项通过 / 2 skipped，日志 `/tmp/pagesage_check_quote_heading.log` |

实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。已静默安装，bundle `diff -qr` 无差异，构建与安装 `libapp.so` SHA256 均为 `5fb96b7a1b5eb7774134919e0ece8050c69d992318ac069c79c4a43c44f350f0`；安装后已重启本地实例（PID `1232741`）。真实窗口视检与 Windows/Android 仍未验证。

### P18：表格单元格内联样式与链接（2026-11-10）

继续把表格细节对齐 Typora 阅读体验。P3 让表格保留行列，P15 让列对齐生效，但单元格里的 `**粗体**`、行内代码、删除线和链接仍被当作纯文本，读者会看到原始标记。本轮让单元格复用正文的行内 run：

- **单元格模型。** 新增 `EpubTableCell`，保存单元格文字和相对该文字的 `EpubInlineRun`。表格文字仍按 `   ` 与换行拼进章节文本，搜索、进度、选区和 locator 偏移不变。
- **解析复用正文规则。** `_addTable` 用 `_draftFor` 生成每个单元格的文字与 run；粗体、斜体、删除线、行内代码、链接、脚注引用与行内公式都走与段落相同的解析路径。
- **穿过排版层。** `EpubTableBlock`、`EpubBlock`、`EpubPageFragment`、分页行切分和连续模式切片都携带 `tableCells`。跨页表格重复表头时，表头与正文单元格的 run 一并保留。
- **渲染与测量一致。** 单元格改用 `Text.rich`；表头仍先给 `w600`，单元格内的 `strong` 再叠加到 `w700`，代码使用等宽字体，链接有主题色和下划线，并复用正文的外链确认与内部跳转回调。分页测量用同一套 `epubInlineRunStyle` 构建样式文本，避免粗体或代码导致测量与绘制不一致。
- **边界不变。** 单元格 run 使用单元格局部偏移，不进入章节文本；未知锚点、危险协议、空单元格和纯文本单元格保持原行为。

| 行为 | 最小检查 | 结果 |
| --- | --- | --- |
| 解析保留单元格 run | `test/renderers/markdown/markdown_parser_test.dart` → `table cells keep their inline styles and links` | PASS：文字不含 Markdown 标记；粗体、代码、链接 run 的范围和 target 正确；表格偏移仍与章节文本逐字一致 |
| 渲染粗体、代码与链接 | `test/renderers/markdown/markdown_rendering_test.dart` → `table cells set inline styles and links like prose` | PASS：粗体 `w700`、代码 `monospace`、链接下划线；点击单元格链接只发出宿主外链事件；页面不显示 `**` 或 `](` |
| 跨页保留单元格 run | `test/renderers/epub/epub_paginator_test.dart` → `table cell runs survive row splitting and repeated headers` | PASS：长表格按行跨页，每页重复表头，表头粗体与正文斜体 run 都保留局部范围 |
| 聚焦回归 | Markdown 解析 / 渲染与 EPUB 分页三个文件 | PASS：81 项 |

实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。已静默安装，bundle `diff -qr` 无差异，构建与安装 `libapp.so` SHA256 均为 `6dc082d6d148fcd809ddd66cd9dfa9c5f723968378cb564b4b30b11ff1e08d7e`；安装时运行中的旧实例 PID `1097526` 未重启，后续已由用户重启。真实窗口视检与 Windows/Android 仍未验证。

### P19：表格单元格搜索、批注与聚焦（2026-11-10）

P18 让表格单元格拥有行内样式，但搜索命中、批注高亮和临时聚焦仍只作用于普通段落。本轮给每个单元格补上章节坐标，让这三个阅读态在表格里也成立：

- **单元格章节坐标。** `EpubTableCell` 新增 `chapterOffset`，解析器按 `   ` 和换行实际拼出的章节文本计算每个单元格起点；局部 run 仍相对单元格文字，搜索和批注则通过该起点映射回章节偏移。
- **搜索命中。** 单元格内的不区分大小写匹配沿 `Text.rich` 的 span 切分着色，代码、粗体和链接样式不会被搜索高亮覆盖掉。
- **批注高亮与点击。** 有 locator offset 的批注与单元格章节范围求交，再转成局部 span；旧批注没有 offset 时退回单元格内文字匹配。高亮、下划线、点击发出 `RendererAnnotationSelected` 与正文一致。
- **临时聚焦。** 搜索跳转 / 笔记跳转的 focus range 同样按章节偏移映射到单元格。顺带修正 `epubFocusRangeFor` 只接受 `epub` locator 的问题，Markdown locator 现在也能产生聚焦范围。
- **跨页一致。** 表格按行分页和重复表头时，单元格对象及其章节坐标原样传递；续页上的搜索、批注和聚焦仍能落到正确文字。

| 行为 | 最小检查 | 结果 |
| --- | --- | --- |
| 解析记录单元格章节坐标 | `test/renderers/markdown/markdown_parser_test.dart` → `table cells keep their inline styles and links` | PASS：每个单元格的章节切片都等于自身文字 |
| 搜索 / 批注 / 聚焦同时生效 | `test/renderers/markdown/markdown_rendering_test.dart` → `table cells carry search hits, annotations and focus marks` | PASS：批注黄色高亮且可点击、搜索命中与聚焦底色分别落在对应 span |
| Markdown locator 可聚焦 | `test/renderers/epub/epub_jump_test.dart` → `accepts Markdown locators on the same chapter offsets` | PASS：章节、起止偏移与 EPUB locator 同义 |
| 聚焦回归 | Markdown 解析 / 渲染、EPUB 分页与跳转四个文件 | PASS：96 项 |

实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。已静默安装，bundle `diff -qr` 无差异，构建与安装 `libapp.so` SHA256 均为 `d26f8c1281d6b4bd133e803c67220e8a6b3215868d17deb082885aa8db8deb80`；安装时运行中的 PID `2633513` 启动于安装前，未重启，待用户手动重启后生效。真实窗口视检与 Windows/Android 仍未验证。

### P20：行内公式与安全 HTML 语义（2026-11-11）

继续收口 Typora 风格的行内阅读边界。上一轮已经支持 `$...$`、`$$...$$` 与独立 `\[...\]`，但常见的 `\(...\)` 行内公式仍会显示反斜杠；行内 HTML 虽已去除危险标签，`<br>` 会被吞掉，`<u>`、`<mark>`、`<sup>`、`<sub>` 也只留下文字而没有阅读语义。

- **公式定界符。** `\(...\)` 与 `$...$` 走同一条行内公式路径：定界符不进入章节文本，表达式保留在同一字符范围，交由本地 TeX 排版；无效公式继续安静回退为可读表达式。
- **安全 HTML 语义。** 成对的 `<b>/<strong>`、`<i>/<em>`、`<s>/<strike>/<del>`、`<u>`、`<mark>`、`<sup>`、`<sub>` 与 `<kbd>` 在去除标签后生成对应行内 run；属性、脚本、远程地址和未知标签仍不进入正文，也不产生可执行内容。
- **换行。** 行内 `<br>` 还原为一次软换行，不再被空白归一化吞掉；块级 HTML 的既有安全边界不变。
- **契约不变。** 行内语义只增加展示元数据，不写数据库，不改 locator、搜索、选区、进度或 AI 引用；分页测量与绘制继续共用 `epubInlineRunStyle`。

| 行为 | 最小检查 | 结果 |
| --- | --- | --- |
| `\(...\)` 公式进入同一文本契约 | `test/renderers/markdown/markdown_boundaries_test.dart` → `slash-delimited inline math keeps the same text contract` | PASS：章节文本保留表达式、去掉定界符，run 为 math 且 TeX 可解析 |
| 安全 HTML 语义与 `<br>` | 同文件 → `safe inline HTML keeps its reading semantics and line breaks` | PASS：粗体、下划线、高亮、键盘、上下标 run 正确，标签不出现在正文，`<br>` 产生换行 |
| 渲染样式实际生效 | `test/renderers/markdown/markdown_rendering_test.dart` → `safe inline HTML keeps its reading styles and line breaks` | PASS：粗体、下划线、高亮底色、等宽键盘样式与上下标 font features 均到达 TextSpan |
| 聚焦回归 | Markdown 边界 / 渲染与 EPUB 分页三个文件 | PASS：70 项，日志 `/tmp/pagesage-p20-focused-1.log` |
| 全仓格式 / 分析 / 回归 | `flutter analyze`、`flutter test --concurrency=4` | PASS：分析无问题；957 项通过、5 项按环境跳过，日志 `/tmp/pagesage-p20-analyze-2.log`、`/tmp/pagesage-p20-full-1.log` |

实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。已静默安装，日志 `/tmp/pagesage-p20-install-1.log`；bundle `diff -qr` 无差异，构建与安装的 `pagesage` SHA256 均为 `ad58a1c45c52438faa74c546cb558e75bad856e7aac4c3ac2eb459f639a47210`，`libapp.so` 均为 `ae632e4591c9e471961e571554a09a1cbdc337ca7b06b4f76c55e5c17cdedbc1`。安装时没有运行实例，未启动窗口；真实窗口视检与 Windows/Android 仍未验证。

### P2 实现说明

- **原地读取，不复制。** 目录书的 `libraryFilePath` 就是用户选的那个目录；`fileHash` 是 `dir:` + 规范化绝对路径的 sha256，同一个目录重复导入是重复书，目录搬家就是另一本书。这是 `AGENTS.md`「导入必须复制进书库目录」的唯一例外，已写进 `AGENTS.md`。
- **删除书不会删目录。** 书库「删除应用副本与数据」对目录书跳过 `libraryFilePath`，`Book.isFolderBook` 负责判断（Markdown 且路径不以 `.md`/`.markdown` 结尾）。
- **文件夹书按文件打开。** 阅读器先用 `MarkdownFolderManifest` 发现文件与目录树，只把当前文件交给 `MarkdownDocumentLoader`；每个文件仍按单文件规则解析（有 `#` 按一级标题分章，没有就整篇一章，标题取文件名），章节的 `href` 由文件夹加载器写成相对路径。
- **目录书进度是全书进度。** locator 的 `chapterIndex` / `chapterOffset` 属于当前文件，`progress` 按 manifest 里的文件大小加权到全书；`folderFileLocal: true` 区分新版 locator。旧的合并 locator 通过一次 legacy 文档映射到「文件 + 文件内章节」。
- **跳过 `node_modules` 和所有隐藏目录**（`.git`、`.obsidian`、`.trash`），按相对路径排序。
- **上限**：2000 个文件、合计 64 MB，超过时明确报错而不是把机器拖死。
- **读不了的文件不静默消失**：文件树仍保留该文件；打开失败时在阅读区给出可读错误，不在别的文件里伪造正文。
- **入口**：书库头部与空书库都只有一个「导入」菜单——「导入文件」「扫描文件夹（每个文件一本书）」「把文件夹作为一本书」。拖拽只接文件，不猜文件夹意图。
- **性能（2026-11-05 实测修正）**：真实笔记库打开时卡死并闪退，原因是两件事——
  1. 解析图片时把每张图的**全部字节**读进文档对象：一个带截图的笔记库几百 MB 图片全在内存里，1 GB 峰值后被系统杀掉。现在 `EpubImage` 只记 `sourcePath` 和从文件头读到的尺寸，渲染时才由 `Image.file` 加载，并按页面宽度 `cacheWidth` 解码；`data:` 图片仍走内存。
  2. 整个目录的读取与解析跑在 UI isolate 上，500 篇约 2.3 秒，窗口直接冻住。现在放进 `Isolate.run`，界面保持可滚动并显示加载指示。
  另加一层缓存：单文件按「大小 + 修改时间」、目录按「全部文件的路径/大小/修改时间」指纹缓存解析结果（最多 2 个目录、4 个文件），阅读器、目录面板、索引器共享同一个 Future，编辑后指纹变化会自动重解析。实测 500 篇 + 500 张 1 MB 图片：首次 2.2 s / RSS 243 MB，二次打开 55 ms。
- **真实进程复测（2026-11-05，已归档 2026-11-08）**：按秒采样的 `.codex-run/watch_app.sh`（不入库）记录到三次安装版进程峰值 RSS 分别为 534 MB、361 MB、219 MB，最后一次从 14:58:32 稳定运行到 15:00:27 后正常退出；栈采样没有显示 Markdown 持续分配。此前 `匿名样本 04` 笔记库约 900 MB／闪退的「未定位」描述早于这些复测，且此后又落地了 P3 表格、P4 切章分片与分页缓存、P5 行内样式，因此该旧观察已被更新证据取代，不再作为当前阻塞项。日志未记录样本名与操作人，所以不升级为正式用户验收；若安装版再次复现，应按下面的手测步骤重新留痕。

## 涉及模块和文件

- `lib/domain/books/book.dart`、`reading_position.dart`
- `lib/core/files/format_detector.dart`、`metadata_extractor.dart`
- `lib/renderers/markdown/markdown_document_loader.dart`、`markdown_parser.dart`
- `lib/features/reader/presentation/reader_page.dart`
- `lib/core/search/search_indexer.dart`
- `lib/features/library/*`、`lib/features/search/presentation/search_page.dart`
- `lib/core/platform/file_picker_service.dart`、`lib/features/import/application/import_use_case.dart`

## 数据与接口

- 无数据库 schema 变更：`books.format` 是文本列，写入 `md` 即可。
- `ReadingLocator` 新增 `markdown` 类型，字段复用 EPUB 那组（章节索引 + 章节内偏移 + 进度）；旧数据反序列化行为不变。
- 文档模型暂沿用 `EpubDocument` / `EpubChapter` / `EpubBlock` 这组类型。它们是「排版文档」而不是「EPUB 专属」，改名留到有第三个格式时一起做。

## UI 与交互

- 阅读界面与 EPUB 完全一致：同一套主题、字号、行距、分页/连续模式、目录、进度。
- 书库里的 Markdown 书和文本类 EPUB 一样显示文字封面，格式徽标为 `MD`。
- 没有正文可读（空文件）时给出可读提示，不是空白页。

## 验收标准

- [x] 导入一个 `.md` 文件后出现在书库，打开能看到排好版的正文。
- [x] 标题、列表、引用、代码块、图片都按预期呈现，不是带标记的原文。
- [x] 多层引用按层级逐级缩进并保留各自的竖线，正文和阅读位置不受展示层级影响。
- [x] 引用内的标题按引用层级呈现，不拆分章节，也不混入章节目录。
- [x] 表格按行列排版：表头加粗、行间有分隔线，长表格跨页时重复表头；`:---` / `:---:` / `---:` 的列对齐生效；分隔行列数与表头不一致的表格也能正常解析。
- [x] 表格单元格内的粗体、斜体、删除线、行内代码、链接和行内公式按正文样式呈现，跨页表格仍保留这些样式与链接目标。
- [x] 表格单元格内的搜索命中、批注高亮、批注点击和临时聚焦与正文一致，跨页后仍落在正确文字上。
- [x] 行内样式按原文呈现：粗体、斜体、删除线、行内代码、链接有各自的字形/颜色，正文里不残留 `**`、`` ` ``、`[]()`；标题按一到六级递减，一级最大；`---` 画成细线而不是三个连字符。
- [x] 列表换行对齐到内容列；安全外链点击后由宿主确认地址再打开；图片的 `alt` 显示为安静图注，不参与正文偏移。
- [x] 脚注引用以小号带色文字呈现，脚注定义在分隔线后以缩小列表呈现，GFM 回链箭头不进入正文。
- [x] 点击脚注引用能跳到同章或后章的脚注定义；内部跳转不弹外部链接确认框。
- [x] 点击 `[文字](#标题)` 能跳到同文档的对应标题；未知标题锚点安静忽略。
- [x] 目录列出各级标题，点击能跳到对应位置。
- [x] 关闭再打开，回到上次阅读位置。
- [x] 全文搜索能命中 Markdown 正文，结果可跳转。
- [x] 远程图片不加载，缺失图片有可读占位。

## 测试与验证

- 单元测试：解析器（标题层级、列表、引用、代码、表格、表格分隔行容错、图片、front matter、空文件）。
- 单元测试：分页器把长表格按行切开并重复表头；渲染测试断言表格画成 `Table` 而不是管道符文本。
- 单元测试（P5）：行内 run 的偏移指向原文（粗体就是「粗体」四个字）、嵌套样式叠加、标题层级、`---` 成为分隔块；分页片段带着 run 与层级；widget 测试断言粗体 `w700`、斜体 `italic`、代码 `monospace`、链接有下划线、标题字号随层级递减、分隔线画成 1 px 细线且不显示 `---`。
- 单元测试 / widget 测试（P6）：列表分列与透明占位、链接目标及危险链接负例、可用图 / 占位图图注、EPUB 可用图图注；分页断言链接目标、悬挂宽度与图注高度。
- 单元测试 / widget 测试（P7）：文件夹 manifest 保留子目录树、文件大小加权进度、单文件大纲不混入其他文件、旧版 locator 映射、64 MB 上限；阅读器断言保存文件恢复、切文件只加载当前文件、导入菜单三项。
- 单元测试 / widget 测试（P9）：脚注 run 偏移、脚注定义 caption 块与分隔线、回链箭头移除；离屏截图 `build/workbench-captures/markdown-footnotes.png` 检查引用字号、分隔线与脚注列表。
- 单元测试 / widget 测试（P10）：脚注 target 与章节锚点、跨章引用、分页后 target 保留、点击只发内部跳转事件、缺失锚点负例、连续模式按块偏移落点。
- 单元测试 / widget 测试（P11）：文件夹会话控制器、文件切换与坐标互转、renderer 事件归一化、旧版 locator、同书缓存、换书竞态，以及阅读页文件夹用例。
- 单元测试 / widget 测试（P18）：表格单元格文字与局部 run、粗体 / 代码 / 链接的渲染与点击、长表格跨页重复表头时 run 保留。
- 单元测试 / widget 测试（P19）：单元格章节坐标、搜索命中、批注高亮与点击、Markdown locator 聚焦、分页续页映射。
- 单元测试：格式识别与元数据提取。
- Widget 测试：Markdown 书在阅读器里渲染出块。
- `dart format .`、`flutter analyze`、`flutter test`。
- 集成测试（离屏虚拟 Wayland，真实 Linux 窗口）：`.codex-run/samples/markdown-note.md` 打开后正文、列表、引用、代码、表格都排版呈现，capture 见 `build/integration-captures/markdown-01-prose.png`；`markdown-picture-note.md` 验证可用图与缺失图的 `alt` 图注，capture 见 `markdown-02-picture-captions.png`；现场生成的含子目录文件夹验证 `文件` / `大纲`、切文件与当前正文，capture 见 `markdown-03-folder-outline.png`、`markdown-04-folder-file-tree.png`、`markdown-05-folder-switched-file.png`。
- 真实应用：待用户在 `tool/install_linux.sh` 更新后的安装版里手测导入、阅读、进度、搜索，以及把一个真实笔记文件夹作为一本书打开。

## 验证矩阵（2026-11-08 执行记录）

| 行为 / 契约 | 检查 | 证据级别 | 当前信号 |
| --- | --- | --- | --- |
| 文档链接与发布资源 | `test/tool/release_readiness_test.dart` → `documentation links and release assets stay valid` | TOOLING | 2026-11-08 PASS：修前把文档示例 `a.png` 当成断链，链接检查改为忽略图片语法并通过 |
| 格式、分析、全量单测 | `bash tool/check.sh` | TOOLING | 2026-11-08 P7 UI 收口后 PASS：`dart format` 204 files / 0 changed、`flutter analyze` 0 问题、`flutter test` 528 passed / 2 skipped |
| Markdown 单文件解析与排版 | `flutter test test/renderers/markdown` | TOOLING | 包含在 2026-11-08 `flutter test`；历史 `test-suite-typora.log` 亦全绿 |
| 目录书解析、进度、搜索、AI 上下文 | `test/renderers/markdown/markdown_folder_test.dart`、`test/core/search/search_indexer_test.dart`、`test/features/ai/ai_context_source_test.dart` | TOOLING | 2026-11-08 P7 包含在全量 `flutter test`：manifest 子目录树、文件大小加权进度、逐文件搜索、活动文件 AI 上下文均 PASS |
| 真实窗口打开 Markdown | `integration_test/reader_markdown_test.dart` | RUNTIME | 2026-11-08 在隔离虚拟 Wayland 会话 PASS：单文件排版、图片 `alt` 图注、文件夹 `文件` / `大纲` 与切文件共 3 项；截图 01–06 刷新；代码块占满列宽、列表间距收紧 |
| P6 聚焦行为 | `markdown_parser_test.dart` / `markdown_rendering_test.dart` / `epub_paginator_test.dart` / `epub_image_rendering_test.dart` 具名用例 | TOOLING | 2026-11-08 PASS：列表元数据与偏移、链接目标与危险协议负例、点击只发宿主事件、可用图与占位图图注、分页宽度与图注高度 |
| P6 UI 机械检查 | `impeccable detect --json <三个渲染目标>`；收口后 `impeccable 4.8.1 detect --json <四个渲染目标 + 集成目标>` | TOOLING | 2026-11-08 两次 PASS：均返回 `[]`，无新增真实缺陷 |
| P7 UI 机械检查 | `impeccable detect --json lib/features/library/presentation/library_page.dart lib/features/reader/presentation/reader_page.dart lib/renderers/epub/epub_renderer_view.dart` | TOOLING | 2026-11-08 PASS：返回 `[]`，无新增真实缺陷 |
| P7 目录与排版收口 | `test/widget_test.dart` → `a folder book restores its saved file and own outline`；`markdown_rendering_test.dart` 代码块用例；`epub_paginator_test.dart` 列表间距用例 | TOOLING | 2026-11-08 PASS：顶层行无重复副标题、切文件保持 `文件` 页签、代码块占满正文列且无边框、列表间距小于段落间距 |
| P7 文件夹真实窗口 | `integration_test/reader_markdown_test.dart` → `a Markdown folder shows its file tree and current outline`，在 `kwin_wayland --virtual` 离屏会话执行 | RUNTIME | 2026-11-08 PASS：恢复 `sub/b.md`、大纲只含 `乙章`、展开 `sub` 看到嵌套文件 `b`、切到 `a` 后正文变为 `甲篇正文` 且仍停在 `文件`，再点 `大纲` 才显示 `甲章`；截图 03–06 留痕 |
| 共享渲染器离屏回归 | `reader_s0_test.dart`、`reader_epub_image_test.dart`、`reader_markdown_test.dart`，每个文件独立虚拟会话 | RUNTIME | 2026-11-08 UI 收口后复跑 PASS：11 + 1 + 3 项全过；未在用户桌面开窗 |
| 收口切片静态检查 | `dart format --output=none --set-exit-if-changed integration_test/reader_markdown_test.dart`、`flutter analyze integration_test/reader_markdown_test.dart`、`git diff --check` | TOOLING | 2026-11-08 PASS：格式 0 改动、分析 0 问题、diff 无空白错误；用户复核时又执行 `bash tool/check.sh` 全量门禁并保留上方 PASS |
| 安装版单文件 / 目录书阅读闭环 | 用户在 `tool/install_linux.sh` 安装版按「测试与验证」手测 | E2E | **BLOCKED**：待用户执行；不得用自动化或内存日志替代 |

`bash tool/check.sh` 的 P6 完整日志保存在 `/tmp/pagesage-check-p6-final-20261108.log`，P6 真实窗口日志保存在 `/tmp/pagesage-integration-p6-final.log`，收口切片的虚拟 Wayland 合成器日志保存在 `/tmp/pagesage-kwin-md-caption-final.log`（临时文件，不入库）。截图 `build/integration-captures/markdown-02-picture-captions.png` 由最终文件格式下的命名用例刷新，显示可用图与缺失图各一条安静图注。Impeccable 已更新到 CLI / skill 均为 4.8.1；官方安装器下载 skill bundle 遇到上游 `HTTP 504`，改用 `skill-v4.8.1` 发布 tag 的等价 skill 树同步用户级安装，并保留 `~/.config/magpie/library/skills/impeccable.bak-20261108-174712` 备份。

P6 实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS` + `RUNTIME_PASS`，安装版 `E2E` 仍 `BLOCKED`。图注的可见性由 widget 测试与真实窗口截图共同证明；截图只覆盖 Linux 集成窗口，不外推为安装版 E2E 证据。

P7 实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS` + `RUNTIME_PASS`（离屏虚拟 Wayland），安装版 `E2E` 仍 `BLOCKED`。文件夹截图只覆盖 Linux 集成窗口，不外推为安装版 E2E 证据。

## 依赖与风险

- 依赖：无。`package:markdown` 已在锁文件中。
- 风险一：Markdown 的块与 EPUB 的块语义不完全一致（列表嵌套、代码语言）。先把常见写法做对，边角写法保持「可读但不精美」。宽表格（十几列）在窄窗口里每列很窄，只能靠换行将就；不提供横向滚动，因为阅读器正文不该横向滚。
- 风险二：进度偏移依赖「文本是写出来的」这一规则，Markdown 解析器必须和 EPUB 解析器一样边解析边累计偏移，不能事后对齐。
- 风险三：文件夹模式会引入「一本书对应多个文件」的生命周期问题。当前策略是每次打开都重新遍历目录，文件被删就自然消失、被加就自然出现；代价是每次打开都要 stat 一遍目录（2000 文件量级可接受），以及不跟踪改名（改名后旧进度落不到新章节，按章节索引仍能落到相近位置）。
