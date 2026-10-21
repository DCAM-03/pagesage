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
| US-001 | 导入 EPUB/PDF，集中管理 | [x] | 文件选择、拖拽、hash 去重、复制到书库 |
| US-002 | 打开书籍并自动恢复进度 | [x] | EPUB/PDF 均有进度表；会话保存已加固 |
| US-003 | 调整字号、背景和样式 | [x] | 阅读设置持久化；多主题 |
| US-004 | 按目录跳转 | [x] | EPUB TOC + PDF 大纲/页码；软跳转已接 |
| US-005 | 添加书签 | [x] | 添加/删除/跳转/备注入口存在 |
| US-006 | 书籍和笔记全局搜索 | [x] | FTS 索引 + 搜索页 + 跳转 |
| US-007 | 划线和写笔记 | [x] | 标注渲染、笔记页、阅读器 Notebook |
| US-008 | 划词问 AI | [x] | 用户主动触发；四种上下文范围均已取真实页/章全文（`AiContextSource`，见 `docs/12-ai-retrieval-strategy.md` §7.1） |
| US-009 | AI 回答保存为笔记 | [x] | AI 面板可保存；可被搜索索引 |
| US-010 | 导出笔记 | [x] | 设置页：Markdown / Notebook / 标注 JSON / 书签 CSV / AI Markdown |
| US-011 | 扫描文件夹批量导入 | [x] | 书库「扫描文件夹」+ 递归发现 EPUB/PDF |
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
