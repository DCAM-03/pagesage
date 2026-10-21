# AI 检索层技术选型：DCI、向量 RAG 与结构感知词法检索

> 决策日期：2026-10-21
> 状态：已决策，待实施
> 上游需求：`docs/tasks/selected-text-ai-workflows.md`（TASK-16），`docs/02-feature-spec.md` §10
> 约束来源：`AGENTS.md`（AI 用户主动触发、上下文范围显式、本地优先）

## 1. 要解决的问题

用户提出两项超出当前实现的能力：

1. **全书关联提问**：对某段划词后，提问「这页/这段话和整本书的哪些知识有关」。
2. **同文件夹关联**：进一步对同一分类（文件夹）下的多本书提问。

当前 AI 面板只能发送选中文本（截断至约 120 字摘要），无法覆盖这两种范围。

## 2. 先厘清：哪些范围真的需要检索

四种上下文范围的性质不同，不能一概而论（现有实现也只提供这四种，「全书 / 文件夹」尚未加入枚举，见 §7.1）：

| 范围 | 是否需要检索 | 数据来源 | 说明 |
| --- | --- | --- | --- |
| 仅选中文本 | 否 | `RendererTextSelected.text` | 直接发送 |
| 当前页 | 否 | PDF `textOf()` / `renderer.cachedTextOf()` | 全页文本已可得 |
| 当前章节 | 否 | EPUB `EpubChapter.text` | 全章文本已可得 |
| 全书关联 | **是** | FTS + 结构 | 单书 60–104 万字，超出合理上下文 |
| 文件夹关联 | **是** | FTS + `categoryId` | 跨书，量级更大 |

**结论：RAG 只在后两档才有必要。** 前两档本应零成本可用——详见 §7 的断链缺陷。

## 3. 语料规模实测

本机书库（`dev.pagesage.pagesage`）已索引数据：

| 书名 | 分块数 | 字符数 |
| --- | ---: | ---: |
| 匿名样本 03 | 749 | 596,601 |
| 匿名样本 02 | 1,144 | 832,753 |
| 匿名样本 01 | 1,345 | 1,034,956 |
| 第1章 | 260 | 205,047 |
| 匿名数学扫描样本 | 1 | 17 |
| **合计** | **3,499** | — |

分块由 `SearchIndexer._splitTextWithOffsets(targetLength: 1200)` 产生，每块带 locator，已写入 FTS5。

**这个规模是选型的决定性因素**：三千量级的块，精确词法检索是毫秒级的，DCI 省掉建索引的收益在这里等于零。

## 4. DCI（Direct Corpus Interaction）评估

### 4.1 它是什么

DCI 让 LLM agent 直接用终端工具（`rg`、`find`、`sed`、文件读取）操作原始语料，而不是查询检索服务。不需要 embedding 模型或向量索引。

收益主张：在 BRIGHT/BEIR/BrowseComp-Plus 上超过稀疏、稠密、rerank 基线。

### 4.2 不建议采用，三个理由

**理由一：Android 上不可行。** DCI 的前提是「语料可通过终端工具访问」，参考实现给 agent 的是 bash 工具。PageSage 目标平台是 Android + Windows：Windows 可调用外部进程，Android 无 shell、无 `rg`。用 Dart 重新实现工具接口后已不是 DCI，而是「带搜索工具的 agent」，每次工具调用都是一次 API 往返。

**理由二：成本与延迟不可接受。** 第三方实测（326 文档 / 25 问题，混合格式）：

| 指标 | 向量检索 | DCI |
| --- | ---: | ---: |
| 准确率 | 22/25 (88%) | 22/25 (88%) |
| 延迟 | 3–10 秒 | 20–70 秒 |
| Token 总量 | 16,625 | 5,630,800（**338×**） |
| 25 次查询总成本 | $0.028 | $0.491（**17.5×**） |

论文自身数据（Lite 配置，100 题子集）：准确率 73% vs 45%，但每题工具调用 35.35 vs 17.55、成本 $0.1021 vs $0.0498——**准确率更高，代价是约两倍的调用与成本**。

论文另有一组同骨干模型结果（Sonnet 4.6）：80% vs 69%，总成本 $1,016 vs $1,440。说明在**大规模语料 + 强 agent** 下 DCI 可以赢。但正是这种「有时更贵、有时更便宜」的不可预测性，对用户自付 API Key 的消费者产品是硬伤——用户无法预期一次提问花多少钱。

**理由三：语料增大后显著退化。** 论文实测：

- 10 万 → 20 万文档：平均工具调用 38.5 → 86.9，准确率 **−13.6 个点**
- 40 万文档：准确率 **37.5%**，平均 122.4 次调用，20 个样本耗尽工具预算

DCI 的目标场景是 2 万–2000 万文档、离线建索引代价高的语料。PageSage 差两个数量级。

### 4.3 保留为后续可选项

如果将来做「跨整个书库的开放式研究式检索」（例如 500 本以上），DCI 的权衡可能反转。届时应在桌面端（Windows）先试点，不进入移动端主路径。

## 5. 向量 RAG 评估

**技术上可行，但代价与收益不成比例。**

Flutter 端侧向量检索需要两样东西：

- **存储/检索**：`sqlite3_vec`（封装 `sqlite-vec`），Android/Windows 已有社区封装，可用。
- **嵌入推理**：`sqlite-vec` 只做存储与检索，不做嵌入；需另配 ONNX/TFLite runtime 与打包模型（通常 100MB+）。

为 3,499 个块引入 100MB+ 模型体积与两个原生依赖，在「本地优先、Android + Windows 双端」的产品里不划算。中文效果仍取决于模型选择。

**结论：不采用。** 若将来语料规模或语义召回需求显著上升，可按以下条件重新评估：单书库超过 5 万块、或实测发现词法检索召回不足以支撑真实提问。

## 6. 选定方案：结构感知的词法检索

### 6.1 核心思路

书籍天然自带层级结构，且项目里**已有现成实现**：

- EPUB：`EpubTocItem` 树 + `EpubChapter.text`
- PDF：`PdfOutline` 章节树（含页码），由 `pdfOutlineEntries()` 解析

这与 PageIndex 的思路一致（用文档自身目录做检索），但关键区别是：**PageIndex 需要 LLM 生成树索引，我们的树本来就在文件里**，省掉了它最贵的一步。

### 6.2 流程

```
划词 / 提问
   │
   ├─ 范围：页 / 章 ────────────→ 直接取全文（零检索成本）
   │
   └─ 范围：全书 / 文件夹
          │
          ├─ 1. 查询扩展：把问题压成 3–5 个检索词
          │     默认纯词法抽取；可选一次 LLM 调用（用户可关）
          │
          ├─ 2. FTS5 bm25 检索
          │     SearchDao.search() 已支持 bookId / categoryId / tagIds
          │
          ├─ 3. 结构重排：同章加分、邻近章节加分、
          │     跨书按书聚合后各取前 2
          │
          ├─ 4. 邻块扩展（chunk ±1）
          │     1200 字切片会在句中截断，补相邻块保证语义完整
          │
          └─ 5. 组上下文 → 回显引用清单 → 发送
```

### 6.3 为什么复用现有检索层

`SearchDao.search()` 已经支持全部所需过滤：

- `bookId` — 全书
- `categoryId` — 文件夹（`Categories` 表即「文件夹」，支持 `parentId` 层级）
- `tagIds` / `format` — 可选收窄

`DriftSearchRepository` 已处理中文：`SearchNormalizer` + `searchLikeFallback`（CJK 时用 LIKE 回退）。

### 6.4 成本对比

按实际书库估算：

| 方案 | 每问题 token | 每问题 API 往返 |
| --- | ---: | ---: |
| 结构感知词法检索（K=5） | ~2,500 | 1（或 2，含查询扩展） |
| DCI（论文 Lite 配置） | ~225,000 | 35 |

相差约 **90 倍**，且检索方案是确定性的：同样的书、同样的问题，永远返回同样的引用。

### 6.5 中文检索的已知短板

`docs/plan-to-m5.md` 第 84 行已记录「中文 FTS 未换分词器」。现状是 `searchLikeFallback` 用 `LIKE` 回退；单书 1,345 块的 `LIKE` 扫描是毫秒级，**该档不需要动**。

若后续实测发现召回不足，低成本升级路径是 SQLite 内置 `trigram` 分词器（3.34+，`sqlite3_flutter_libs` 已含）。注意三角分词要求查询至少 3 字符，两字词（如「抽象」）仍需回退。该改动需重建 FTS 表并重新索引，属 Drift 迁移，**暂不实施**。

## 7. 前置缺陷：上下文断链（必须先修）

`ContextBuilder.build()` 有 `availableText` 参数，用于提供「前后段落 / 当前章节 / 当前页」所需正文，但**生产代码从未传入**：

```
$ grep -rn "availableText" lib/ test/
lib/features/ai/application/context_builder.dart:34   # 定义
lib/features/ai/application/context_builder.dart:37   # 使用
test/features/ai/context_builder_test.dart:23         # 仅测试
```

`ai_panel.dart:_applyContextRange` 调用时少了这个参数：

```dart
final built = const ContextBuilder().build(
  selectedText: widget.initialContext ?? _contextController.text,
  range: range,
  locator: widget.locator,
  // 缺少 availableText
);
```

**后果**：用户在面板选「当前章节」，拿到的文本与「仅选中文本」完全相同。范围切换是空操作。

同时，上游也只有约 120 字符——阅读位置事件的 `excerpt` 经 `compactLocatorExcerpt(maxChars: 120)` 产生，所以「当前页」连完整段落都取不到。

**这是第 1 步施工内容。** 不修它，后续所有「全书 / 文件夹」能力都建立在一个说谎的范围选择器上。

### 7.1 第 1 步完成情况（2026-10-21）

已接线，链路为：`ReaderPage` → `AiPanel(bookPath, isEpub)` → `_applyContextRange`
→ `AiContextSource.load()` → `ContextBuilder.build(availableText: …)`。

| 文件 | 作用 |
| --- | --- |
| `lib/features/ai/application/ai_context_range.dart` | 范围枚举独立成文件，避免加载器与构造器互相 import |
| `lib/features/ai/application/ai_context_source.dart` | 从磁盘读一页 PDF（`PdfTextExtractor.reflowPage`，走 isolate）或一章 EPUB |
| `lib/features/ai/application/context_builder.dart` | 新增 `_boundedChapter`，超长章节按选区居中截取，不再报错 |

行为约定（都有测试覆盖）：

- 读不到书文件 / 本页无文字（扫描页、封面）→ 明确提示并退回「仅选中文本」，
  绝不把选区冒充成整页。
- 读取期间范围下拉与发送按钮禁用，避免读到一半改范围。
- 读取结果晚到、翻页已经换了选区 → 丢弃旧结果，不覆盖新选区。

**刻意未加入 `AiContextRange.wholeBook`。** 若此时加入，`AiContextSource` 只能返回当前章节，
枚举会立刻复现本次要修的缺陷（标签承诺全书、实际发送一章）。全书/文件夹范围应在第 4 步
连同检索一起落地。

### 7.2 第 2 步完成情况：引用清单（2026-10-21）

发送内容从「一个可编辑文本框」改为**引用清单**（`AiContextReference`）：

- 每段引用一行，显示来源（`第 3 章` / `第 12 页`）、字数，以及跳回原文的按钮。
- 行可**移除**；只剩最后一段时不可移除（避免把上下文清空）。
- 「编辑文本」展开后逐行可改，改动立即计入总字数与发送内容。
- 换范围时保留选区行、替换上一范围带来的行——选区是问题的对象，不能丢。
- 发送前的隐私确认框列出每一段引用的名称，而不是只报一个范围名。

多段发送时每段带 `【来源】` 标题（单段保持裸文本，不额外花 token）。实测标题开销
约 18 字/段，相对 12000 字预算可忽略。这个格式同时也是第 4 步引用回显的载体：
检索结果以同样结构进入清单，`bookTitle` 非空时标题显示 `书名 · 章节`。

**未做**：跨书来源的跳转。`AiContextReference.locator` 已能携带任意书的位置，
但 `_jumpTo` 只在当前书内跳转；第 5 步需要「打开另一本书并定位」的路由。

### 7.3 第 3 步完成情况：多轮对话（2026-10-21）

追问从「对同一段文本再问一次」变成真正的多轮：`AiRequest.history` 携带本会话
此前各轮，`ai_conversations.thread_id` 把它们归到一组。

| 层面 | 做法 |
| --- | --- |
| 传输 | `_messages()` 只把上下文挂在开篇那一轮；后续轮只发自己的问题 |
| 存储 | `schemaVersion` 3 → 4，`migrator.addColumn(aiConversations.threadId)` |
| 会话 | 面板持有 `_threadId` / `_history`，首轮生成 `thread-<微秒>`，后续轮复用 |

三条关键约定：

1. **上下文只出现一次。** 书籍正文是请求里最贵的部分；每轮重发会让请求成本随
   轮数线性增长。测试用本地 `HttpServer` 抓真实请求体，断言正文块恰好出现一次、
   角色序列为 `user / assistant / user …`，而不是复刻一份 `_messages` 逻辑自证。
2. **上下文一变，会话就断。** 换选区、换范围、删引用都会调用 `_startNewThread()`。
   继续旧会话意味着模型拿着它没见过的正文作答——正是第 1 步修掉的那类问题。
3. **迁移不猜历史。** 升级前已有的会话 `thread_id` 置空，历史视图把它们当单轮展示。
   事后按时间或文本相近度归组只是猜测，猜错比不归组更糟。迁移测试从真实 v4 库
   `DROP COLUMN` + 回写 `user_version = 3` 再打开，确保走的是生产升级路径且不清数据。

**未做**：历史视图仍按单条会话平铺，尚未按 `thread_id` 折叠成组。数据已经就位，
折叠是纯展示层改动；等第 4 步的多书引用进来后一起做，避免两次重排列表。


## 8. 隐私边界（不可妥协）

`AGENTS.md`：

> AI is user-triggered only. Never upload a whole book automatically, and always **make the AI context range explicit**.

「自动检索 → 挑块 → 发送」若做成后台黑箱，直接违背该约束。因此：

- 检索可以自动，但结果**必须回显成可检查、可增删的引用清单**，每条能跳回原文。
- 跨书引用时，发送前必须明确列出「来自 N 本书的 M 处引用」，不能只用「当前文件夹」四个字概括。
- 引用清单同时解决答案出处不可信的问题。

## 9. 实施顺序

| 步骤 | 内容 | 依赖 | 表结构改动 |
| --- | --- | --- | --- |
| 1 | 修上下文断链：`availableText` 接入，页/章取真实全文 | 无 | 无 |
| 2 | 引用区 UI：发送内容做成可检查清单 | 1 | 无 |
| 3 | 多轮对话：会话归组 | 2 | `threadId` 迁移（已完成，v3 → v4） |
| 4 | 全书关联：FTS + 结构重排，K=5 | 2 | 无 |
| 5 | 文件夹关联：`categoryId` + 跨书跳转 | 4 | 无 |

**第 5 步的独立难点**：检索结果来自别的书，点击引用需跨书跳转。现有 `_jumpTo` 只在当前书内跳转，路由无加载其他书的路径。需新增「打开另一本书并定位」，`ReadingLocator` 已可作为 `extra` 传入。此项应与 UI 改造分开设计。

## 10. 参考来源

- [Beyond Semantic Similarity: Rethinking Retrieval for Agentic Search via Direct Corpus Interaction](https://arxiv.org/abs/2605.05242)（DCI 原始论文）
- [alphaXiv 详细数据页](https://www.alphaxiv.org/abs/2605.05242)（成本、工具调用、扩展性数字）
- [DCI-Agent 参考实现](https://github.com/vvjohn/DCI)
- [Agentic RAG vs Vectorless Retrieval 实测对比](https://www.dataworkz.com/blog/agentic-rag-vs-vectorless-retrieval-benchmark/)（Dataworkz，成本/延迟对比数据）
- [PageIndex：基于文档结构的向量less 检索](https://github.com/VectifyAI/PageIndex) · [树检索文档](https://docs.pageindex.ai/tutorials/tree-search)
- [sqlite-vec 移动端支持 issue #71](https://github.com/asg017/sqlite-vec/issues/71) · [sqlite3_vec (pub.dev)](https://pub.dev/packages/sqlite3_vec)
- [Evidence Blindness：有限交互预算下的失效模式](https://arxiv.org/abs/2608.24764)
