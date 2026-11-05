# PageSage 实现对照清单

版本：0.2  
日期：2026-07-16  
对照文档：`01-product-requirements.md`、`02-feature-spec.md`、`07-roadmap.md`、`plan-to-m5.md`、`AGENTS.md`  
状态说明：

| 标记 | 含义 |
| --- | --- |
| [x] | 已实现，主路径可用 |
| [~] | 部分实现 / 有缺口 / 体验未达验收 |
| [ ] | 未实现 |
| [-] | 文档明确延后或不做（非当前范围） |

---

## 1. 用户故事 US-001～012

| 编号 | 用户故事 | 状态 | 说明 |
| --- | --- | --- | --- |
| US-001 | 导入 EPUB/PDF/Markdown，集中管理 | [x] | 文件选择、拖拽、hash 去重、复制到书库 |
| US-002 | 打开书籍并自动恢复进度 | [x] | EPUB/PDF 均有进度表；会话保存已加固 |
| US-003 | 调整字号、背景和样式 | [x] | 阅读设置持久化；多主题 |
| US-004 | 按目录跳转 | [x] | EPUB TOC + PDF 大纲/页码；软跳转已接 |
| US-005 | 添加书签 | [x] | 添加/删除/跳转/备注入口存在 |
| US-006 | 书籍和笔记全局搜索 | [x] | FTS 索引 + 搜索页 + 跳转 |
| US-007 | 划线和写笔记 | [x] | 标注渲染、笔记页、阅读器 Notebook |
| US-008 | 划词问 AI | [x] | 用户主动触发；四种上下文范围均已取真实页/章全文（`AiContextSource`，见 `docs/12-ai-retrieval-strategy.md` §7.1） |
| US-009 | AI 回答保存为笔记 | [x] | AI 面板可保存；可被搜索索引 |
| US-010 | 导出笔记 | [x] | 设置页：Markdown / Notebook / 标注 JSON / 书签 CSV / AI Markdown |
| US-011 | 扫描文件夹批量导入 | [x] | 书库「扫描文件夹」+ 递归发现 EPUB/PDF/Markdown |
| US-012 | 备份数据库 | [x] | 备份 zip + 恢复 + 回滚副本 |

**用户故事合计：** 12 完成

---

## 2. 里程碑对照

### M0–M3

主路径 **[x]**。可选延后：本地模型运行时 `[-]`；完整 Markdown 引擎 `[~]`；中文 FTS 增强 `[~]`。

### M4 v1.0（稳定发布）

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 数据库备份 / 恢复 | [x] | UI + 服务 + 单测；恢复后强制提示重启 |
| 快捷键（桌面） | [x] | `docs/keyboard-shortcuts.md` |
| 隐私说明 / 开源许可 | [x] | 设置 → 关于 |
| 本地质量门禁脚本 | [x] | `tool/check.ps1` / `tool/check.sh` |
| 发布构建脚本 | [x] | `tool/build_release.ps1` |
| 性能与大库/大 PDF 验收 | [~] | 手测：`docs/m4-release-checklist.md` |
| 辅助功能完整验收 | [~] | tooltip/语义有；清单待人工勾 |
| Windows 商店签名/安装器 | [~] | release 可构建；签名人工 |
| Android 签名发布 | [~] | 同上 |

### M5 UI/UX 现代化

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 设计方案 / token 冻结 | [x] | `docs/09-design-system.md` 与 `app_tokens.dart` 对齐 |
| Flutter token + 公共组件 | [x] | PageHeader/CommandBar/EmptyState/SidePanel 等 |
| App Shell 双标题收敛 | [x] | CommandBar 品牌弱标题 + PageHeader 页面标题 |
| 书库 / 搜索 / 笔记空状态插图 | [x] | `assets/images/empty-states/*.png` |
| 阅读器 / 搜索 / 笔记主体改造 | [x] | 前期已落地 |
| 响应式 + 主题自动化 | [x] | widget/contrast 测试 |
| 双端真实样本手测闭环 | [~] | 需人工按 checklist 勾选 |

### 明确不做

MOBI/AZW、云同步、账号、DRM 绕过、在线书店、iOS/macOS/Linux 首发 → `[-]`

扫描版 PDF OCR：
- Phase 0/1 已落地（无文本层文案、`no_text` 索引态、当前页本地 OCR、复制/问 AI）。见 `docs/tasks/pdf-ocr-optional.md`（TASK-26）。
- Phase 2 部分推进：`ocr_pages` 本地落库 + 翻页自动恢复叠加已落地；选页任务队列 / OCR 进 FTS / ONNX 仍后置，不阻塞 v1.0。

性能 / 稳定性（2026-07-17）：
- PDF 全文提取改走 `Isolate.run`，避免索引时主 isolate 卡死。
- 导入任务索引失败标记为 `failed` 并保留 `bookId`；任务中心重试只重建索引，不再 `allowDuplicate` 再导入一本。
- `createImportedBook` 按 hash 兜底去重；取消导入时清理已插入的孤儿书籍记录。

v1.0 体验冻结落地（`docs/v1-experience-freeze.md`，2026-07-17）：
- **F-01** 单 chrome：PDF 阅读器只有 Flutter 工具栏/状态栏，操作走 Flutter。
- **F-03/S-B** 扫描/OCR 页标注 SnackBar 与状态条标明「近似定位」。
- **F-06** capability 区分 `nativeTextLayer` / `ocrTextLayer`；OCR 入口按 native 控制。
- F-02 文本 PDF 精确标注仍需手测勾选；扫描印刷级贴字仍延后。

PDF 渲染迁移（`docs/10-pdf-renderer-migration.md`，2026-10-21）：
- WebView/PDF.js 渲染器已删除，PDF 由 `pdf_graphics` 在 Flutter Canvas 上直接绘制。
- S0–S7 完成：几何/缩放、滚动与分页、选区、搜索/大纲/链接、导出与 F-02、主题与失败分级、平台切换与删除。
- `flutter_inappwebview` 与 `assets/renderer/pdf/` 已移出依赖与包体。
- **划词修复（2026-10-21，见 `11-pdf-canvas-implementation-plan.md` §25）**：`positionNear` 按 run 包围盒评分，在排版复杂的书上 3–27% 的点落到非指针所在行（最远 729pt）。改为 em 空间基线带判定 + 同行 run 合并 + 行内水平距离决胜；真实书网格复测错行 0.0%。顺带修掉前页/正文页尺寸不同导致的逐行偏移、连点失效、跨页拖选不滚动。
- **待办**：S8 收口——Windows/Android 手工回归、旋转页标注、夜间标注配色、真机帧时间与峰值内存。

图片批注（`docs/13-image-annotations.md` / `docs/tasks/image-annotations.md`，2026-10-22）：
- B1 完成：PDF 拖框模式、视图内吸附、`annotations` 表 v4→v5（`target` / `image_anchor`）、四角括号描边、Notebook 图片条目与琥珀色跳回闪烁、`exportPageRegion` 保存 PNG。
- B2 完成：标注时裁图进 `<cache>/images/<bookId>/`（文件名按图的同一性，不按矩形）、设置页「导出图片批注」（Markdown + 同级图片目录 + 相对路径）、「清理图片缓存」、删书/删批注清缓存、标注 JSON 补上 `target` 与 `imageAnchor`。裁图不挡读者的路：批注先写库，裁图在之后自己跑。
- B3 完成（2026-10-22）：EPUB 真正显示书中的插图。加载器改为解析 XHTML 的结构（`epub_chapter_parser.dart`），章节文本仍是「只有字」的一条字符串，图片作为并列的块插在文字之间且不占字符，因此搜索、进度、跳转、划词偏移全部不受影响。图片字节从 archive 读，`data:` URI 支持、远程图片不加载；单图字节与像素预算硬限制，尺寸在解码前从头部读。图注是正文的一部分（参与排版与搜索）。失败降级为带原因和 `alt` 的占位块，不留空白。已在真实 Linux 窗口里验证图片被画出（`integration_test/reader_epub_image_test.dart`）；同时修好样本本身：`image.epub` 原先内嵌的插图是一张 144 字节的坏图，任何解码器都读不出来，样本改由生成器现场产出可解码的真图。详见 `docs/tasks/epub-images.md`。
- **待办**：B4、B5；以及「重启后批注仍在原位」的真实应用手动确认。

Markdown 阅读（`docs/tasks/markdown-reading.md` / TASK-31，2026-11-05）：
- P1 完成：单个 `.md` / `.markdown` 文件即一本书。解析成与 EPUB 相同的文档模型（章节 → 块 → 字符偏移），因此分页、连续滚动、目录、进度、全文搜索、图片渲染直接复用，没有第二个阅读器。
- 章节按一级标题切分，二级标题进目录子项；列表、引用、围栏代码、图片都是有结构的块。（行内强调当时只保留文字，P5 已补上样式。）
- 图片只读本地（相对路径 / `data:`），远程图片不加载并给出原因；front matter 只用来取标题，不进正文与索引。
- `books.format` 写入 `md`，无 schema 变更；`ReadingLocator` 新增 `markdown` 类型，字段复用 EPUB 那组。
- 验证：解析器/格式识别/widget 测试通过；真实 Linux 窗口集成测试打开 `.codex-run/samples/markdown-note.md`，排版见 `build/integration-captures/markdown-01-prose.png`（该图早于表头横线的调整）。
- P3 完成（2026-11-05）：表格画成真正的表格。新增 `EpubTableBlock`（行列 + 表头），渲染层用 `Table` 等宽列、横线分隔、表头加粗；分页按行切分，跨页时重复表头。解析前修正分隔行/表头列数不一致的表格（`package:markdown` 原本会整张丢弃），围栏代码块不受影响。单元格文字仍在章节文本里，搜索与进度不受影响。
- P5 完成（2026-11-05）：行内样式与排版层级，阅读观感向 Typora 靠拢（仅阅读）。共享块模型新增 `EpubInlineRun`（粗体/斜体/行内代码/删除线/链接，章节偏移，文字本身不变）与 `headingLevel`、`EpubDividerBlock`；Markdown 与 EPUB 两个解析器都填，渲染层在样式、批注、搜索命中的边界切开 span 叠加合成，标题按 1–6 级缩放，`---` / `<hr>` 画成细线。列表悬挂缩进、链接点击、图片 alt 图注**未做**（记录在任务文档里）。
- P4 完成（2026-11-05）：切换章节性能。连续模式改为「一章多行（每行 8 块）」，不再在章节进入视野时一次排版整章（实测单帧 160–250 ms → 25–60 ms）；分页模式缓存已测章节并在页面停稳后预排下一章；章节定位改按「章节首行」映射，不再假设行号等于章号。
- P2 完成：**一个 Markdown 文件夹即一本书**，原地读取、不复制（`AGENTS.md` 里唯一例外），`fileHash` 为目录路径指纹；每篇按单文件规则成章、`href` 记相对路径，隐藏目录与 `node_modules` 跳过，超过 2000 文件 / 64 MB 明确报错，读不了的文件在末尾「无法读取的文件」一章里列出。同一个加载器按路径类型分派，阅读器/搜索/AI/目录无需分支；删除书不会删目录（`Book.isFolderBook`）。入口是书库「文件夹」菜单的「把文件夹作为一本书」。**性能修正**：图片只记路径（渲染时按页面宽度解码），目录解析移入 `Isolate.run` 并按目录指纹缓存结果——实测 500 篇 + 500 张 1 MB 图片首次 2.2 s / RSS 243 MB（此前把全部图片字节读进文档，1 GB 峰值被系统杀掉），二次打开 55 ms。

AI 检索层（`docs/12-ai-retrieval-strategy.md`，2026-10-21）：
- **选型已定**：全书 / 文件夹关联采用「结构感知的词法检索」（复用 FTS5 + EPUB 目录树 / PDF 大纲），**不采用 DCI，不引入向量 RAG**。
- 依据：DCI 在 Android 无 shell 不可行；实测同准确率下 token 高 338×、成本高 17.5×、延迟 4–20×；论文自述语料从 10 万增至 40 万文档时准确率跌至 37.5%。向量 RAG 需 100MB+ 嵌入模型与两个原生依赖，对 3,499 块的语料规模不划算。
- **发现断链缺陷**：AI 面板「前后段落 / 当前章节 / 当前页」三项范围从未生效——`ContextBuilder.build()` 的 `availableText` 生产代码从未传入。
- **第 1 步已完成**：`AiPanel(bookPath, isEpub)` → `AiContextSource`（磁盘读一页 PDF / 一章 EPUB）→ `availableText`；读不到或本页无文字时明确提示并退回「仅选中文本」。US-008 恢复 `[x]`。
- **第 2 步已完成**：发送内容改为引用清单（`ai_context_reference.dart`）：每段可看来源与字数、可跳回原文、可移除、可逐段编辑；多段带 `【来源】` 标题，隐私确认框逐段列出。
- **第 3 步已完成**：多轮对话。`AiRequest.history` 携带本会话此前各轮，上下文只挂在开篇一轮；`ai_conversations.thread_id` 归组，Drift v3 → v4 新增该列（旧会话置空、不猜历史）。换选区/换范围/删引用都会断开会话。
- **第 4 步已完成**：全书关联。`ContextRetriever` 直接对 `SearchChunks` 正文做 BM25（FTS5 的 `unicode61` 对中文基本失效，实测「数据」21 命中 vs 489 实含），中文按二元组切词；`_looksLikeContents` 过滤目录页；引用从命中点前 180 字截取。真实库单本检索 100–190ms。
- **第 5 步已完成**：文件夹关联。同 `categoryId` 下的书一起检索，每本最多 2 段；跨书引用行显示 `书名 · 页码`，点击走 `/book/:bookId/reader` 并在目标书定位。书没有文件夹时返回空结果，不扩大到全库。
- 实施顺序：① 修断链 → ② 引用区 UI → ③ 多轮对话 → ④ 全书关联 → ⑤ 文件夹关联（全部完成）。

---

## 3. 收尾建议（仅人工）

1. 按 `docs/v1-experience-freeze.md` 冻结 v1.0 体验范围（单 chrome、标注契约、扫描 PDF 降级策略）。  
2. 按 `docs/m4-release-checklist.md` 做 Windows 备份恢复与阅读闭环手测。  
3. 有 Android 设备时跑一遍导入→阅读。  
4. 可选：商店签名、完整 Markdown 包、中文分词。

---

## 4. 一句话结论

| 范围 | 结论 |
| --- | --- |
| 产品书功能主路径 | **已基本完成** |
| 工程侧 M4/M5 | **代码与文档就绪** |
| 发布/双端手测 | **待人工勾选** |
