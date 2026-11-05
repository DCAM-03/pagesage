# TASK-31：Markdown 阅读

状态：**P1、P2 完成**（2026-11-05），待用户在安装版里手测验收。

## 目标

让 PageSage 能像读一本 EPUB 那样读 Markdown 文件：导入书库、排版阅读、目录跳转、保存进度、全文搜索。第二阶段支持把**一个目录**当作一本书来读（笔记库、文档仓库）。

## 来源与边界

- 来源：用户 2026-11-05 明确要求「加个阅读 markdown 的功能」。
- **范围变更**：`AGENTS.md` 与 `docs/00`–`07` 原本把阅读格式限定为 EPUB / PDF。Markdown 不在原路线内，本次是产品路线的有意扩展，已同步更新 `AGENTS.md` 的格式约束与 `docs/00-overview.md`。除格式之外的产品约束（本地优先、AI 由用户触发、不做云同步等）不变。
- P1 只做**单个 `.md` / `.markdown` 文件当一本书**。
- P2 做**目录当一本书**（按路径排序成章节，目录内的相对图片正常工作）。已实现：**原地读取，不复制**（用户 2026-11-05 决定）。
- 不做：Mermaid / 图表渲染、数学公式（LaTeX）、脚注编号排版、内嵌 HTML 渲染、外链自动打开、划词标注与 AI 上下文（这些和 EPUB 一样留到后续统一做）。

## 设计取舍

- **复用阅读引擎，不另写一个阅读器。** Markdown 被解析成与 EPUB 相同的文档模型（章节 → 块 → 字符偏移），因此分页、连续滚动、目录、进度、搜索高亮、图片渲染全部直接复用。另写一个 Markdown 阅读器意味着这套行为要重做一遍，且两边会慢慢长歪。
- **行内强调暂不渲染。** `**粗体**`、`*斜体*`、行内代码只保留文字、去掉标记。这不是 Markdown 特有的取舍：EPUB 路径同样没有行内样式，正文一律是纯文本块。等行内样式统一做的时候，两种格式一起受益。
- **标题、代码块、引用、列表、表格、图片是有结构的。** 这些是块级语义，正好落在现有块模型上：标题走 heading 样式，围栏代码走 code 样式（等宽 + 边框），引用走 quote 样式，列表项带项目符号，表格按等宽块排版（保住对齐），图片走图片块。
- **章节按一级标题切分。** 有 `#` 就一章一节；没有一级标题时整篇是一章，标题取 front matter `title:` 或文件名。目录由一级、二级标题生成。
- **图片只读本地。** 相对路径按文件所在目录解析，支持 `data:` URI；`http(s)` 图片不加载，理由同 EPUB：本地优先，一本书指向网络不该让读者等。
- **front matter 只用来取标题。** `---` 之间的 YAML 不进入正文，也不参与搜索；现阶段只认 `title:`，其余字段以后再说。
- **不引入新依赖。** `package:markdown` 已经作为 `flutter_markdown` 的传递依赖在锁文件里（AI 面板用它渲染回答），解析器直接用它，不新增第三方包。

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
- [x] 文件夹新增/删除文件后的重新扫描策略：不缓存目录快照，每次打开/索引都重新遍历，编辑器里加的文件下次打开就在；删除的章节自然消失。

### P2 实现说明

- **原地读取，不复制。** 目录书的 `libraryFilePath` 就是用户选的那个目录；`fileHash` 是 `dir:` + 规范化绝对路径的 sha256，同一个目录重复导入是重复书，目录搬家就是另一本书。这是 `AGENTS.md`「导入必须复制进书库目录」的唯一例外，已写进 `AGENTS.md`。
- **删除书不会删目录。** 书库「删除应用副本与数据」对目录书跳过 `libraryFilePath`，`Book.isFolderBook` 负责判断（Markdown 且路径不以 `.md`/`.markdown` 结尾）。
- **一个加载器认两种形态。** `MarkdownDocumentLoader.load` 先 `FileSystemEntity.type`，目录就交给 `MarkdownFolderLoader`，因此阅读器、搜索、AI 上下文、目录面板都不用分支。
- **目录里的每篇是一章。** 每个文件按单文件规则解析（有 `#` 按一级标题分章，没有就整篇一章，标题取文件名），章节的 `href` 记相对路径，进度/搜索跳转能回到具体文件。
- **跳过 `node_modules` 和所有隐藏目录**（`.git`、`.obsidian`、`.trash`），按相对路径排序。
- **上限**：2000 个文件、合计 64 MB，超过时明确报错而不是把机器拖死。
- **读不了的文件不静默消失**：末尾追加一章「无法读取的文件」列出相对路径。
- **入口**：书库头部「文件夹」按钮弹出两项——「扫描文件夹（每个文件一本书）」与「把文件夹作为一本书」；空书库页同样。拖拽只接文件，不猜文件夹意图。

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
- [x] 标题、列表、引用、代码块、表格、图片都按预期呈现，不是带标记的原文。
- [x] 目录列出各级标题，点击能跳到对应位置。
- [x] 关闭再打开，回到上次阅读位置。
- [x] 全文搜索能命中 Markdown 正文，结果可跳转。
- [x] 远程图片不加载，缺失图片有可读占位。

## 测试与验证

- 单元测试：解析器（标题层级、列表、引用、代码、表格、图片、front matter、空文件）。
- 单元测试：格式识别与元数据提取。
- Widget 测试：Markdown 书在阅读器里渲染出块。
- `dart format .`、`flutter analyze`、`flutter test`。
- 集成测试（真实 Linux 窗口）：`.codex-run/samples/markdown-note.md` 打开后正文、列表、引用、代码、表格都排版呈现，capture 见 `build/integration-captures/markdown-01-prose.png`。
- 真实应用：待用户在 `tool/install_linux.sh` 更新后的安装版里手测导入、阅读、进度、搜索，以及把一个真实笔记文件夹作为一本书打开。

## 依赖与风险

- 依赖：无。`package:markdown` 已在锁文件中。
- 风险一：Markdown 的块与 EPUB 的块语义不完全一致（列表嵌套、表格对齐、代码语言）。先把常见写法做对，边角写法保持「可读但不精美」。
- 风险二：进度偏移依赖「文本是写出来的」这一规则，Markdown 解析器必须和 EPUB 解析器一样边解析边累计偏移，不能事后对齐。
- 风险三：文件夹模式会引入「一本书对应多个文件」的生命周期问题。当前策略是每次打开都重新遍历目录，文件被删就自然消失、被加就自然出现；代价是每次打开都要 stat 一遍目录（2000 文件量级可接受），以及不跟踪改名（改名后旧进度落不到新章节，按章节索引仍能落到相近位置）。
