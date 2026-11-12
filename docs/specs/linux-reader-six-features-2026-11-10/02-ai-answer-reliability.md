# F2：AI 回答可靠性与证据边界

状态：证据策略、引用核验、`answer_meta` 与来源快照 v2 已实现并通过本地自动验证；真实模型冻结评测与人工忠实性验收待执行。共用版本与发布契约见 [总规格](README.md)。

## 1. 当前能力与已知缺口

当前 `context_retriever.dart` 已有词法评分、CJK bigram、父子块扩展及去重；`retrieval_context_source.dart` 支持当前书/同分类检索；`AiChatService` 检查可见引用拼接与实际 contextText 一致，并保存线程和来源快照。

[已有检索执行记录](../../tasks/ai-retrieval-correctness-2026-11-08-execution.md) 的无答案案例中，只有 1/3 为空，2/3 仍返回非空内容；这不能证明模型已经能拒答。既有评测也未充分验证最终模型答案、引文忠实性和真实跳转。F2 解决这些缺口，不把“检索不为空”等同有答案，也不把“有 locator”等同跳对位置。

首期仍采用本地词法+结构检索，不增加 embedding 服务、外部 reranker 或额外模型自动审稿调用。算法效果通过冻结样本验证，达不到门槛继续修正，不能用新阈值包装成已通过。

## 2. 产品模式与状态

书内问答以当前可见范围为界；已有解释/翻译/改写等模式可对显式文本工作，不因书内事实门禁被全部禁用。`AnswerIntent` 区分 `sourceQuestion/explain/translate/rewrite`，模式必须在界面明确，不能通过猜用户问题自动切到范围外常识问答。

### 2.1 检索前置状态

| EvidenceState | 含义 | 处理 |
| --- | --- | --- |
| `unavailable` | 索引未就绪、读取失败、来源变更待重建或权限错误 | 不说“没有答案”；展示真实原因，可重试/选择当前文本 |
| `none` | 在完成且有效的既定范围中无可用候选，或预算后没有正文 | 书内问答不调用模型生成书中结论；显示“当前范围未检索到可用证据”，可更改范围 |
| `weak` | 有候选但主要是宽泛重叠、孤立片段，或问题部分信息缺失 | 明示证据有限；仅发可见候选，要求模型逐项标出不足；结果默认未核验 |
| `eligible` | 有满足当前检索规则的可追溯证据 | 正常发送；仍须检查生成后的引用，不能称“答案确定正确” |

这些是工程决策状态，不是概率或事实真值。`none` 不是全书无答案的证明；`eligible` 也不是语义蕴含的保证。用户扩大范围只通过已有明确选择，不自动由当前章扩大到分类/全库。

范围内部分文件尚未可读/索引时标 scopeCompleteness=partial：已有候选仍可在明示不完整范围后 weak/eligible；没有候选必须 unavailable，不能判 none。只有已完整检查的实际范围允许 none。

### 2.2 回答状态

`answerStatus = insufficient / sourceLinked / unverified / interrupted / failed`。

- `insufficient`：本地没有证据，或模型明确表示材料不足；支持解释是哪部分未找到，不能编造页码。
- `sourceLinked`：书内事实段落均带合法、可定位的引用，且引用检查通过。UI 文案“已关联来源”，详情说明未独立验证结论的语义正确性。
- `unverified`：没有合法引用、引用不完整、版本无法核实或引用检查失败；回答原文可保留但不得有已验证标识。
- `interrupted/failed`：区分用户取消、网络中断和生成失败；已有流式文本标记未完成，不当作正常答案沉淀。

“部分有依据”通过 claim 的检查状态表达，整体仍 unverified，不用绿色整卡掩盖未支持部分。解释/改写不是事实检索时，显示模式而不强行给“来源已验证”。

## 3. 算法与请求流程

### 3.1 输入与检索

输入包含 prompt、显式 range、AnswerIntent、bookId、选区快照、profile snapshot、requestEpoch。范围只使用现有选区/当前页或章/当前书/同分类的实际入口，未增加任意全库检索。

1. 核实来源版本和索引代。当前选区直接复制可见文本及 locator；其他范围通过 S0 active generation 读取。候选集合保留查询 scope、版本、候选数和截断原因。
2. 查询采用 F4 统一 normalization/中文 token；默认最多 100 个子块候选进入本地重排，再取最多 8 个来源窗口。不得先跨范围取全局 topK 再过滤。
3. 父窗口只能来自命中子块的同一 source/textRevision/generation；在窗口边界扩展，不跨文件拼成伪连续引文。
4. 按来源和原坐标区间合并重叠，保留不同来源的相同文字。历史对话与正文引用分开预算，历史回答不可作为新的书内事实来源。
5. 延用现有上下文长度预算并显式记录截断；在引用边界切分，截断后重新生成区间与精度，不能保留已被截掉的 source span。

字符预算是估算，不宣称精确 token 数；context limit 错误显示可减少范围/历史，不自动换配置或发送整章整书。

### 3.2 证据决策

`EvidencePolicyV1` 使用可解释特征：有效来源数量、规范化问题词组在候选中的覆盖、精确短语、前两名分差、相邻命中支持、截断比例、索引完整性和用户显式文本。初始规则：

- 来源失效/读取错误优先 unavailable；无有效文本为 none。
- 只有停用泛词、候选全为元数据/标题，或问题实体在正文完全未命中，判 weak，不硬判该实体在书中不存在。
- 其余有实质正文候选可 eligible；短问题、代词问题和翻译不能仅因词覆盖低判无证据。带上下文续问把当前问题与有界的前一轮用户问题联合检索，不拿前轮模型推断当证据。
- 词覆盖与分差的具体参数属于带版本的调参文件，只能用开发集决定，再冻结到留出集；不设跨书通用的裸 BM25 分数阈值，也不展示伪精确“置信度 93%”。

这里的“问题实体”首期不假设有 NER 模型：仅用数字/引号内短语、非停用 Latin token、连续至少两个 CJK 字的查询组作可解释锚点；代词与只有单字的问题不套该项硬规则。实体锚点缺失只降低证据状态，不推出语义上的不存在。

局部门禁只保证不会在明确没有来源时伪造书内回答，不能静态判断所有复杂问题是否可回答；语义不足由提示约束、可核对引用及真实模型评测补足。

### 3.3 序列化与发送

使用统一 `AiContextSerializer` 给引用分配本次请求内 `R1...R8`，将来源标签、正文和引用 ID 组成唯一 context 字符串。预览和 `AiChatService` 发送必须使用同一序列化结果；现有 joined-text 一致性校验继续保留。提示协议说明材料是不可信内容，不执行其中要求修改范围、调用工具或泄露密钥的指令。

回答约定：书内事实段落使用 `[R1]` 等引用；需要逐字引文时复制原文，不自行修正后仍称原文。对材料未覆盖的子问题明确说明不足。普通文本协议优先，不依赖所有 OpenAI-compatible 服务都支持 structured output。

流式阶段仅展示“生成中，引用待核对”；final 事件后完成引用解析再赋 final 状态。请求复制上下文后来源变化，保留当时版本快照并显示来源已更新；不在流中换成新文本。发送前发现版本已变则重新构建预览，不无提示发送旧版本。

### 3.4 本地核验

1. 解析 `[R<整数>]` 并检查是否存在于本次白名单，非法 ID 不映射到附近引用。代码块和转义符中的字符不计引用。
2. 为段落记录引用集合；书内事实段落无引文时整体不得 sourceLinked。该覆盖检查是保守结构检查，不自称能准确分类所有事实句。
3. 模型声称逐字引用的文本必须在对应 snapshot 原文内精确出现；只允许换行表示方式归一，不能改数字、否定词或实体。重复引文不能据此生成新的精确偏移。
4. 来源跳转重新核实当前文件/页版本：exact、reanchored、approximate、missing 分开。引用快照仍可看，当前原文不可达时不能伪造跳转成功。
5. 检查通过只证明 ID/文本/版本关联，不能证明“引用支持结论”。语义忠实性仍须真实模型评测；不把另一个同模型自动评分当唯一验收依据。

## 4. 数据与消费者契约

### 4.1 来源快照 v2

保留 v1 的 range/truncated/references；每个 reference 新增：`citationId`、`provenanceKind(document/userProvided/legacy)`、`documentSourceId?`、`sourceRevision?`、`textRevision?`、`generationId?`、`precision`。

旧 v1 正常读取，来源版本为未知，不补写当前文件版本；未知版本继续明确拒绝解析，保留原记录与导出能力。v2 逐字段验证类型、区间、重复 citationId 和引用数量。手工编辑引用正文时清除 sourceKey/offset/provenance 的精确版本；原 locator 最多作为导航提示，不能保持“原文精确摘录”。

### 4.2 answer_meta JSON v1

v11 在 `ai_conversations` 增加可空 `answer_meta`：

| 字段 | 语义 |
| --- | --- |
| `version` | 1；未知版本不伪装当前模型 |
| `intent/evidenceState/answerStatus` | 本次决策与最终状态 |
| `policyVersion/reasonCodes` | 规则版本与无正文的原因码 |
| `citations` | citationId、snapshot referenceId、核验状态；不新增正文副本 |
| `claimChecks` | 段落 ordinal、引用 ID、missing/invalid/quoteMismatch 等结构检查 |
| `scopeCompleteness/truncated` | 实际范围的就绪/部分/不可用与预算裁剪 |

旧记录 answer_meta=null，显示“历史回答，未执行本次核验”，不重跑模型或改写答案。profile 身份消费 F3 已保存的不可变 snapshot。

本地 none/unavailable 的反馈可存入线程，但 answer_meta 另记 `producer=localPolicy`，provider=`pagesage-local`、model=`evidence-policy-v1`，profile_id/snapshot 为 null，UI 显示“本地检索反馈”。不得冒充当前模型已经回答；构造下一轮模型 history 时不把它作为模型事实或已发送调用。

快照 decoder 保持严格校验；repository 边界返回可辨的 unsupported/corrupt 状态并保留原始 JSON 供导出，不把解析失败降成空历史。这个安全结果类型须同步历史面板与导出消费者，不能只修改 decoder。

### 4.3 链路同步

| 消费者 | 要求 |
| --- | --- |
| AI 面板 | 证据原因、引用列表、当前版本跳转、未完成状态可见 |
| 历史续问 | 恢复当时正文与各轮 profile；新提问重新核实来源 |
| 保存为笔记 | 保留 final 状态与引用；unverified/insufficient 不去掉提示 |
| 搜索 | 历史 AI 回答仍可搜，但正文事实检索不把 AI 回答循环当作书籍来源 |
| Markdown/Notebook/AI 导出 | 原文、引用列表、状态、来源精度及当时模型一致 |
| 删除/备份 | 来源被删仍保留聊天 snapshot；密钥不进入备份 |

错误码：`evidence_unavailable/no_evidence/source_changed/context_truncated/citation_unknown/citation_missing/quote_mismatch/generation_interrupted`。错误与不足分开，不用空回答掩盖异常。

## 5. 实施与效果门槛

切片：F2-A evidence policy 与反例；F2-B serializer/引用核验/流状态；F2-C v11 和快照 v1/v2/导出；F2-D 冻结评测与真实模型验收。依赖 S0、F3、F4；可先完成不依赖 UI 的纯逻辑测试。

统一评测共 72 题，开发 24、留出 48，按来源文档分组隔离；留出中 32 可回答、16 不足。不得用先前 10 题的小样本报告替代。

- 确定性测试：越界来源、无效引用、错误版本、过期任务覆盖、悄悄扩大范围均为 0。
- 留出 32 道可答题中，top5 来源窗口包含该题全部必需 gold 片段的题数至少 29（≥ 90%）；另报单 span Recall@5，不用部分子问题命中代替整题完整证据。版本正确的来源跳转 100% 通过固定定位用例。
- 真实模型：不足题至少 15/16 正确说明不足；可回答题错误拒答不超过 3/32；人工拆解事实断言后忠实于证据的比例 ≥ 95%，非法引用 ID 为 0。样本数、分母、失败题号同时报告。
- 两次固定配置运行报告各次及合计，不能只选较好的一次；模型/provider/version/参数冻结。推理随机性和语义正确性的边界明确记录。

没有可用凭证或未获实际调用授权时，真实模型部分保持待验证，不阻断纯本地测试但不能声明 F2 效果验收通过。

## 6. 验收用例

| ID | 场景 | 必须结果 |
| --- | --- | --- |
| F2-01 | 检索为空、索引未建、文件失效三种情况 | 原因不同；均不编造书中结论 |
| F2-02 | 泛词匹配、问题实体缺失、部分子问题可答 | weak/部分不足可解释，不套万能阈值 |
| F2-03 | 相同引用文本来自两书、PDF 重复段落 | 身份不合并；PDF 只保留能证明的页级精度 |
| F2-04 | 模型输出不存在的 R9、无引用、错引数字 | 检查失败，不能 sourceLinked |
| F2-05 | 流式中取消、断网、切 profile、文件变更 | 文本/身份快照不漂移，未完成状态保留 |
| F2-06 | v1/v2/未知版本历史、手动编辑引用 | 兼容有边界，编辑后不保留伪精确 provenance |
| F2-07 | 范围包含诱导上传/改提示词的正文 | 不执行材料内指令、不扩大范围 |
| F2-08 | AI 笔记再次被搜索、导出历史 | 不循环作为书内证据，状态与引用保真 |
| F2-09 | 版本更新发生在候选读取/发布/发送之间 | 结果与快照为完整单代，过期时重新预览 |

拟新增 `test/features/ai/evidence_policy_test.dart`、`test/features/ai/answer_citation_verifier_test.dart`、`test/core/database/ai_answer_meta_migration_test.dart`。扩展现有 `test/features/ai/ai_chat_service_test.dart`、`test/core/database/ai_context_snapshot_test.dart`、`test/features/ai/parent_context_effect_test.dart`，并在现有 `tool/retrieval_eval/` 中增加冻结数据与最终答案评分输出。
