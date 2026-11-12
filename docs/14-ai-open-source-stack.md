# AI 能力升级：开源方案调研与落地路线

> 调研日期：2026-11-08
> 状态：调研完成；父子分块第一版已实现并完成真实 33 题离线 A/B，其余方案待选型
> 上游约束：`docs/12-ai-retrieval-strategy.md`、`docs/tasks/selected-text-ai-workflows.md`、`AGENTS.md`
> 算法设计入口：[结构感知的父子分块与上下文扩展](15-parent-child-chunking.md)（2026-11-08；第一版已实现，33 题离线结果见 §9.1）
> 研究补充：[近期分块论文与开源实现复核](16-chunking-research-review-2026-11-08.md)（2026-11-08；补强设计与证据口径）

## 1. 结论

当前 AI 的“简单感”主要不是模型不够强，而是四段链路都还停在最小可用版本：

1. **Provider 只有一条 `chat/completions` 通道。** 没有 Provider 预设、能力声明、结构化输出、工具调用；本地 Ollama / LM Studio 也必须先填一个 API Key 才能通过面板校验。
2. **检索只有中文二元组 + BM25。** 对原词、术语、代码片段有效，但对改写、同义表达、跨章节归纳和对比型问题召回不足。
3. **所有问题都走同一套 top-5 片段。** “解释这句”“比较两章”“总结全书”“找出作者观点”需要的检索和生成策略并不相同。
4. **没有引用校验和分层总结。** 模型可以写出没有来源支撑的句子；全书总结也只能从少量片段拼出来。

建议不要把 LangChain、LlamaIndex、Dify 或一整套 Python RAG 服务塞进 Flutter。PageSage 已经有 Drift、分块、locator 和引用清单，最合适的路线是：

> **保留自己的数据层和引用模型，补一条小型 Dart 检索管线；本地推理只作为可选能力，按设备内存分档。**

推荐优先级：

| 优先级 | 做什么 | 为什么 |
| --- | --- | --- |
| P0 | Provider 预设与能力声明、问题意图路由、查询分解、引用约束、章节级总结缓存 | 不加原生依赖，直接改善回答质量和“聪明感” |
| P1 | 量化中文嵌入模型 + Drift 向量 BLOB + isolate 余弦检索 | 补语义召回，3,500 块规模不需要向量数据库 |
| P2 | 桌面 Ollama / llama.cpp server，随后 Android 本地 GGUF | 离线、隐私、无 API Key；但模型体积和内存必须显式管理 |
| P3 | 扫描 PDF OCR、复杂版面/表格理解 | 价值高，但应独立于问答质量升级，避免范围失控 |

## 2. 当前实现与真实短板

### 2.1 调用链

| 层 | 现状 | 影响 |
| --- | --- | --- |
| `OpenAiCompatibleProvider` | 只发 `${baseUrl}/chat/completions`，SSE 流式、取消、错误映射 | 兼容面其实很广，但缺少能力协商与本地无 Key 模式 |
| `AiChatService` | 发送 `contextText + prompt + history`，流式累计后存库 | 没有结构化输出、引用校验、计划/执行分离 |
| `ContextRetriever` | 直接扫描分块，中文二元组 + BM25 + 邻块扩展 + 目录页过滤 | 无语义召回；对比型问题容易只命中其中一侧 |
| `AiPanel` | 解释、总结、提炼、翻译四个快捷动作；引用清单可编辑 | 交互入口偏少，复杂问题没有“深度检索/总结全书”的明确路径 |
| `AiSettings` | 单一 provider 字符串、baseUrl、model、API Key | 不能表达“本地服务不需要 Key”“是否支持 JSON/工具/嵌入” |

### 2.2 语料规模仍然是选型关键

当前真实库约 4 本书、3,494 个分块、180 万字，单本检索约 100–190ms。这个规模下：

- 不需要 `sqlite-vec`、LanceDB、Milvus 之类的向量数据库；
- 不需要 ANN 索引或 GPU；
- 3,500 × 512 维 `float32` 只有约 **7.2MB**，3,500 × 1024 维约 **14.3MB**；
- 在 Dart isolate 里做一次全量余弦扫描，成本远低于维护一个原生扩展。

这条结论会随着书库增长而变化，但当前阶段应优先把“检索质量”而不是“索引规模”做好。

## 3. 候选方案对比

### 3.1 本地生成 / Provider

| 方案 | 许可证 | 平台 | 适合 PageSage 的部分 | 主要代价 | 结论 |
| --- | --- | --- | --- | --- | --- |
| OpenAI-compatible API | 无新增依赖 | Android / Windows | OpenAI、DeepSeek、Qwen、OpenRouter、Ollama、LM Studio、llama.cpp server、vLLM 都能接 | 需要 Provider 预设与能力声明 | **保留为主通道** |
| Ollama | MIT | Windows / Linux / macOS；Android 不作为应用内依赖 | 桌面端零集成成本，模型管理成熟 | 需要用户另装服务；不能覆盖 Android 离线 | **桌面可选，先做** |
| llama.cpp | MIT | Android / Windows 可编译 | GGUF、量化、CPU/GPU、工具调用、结构化输出 | 需要 Flutter 绑定和原生构建 | **本地推理底座** |
| `fllama_cpp` | MIT | Android / Windows / Linux / macOS / iOS / Web | Flutter 原生绑定，API 简单，支持工具与 JSON schema | 模型管理、下载、内存策略要自己做 | **低层备选** |
| `flutter_edge_ai` + `flutter_edge_ai_llama` | MIT | Android / Windows / Linux / macOS / iOS / Web | 模型安装/恢复、llama.cpp、ONNX、嵌入、RAG、函数调用都有现成抽象 | 包族较新，版本耦合；RAG/SQLite 子包要求 Flutter 3.47 | **首选做一次 spike** |
| MLC LLM | Apache-2.0 | Android / Windows / macOS / Linux | 编译式高性能推理，OpenCL/Metal/Vulkan | 需要模型编译与平台工程，Flutter 胶水成本高 | **不建议进 v1** |
| ONNX Runtime GenAI | MIT | Android / Windows / Linux / macOS | ORT 原生生成、约束解码、Android 支持 | 没有现成 Flutter 插件；模型目录与 EP 配置复杂 | **只在确定走 ONNX 生成时评估** |

### 3.2 中文嵌入模型

| 模型 | 许可证 | 参数量 | 维度 / 上下文 | 体积参考 | 评价 |
| --- | --- | ---: | --- | --- | --- |
| `BAAI/bge-small-zh-v1.5` | MIT | 24M | 512 / 512 tokens | ONNX 量化约 24–95MB | **移动端首选**：小、中文够用、接入简单 |
| `BAAI/bge-base-zh-v1.5` | MIT | 102M | 768 / 512 tokens | 约 400MB 仓库 | 桌面可选，移动端收益/成本一般 |
| `BAAI/bge-m3` | MIT | 568M | 1024 / 8192 tokens | 仓库约 4.6GB；ONNX 需另导 | 多语言、长文本强，但移动端过重 |
| `Qwen/Qwen3-Embedding-0.6B` | Apache-2.0 | 596M | 1024，可 MRL 降维 / 32K | Q8_0 GGUF 约 639MB | 质量强，桌面可选；移动端默认不选 |
| `intfloat/multilingual-e5-small` | MIT | 118M | 384 / 512 tokens | 约 118MB 权重 | 多语言可用，中文检索不如 BGE 小模型 |

`bge-small-zh-v1.5` 的 C-MTEB 平均分约 57.82，检索约 61.77；它不是最强，但在 24M 参数级别里性价比很高。Qwen3-Embedding-0.6B 的 C-MTEB 平均分约 66.33，代价是约 25 倍参数量。对 PageSage，先用小模型验证混合检索是否真的改善体验，再决定是否提供“高质量嵌入”桌面选项。

### 3.3 重排模型

| 模型 | 许可证 | 参数量 | 适用性 |
| --- | --- | ---: | --- |
| `BAAI/bge-reranker-base` | MIT | 278M | 中英重排，桌面可选；移动端推理成本偏高 |
| `BAAI/bge-reranker-v2-m3` | Apache-2.0 | 568M | 多语言强，但移动端不建议默认开启 |
| `Qwen/Qwen3-Reranker-0.6B` | Apache-2.0 | 596M | 指令化重排，桌面/服务端更合适 |

**v1 不建议内置本地重排模型。** 先用混合检索 + 结构加权 + 轻量 LLM listwise 重排（只对 8–12 个候选做一次排序）验证收益；如果桌面端确有需要，再把 cross-encoder 作为可选能力。

### 3.4 文档解析 / OCR

| 方案 | 许可证 | 平台 | 结论 |
| --- | --- | --- | --- |
| `RapidOCR` | Apache-2.0 | Python/C++/多语言；ONNX 模型可移动端 | 扫描 PDF OCR 的首选落地候选 |
| PaddleOCR PP-OCRv6 tiny/small | Apache-2.0 | ONNX / Paddle；tiny 1.5M、small 7.7M、medium 34.5M | 移动端文字识别模型体积友好，适合后续 OCR |
| `Docling` | MIT | Python，桌面/服务端 | 复杂版面、表格、公式强；不适合直接进 Android |
| `MinerU` | MinerU Open Source License（Apache-2.0 + 附加条件） | Python，重型 | 桌面/服务端批处理候选，不进 v1 |
| `granite-docling-258M` | Apache-2.0 | 视觉文档模型 | 桌面可选，移动端暂不现实 |

PageSage 当前明确把扫描 PDF OCR 放在后续范围。这里的结论是：**不要用 Docling/MinerU 替换现有 EPUB/PDF 文本提取**；它们只适合未来做“扫描件/复杂版面导入”的桌面增强。

### 3.5 向量存储与编排

| 方案 | 许可证 | 结论 |
| --- | --- | --- |
| `sqlite-vec` | Apache-2.0 | pre-v1；当前 3,494 块规模不值得引入原生扩展 |
| LanceDB | Apache-2.0 | 面向更大规模与多模态，Flutter 集成成本高，不进 v1 |
| LangChain / LlamaIndex | MIT | Python/JS 生态强，但不适合直接塞进 Dart/Flutter；会把简单管线变成框架适配 |
| DCI（终端式语料交互） | 研究方案 | Android 无 shell；Token 与延迟不可预测；继续不采用 |

### 3.6 PageIndex（2026-11-08 专项评估）

[PageIndex](https://github.com/VectifyAI/PageIndex)（MIT）是
Vectorless 的树检索方案：先用 LLM 把文档整理成带摘要的章节树，再让模型沿树推理
定位，而不是直接做向量相似度。

**结论：借鉴思路，不引入 SDK，也不接 Cloud。**

| 维度 | 事实 | 对 PageSage 的影响 |
| --- | --- | --- |
| SDK 形态 | 官方 [Python SDK](https://github.com/VectifyAI/PageIndex) 提供本地与 Cloud 路径，另有 [JavaScript/TypeScript API SDK](https://github.com/VectifyAI/pageindex-js-sdk) | JS API 客户端不等于 Python 本地检索实现；也不能因有 SDK 就省去 Dart/Flutter 的架构工作 |
| 本地模式 | 开源仓库提供 PDF / Markdown 建树路径；其模型调用与纯本地结构解析应分别分析 | 不能因涉及模型就判定不允许采用；本次不改变 AI 触发设置，也不自动发送正文 |
| Cloud 模式 | 远端文档处理涉及上传；服务能力与开源本地实现应分别核验 | 当前不接 Cloud，不增加自动上传整本书的流程 |
| 建树成本 | 随文档、模型、调用路径与缓存变化，不能将示例每页成本视为通用报价 | 试点应记录实际 token、请求、时间和费用，不作固定成本承诺 |
| 已有结构 | EPUB TOC、PDF outline、Markdown 标题可复用，但可能缺失或不准确 | 优先复用可靠结构；仍需结构映射、精度标记与正文检索旁路 |

可借鉴的部分，按现有数据层落地即可，不新增依赖：

- 树节点摘要：为章节生成 1–2 句摘要和 `key_items`，作为「总结本章/全书」的缓存。
- 结构候选：标题路径和后续摘要补充正文候选，不先用固定数量章节硬过滤；详见 [父子分块算法](15-parent-child-chunking.md)。
- 兄弟节点合并：章节过多时按检索成本合并小节点，但保留原始标题作为 `key_items`。
- 页/章节级引用：沿用现有 locator，不引入 PageIndex 的页级引用格式。

可选试点：仅在 Windows 桌面端把 PageIndex 作为**外部本地服务**通过 HTTP 调用，
用于验证树质量；不作为移动端路径，也不作为默认能力。若复用其代码，MIT 许可证
要求保留版权与许可声明。

## 4. 推荐架构

```text
用户问题
  │
  ├─ 意图判断（轻量规则 + 可选一次结构化调用）
  │    ├─ 查找/解释：混合检索
  │    ├─ 对比：拆成两个子查询，各自检索
  │    ├─ 总结章节/全书：章节摘要缓存 + map-reduce
  │    └─ 引用定位：词法检索优先
  │
  ├─ 混合检索
  │    ├─ 现有 BM25 / 中文二元组
  │    ├─ 可选语义 top-K
  │    ├─ RRF 融合
  │    ├─ 结构加权（同章、邻近章节、标题路径）
  │    └─ 父块扩展（小块召回，大块送入模型）
  │
  ├─ 可选重排（桌面）
  │
  ├─ 上下文打包（预算、来源、顺序）
  │
  ├─ 生成（JSON 或带 [S1] 引用的 Markdown）
  │
  └─ 引用校验（不存在的来源、未覆盖的断言）
```

### 4.1 Provider 层

保持 `OpenAiCompatibleProvider`，但把它从“唯一实现”升级为“默认实现”：

- 增加 Provider 预设：OpenAI、DeepSeek、Qwen/DashScope、OpenRouter、Ollama、LM Studio、llama.cpp server、vLLM。
- `AiSettings` 增加能力字段，而不是继续用字符串猜：
  - `requiresApiKey`
  - `supportsJsonMode`
  - `supportsTools`
  - `supportsEmbeddings`
- 本地 Provider 允许空 API Key；`AiPanel._ask` 不能再把 `hasApiKey` 当作所有 Provider 的前置条件。
- 不急着为 Anthropic/Gemini 写原生适配；OpenAI-compatible 已覆盖当前开源模型生态的大部分使用方式。真正需要时再按能力抽象扩展。

### 4.2 检索层

在现有 `ContextRetriever` 外再加一层组合，而不是重写它：

1. 保留 BM25、中文二元组、目录页过滤、邻块扩展。
2. 新增 `SemanticIndex` 接口，负责查询嵌入和 top-K。
3. 新增 `HybridRetriever`，用 Reciprocal Rank Fusion 合并词法与语义结果。
4. 新增结构加权：同章、邻近章节、Markdown 标题路径、EPUB TOC 层级。
5. 已采用父子分块：小块召回后，父块不超过 1600 字符时送完整父块，超限时围绕命中子块截取父块窗口；块大小与字符预算仍不是 token 口径。算法、来源跨度、存储契约与真实离线结果见 [专项设计](15-parent-child-chunking.md)。
6. 对比型问题拆成多个子查询，分别检索后再按书/主题聚合，避免一个词只命中一侧。

### 4.3 存储层

建议新增 Drift 表，而不是直接改 `search_chunks`：

```text
chunk_embeddings
  chunk_id TEXT PRIMARY KEY
  model_id TEXT
  dimension INTEGER
  vector BLOB          -- float32 little-endian
  created_at INTEGER
```

原因：

- 换嵌入模型时可以整表重建，不影响原文分块；
- 可以记录模型版本与维度，避免混用不同向量空间；
- 3,500 块的暴力余弦在 isolate 中完成，不需要 `sqlite-vec`；
- 以后真超过 5 万块，再把同一接口替换成向量索引，不动上层。

### 4.4 生成层

新增一个轻量 `AnswerContract`：

```json
{
  "answer": "……",
  "citations": ["S1", "S3"],
  "unsupported": ["……"]
}
```

- Provider 支持 JSON mode 时优先用结构化输出；
- 不支持时退回 Markdown `[S1]` 引用，再在 Dart 侧解析；
- `citations` 必须能在本次 `AiContextReference` 列表中找到；
- 找不到依据时明确回答“当前检索内容不足以回答”，而不是编造。

这一步比换更大的模型更能改善“可信感”。

### 4.5 总结层

全书总结不要继续用 top-5 片段硬拼。建议：

- 索引时保留章节路径；
- 首次“总结本章”时生成章节摘要并缓存；
- “总结全书”先取章节摘要，再按预算做 map-reduce；
- 缓存键包含 `bookId + chapterId + model + promptVersion`；
- 摘要生成可由交互或后台任务触发，按具体功能设计控制范围与预算；模型请求必须明确上下文范围，不自动上传整本书。

## 5. 分阶段落地

### P0：不引入原生依赖，先把回答质量拉起来

1. Provider 预设、能力字段、本地无 Key 模式。
2. 意图路由：解释/查找、对比、章节总结、全书总结、引用定位。
3. 查询分解与混合检索融合（先只接现有词法 + 结构加权）。
4. 引用契约与校验；无依据时明确说不足。
5. 章节摘要缓存与全书 map-reduce。
6. 建立固定评测集：用当前 4 本书准备 30–50 个问题，记录 Recall@5、引用准确率、回答是否被引用支撑、延迟与 Token。

验收标准应先看评测集，而不是只看“感觉更聪明”。

### P1：本地语义检索

1. 接入 `bge-small-zh-v1.5` ONNX 量化模型（优先 `flutter_onnxruntime` 或 `flutter_edge_ai_onnx`）。
2. 增加 `chunk_embeddings` 表与 Drift 迁移。
3. 索引任务在后台 isolate 生成向量；失败可降级为纯词法。
4. 查询时并行跑词法与语义，RRF 融合。
5. 模型缺失、内存不足、索引未完成时，UI 明确显示“当前为词法检索”。

第一版不要默认下载大模型；把嵌入模型做成可选组件，并显示体积。

### P2：本地生成

先桌面、后 Android：

1. **桌面优先接 Ollama / llama.cpp server。** 用户已有服务时零额外包体，Windows 体验最好。
2. **应用内离线生成做 spike：** 首选 `flutter_edge_ai_llama`，备选 `fllama_cpp`；两者都是 MIT。
3. 模型分档：
   - Android 低内存：Qwen3.5-0.8B Q4_K_M，约 0.51GB；
   - Windows / 高内存 Android：Qwen3.5-2B Q4_K_M，约 1.28GB；
   - 4B 级模型只作为桌面可选项，不作为移动端默认。
4. 首次下载必须用户确认，显示体积、内存门槛和“仅在本地运行”说明。
5. 本地模型回答质量不足以支撑高质量书评/长总结时，UI 要允许切回云端 Provider。

### P3：扫描件与复杂版面

1. 先用 RapidOCR + PP-OCRv6 tiny/small ONNX 做扫描页文字识别。
2. 只在用户明确导入扫描 PDF 时触发，不默认全库 OCR。
3. Docling / MinerU / granite-docling 仅作为桌面端可选预处理，不进入 Android 主路径。

## 6. 明确不建议

- 不为 3,500 块引入 `sqlite-vec`、LanceDB 或 ANN 索引。
- 不把 LangChain/LlamaIndex 整包移植进 Flutter。
- 不默认下载 2GB+ 模型，不自动上传整本书。
- 不把 4B 模型作为 Android 默认；不把 0.6B 嵌入模型作为移动端默认。
- 不在 v1 内置本地 cross-encoder 重排。
- 不用 Docling/MinerU 替换现有 EPUB/PDF 文本提取。
- 不内置 PageIndex Python SDK，也不接 PageIndex Cloud；只借鉴其树摘要与树路由思路。
- 不恢复 DCI 作为移动端主检索方案。

## 7. 关键取舍

| 问题 | 选择 | 理由 |
| --- | --- | --- |
| 先换模型还是先改检索 | **先改检索和引用** | 同一模型下，召回和引用约束的收益更确定 |
| 向量库还是 BLOB | **BLOB + isolate 余弦** | 当前规模小，少一个原生依赖 |
| 云端还是本地 | **云端为主，本地可选** | 本地小模型质量有限，且下载/内存成本高 |
| 统一管线还是按意图分流 | **按意图分流** | 总结、对比、查证不是同一种检索问题 |
| 是否引入 RAG 框架 | **不引入** | PageSage 的数据层和引用模型已经足够，框架只会增加适配层 |
| 是否现在做 OCR | **后置** | 与问答质量升级独立，避免范围膨胀 |

## 8. 参考来源

项目与许可证状态按 2026-11-08 的官方仓库/模型卡核对：

- llama.cpp：<https://github.com/ggml-org/llama.cpp>（MIT）
- fllama_cpp：<https://github.com/Telosnex/fllama_cpp>（MIT）
- flutter_edge_ai：<https://github.com/DenisovAV/flutter_edge_ai>（MIT）
- Ollama：<https://github.com/ollama/ollama>（MIT）
- MLC LLM：<https://github.com/mlc-ai/mlc-llm>（Apache-2.0）
- ONNX Runtime GenAI：<https://github.com/microsoft/onnxruntime-genai>（MIT）
- flutter_onnxruntime：<https://github.com/masicai/flutter_onnxruntime>（MIT）
- bge-small-zh-v1.5：<https://huggingface.co/BAAI/bge-small-zh-v1.5>（MIT）
- bge-m3：<https://huggingface.co/BAAI/bge-m3>（MIT）
- Qwen3-Embedding-0.6B：<https://huggingface.co/Qwen/Qwen3-Embedding-0.6B>（Apache-2.0）
- Qwen3-Reranker-0.6B：<https://huggingface.co/Qwen/Qwen3-Reranker-0.6B>（Apache-2.0）
- bge-reranker-base：<https://huggingface.co/BAAI/bge-reranker-base>（MIT）
- RapidOCR：<https://github.com/RapidAI/RapidOCR>（Apache-2.0）
- PaddleOCR：<https://github.com/PaddlePaddle/PaddleOCR>（Apache-2.0）
- Docling：<https://github.com/docling-project/docling>（MIT）
- MinerU：<https://github.com/opendatalab/MinerU>（MinerU Open Source License）
- sqlite-vec：<https://github.com/asg017/sqlite-vec>（Apache-2.0，pre-v1）
- LanceDB：<https://github.com/lancedb/lancedb>（Apache-2.0）
- PageIndex：<https://github.com/VectifyAI/PageIndex>（MIT）
