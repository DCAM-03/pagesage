# F4：中文搜索、统一排名与原文高亮

状态：中文索引、原子发布与 60 题自动评测已实现；真实大库性能与用户验收待执行。依赖 S0 原子索引。

2026-11-12 增量：完成 10k 块合成库基准、连续输入隔离与实际命中定位修复；
归一化版本为 `normalizer-v2`（修复 UTF-16 代理对映射），现有类名保留。
只回填缺失/过期派生 term，禁止查询中整库重建 FTS。结果与真实大库证据边界见
[联合记录](../../tasks/search-restore-export-2026-11-11.md)。

## 1. 基线与目标

`lib/core/database/drift_search_repository.dart` 当前先 FTS，中文不足 limit 时再 LIKE，并按返回顺序拼接；`SearchNormalizer` 已做全半角、空白及小写。已有书籍/正文/笔记/书签/AI 类型、书籍/分类/标签/格式过滤和来源跳转。

改进目标：中文单字/双字/连续句、中英混合、全半角查询行为一致；命中前先过滤；同一版本内稳定排名；高亮回到原文。首期不引入大型词典、拼音/繁简转换、模糊纠错、向量数据库或 DuckDB。

## 2. 用户查询语义

| 输入 | 明确语义 |
| --- | --- |
| `知识` | 连续双字命中；优先标题及原文完整短语 |
| `知识管理` | 不分空格的一组中文；完整短语优先，bigram 覆盖可召回部分匹配并标明相关结果 |
| `知识 管理` | 空白分开的两组 AND，均须在同一结果正文/标题内满足，不在不同书籍拼接 |
| `Flutter 状态管理` | 拉丁 token 与中文组 AND，不把整句当一个不可分词条 |
| `数` | CJK unigram 候选；常见字多时有“结果较多”提示，不扫描无限全文 |
| `ＡＩ　阅读` | 全半角、大小写、空白规范后匹配，显示原文 |
| `a" OR 1=1`、`100%` | 一律作为文字和普通分组解析，不暴露 FTS/SQL 操作符 |
| 空白/纯分隔符 | 空结果或提示输入文字，不触发全库查询 |

默认不提供高级查询语言；双引号、冒号、括号等不直接进入 MATCH 表达式。中文较长组的“相关匹配”不是精确子串命中，UI 不画出原文并不存在的整句高亮。

限制：输入最多 256 UTF-16 单位，最多 16 个语义组、128 个生成 term。超限显示输入过长，不静默丢后半句来改变语义。每次输入 debounce 250 ms，requestEpoch 拦截过期结果。

无空白的中英混合串也按 Latin/CJK run 边界形成 AND 组；标点是词法边界而不是操作符。百分号等仅参与原句精确优先判断，不提供任意符号单独全文检索；因此纯标点输入不查全库。

## 3. 归一化与偏移反向映射

`SearchTextNormalizerV1` 对 rune 遍历，做全角 ASCII → 半角、ASCII 大小写折叠、空白折叠；中文及标点本身不做语义替换。归一化算法和 token 版本一并持久化。

每个输出 UTF-16 单位对应原文 `[start,end)`，折叠多个空白时映射到整段原始空白。surrogate pair 不在中间截断。首期不做可能扩展字符长度的通用 Unicode casefold/NFKC，以免规则与运行环境漂移。

搜索用归一化文本，展示与 locator 使用原坐标正文。候选确定后按相同版本重算映射，无须为全部正文永久存 offset 数组；抽样验证重算 textRevision 一致。HTML/snippet 标记只用于 UI，不把 FTS highlight 的 token 坐标当作正文偏移。

## 4. 分词和索引

### 4.1 方案选择

采用应用侧 CJK unigram+bigram 与普通 Latin token，两路 FTS5 候选融合。SQLite 内置 trigram 的全文查询不适合一/双字中文，因此不把“切换 trigram”作为完整方案。FTS5 能力在真实 SQLite 启动检查，缺失返回明确能力错误，不无提示退回无限 LIKE。

CJK 范围 V1 明确包括汉字基本区/扩展区、兼容汉字、平假名、片假名、Hangul 音节；范围表固定在 tokenizer 测试，不用字体或平台语言判断。标点、空白、Latin 与 CJK 边界终止 ngram run。

每个 CJK rune 生成 `u`+六位十六进制 Unicode 值，相邻对生成 `b`+两个六位值；例如“中文”包含 `u004e2d`、`u006587`、`b004e2d006587`。term 只含 ASCII 字母数字，以空格分隔，避免分隔符被 unicode61 再切开。不能把 token 文本导出为正文。

重复词保留真实频次用于 BM25，但设置每 chunk 的总 term 上限并按 chunk 边界控制，不截断后半 chunk。超过上限重新切块，继承结构化父窗口，不跨 source/textRevision。新切块不得破坏现有父子来源和精确 substring 契约。

### 4.2 v10 派生结构

`search_term_documents` 为普通派生表：`id(UUID), chunk_id UNIQUE, generation_id, title_normalized, text_normalized, title_terms, text_terms, normalizer_version, tokenizer_version`。其 SQLite rowid 仅作 FTS rowid，不对领域暴露。

两张 external-content FTS5：

- `search_normalized_fts(title_normalized,text_normalized,content='search_term_documents',content_rowid='rowid')`，Latin/数字词法候选。
- `search_cjk_fts(title_terms,text_terms,content='search_term_documents',content_rowid='rowid')`，编码后的 unigram/bigram 候选。

两路的 INSERT/UPDATE/DELETE trigger 都以派生表 OLD/NEW 对应列维护；外部 content 的列名必须真实存在，不能指向未分词的 search_chunks 原文。已有数据在创建 trigger 后仍需 backfill/rebuild，不能认为触发器会自动索引旧行。

派生表与 chunk/generation 的写入、删除在事务内一致；失败不可发布 active 指针。升级重建按 generation 并保留旧 token 路由到当前有效代，不能一次删掉所有搜索能力。旧 `search_chunks_fts` 在仍有 legacy/旧 tokenizer 代使用时保留，全部转完且一致性检查通过后才可后续迁移移除。

## 5. 候选、过滤和融合算法

### 5.1 执行顺序

1. 规范输入，构造 typed query groups，绑定 type/book/category/tags/format 过滤。多标签延用当前 DAO 的 AND：书籍必须包含所有选中标签；独立无书籍笔记在书籍标签过滤下不冒充符合条件。固定测试，不能本次悄悄改成 OR。
2. 在同一读事务读取 active generation、可用 source revision 和候选。每路在 SQL 中先过滤再 ORDER/LIMIT，不先取全库 topK。
3. Latin 路取最多 500 条；中文路精确 term/短语候选与宽松覆盖候选各最多 500 条。达到预算记录 `candidateTruncated=true`，合计最多 1,500 条，不无限扩候选。
4. 中文单字查 unigram，双字查 bigram，较长组查 bigram AND 的严格候选，并取有界 OR 候选补召回；所有空白组最终都必须满足组内覆盖条件。
5. 对候选原始规范文本复核：两字/单字组必须完整命中；长中文组精确子串优先，相关匹配至少覆盖 2/3 不同 bigram 且有不少于 2 个相邻 bigram 的连续链；少于 3 个 bigram 的组要求全部覆盖。混合语义组全部成立才保留。
6. 合并两路候选，再 rerank、去重，最后取 query.limit（默认 50，允许 1–200）。

每路 SQL MATCH 由 parser 输出白名单 term，参数绑定传入；不插入用户原始 MATCH 语法。特殊 `%/_/引号` 在诊断 fallback 中也必须转义。常规中文不依赖全库 LIKE，诊断 fallback 不属于用户正常查询路径。

每路 ORDER BY 必须在 LIMIT 前加入稳定 tie-break（BM25 后按 unit_key、chunkId），否则即使最终排序稳定，候选边界也会因同分项变动而漂移。

### 5.2 可比较的排名

独立 FTS 的裸 BM25 不直接相加。先按各路 rank 计算 `RRF = Σ 1/(60+rank)`，同源重复结果只在同一路保留一次，再采用确定性排序：

1. 所有查询组都作为原文完整短语命中（exact tier）；
2. 标题精确覆盖的组数，正文精确覆盖的组数；
3. RRF，随后最小命中跨度；
4. 同分时用规范书名、bookId、source address、startOffset、chunkId 作稳定 tie-break，不依赖异步返回先后。

该顺序是 V1 默认，通过开发集比较 exact 命中、短词、常用字和混合查询，再冻结；不得为单个失败题随意改变未版本化权重。

去重键是来源身份+textRevision+实际命中区间；重叠 parent/child 合并为一条窗口，多处不同命中保留。不同书/文件即使原文相同也不全局合并。书籍元数据与正文可显示不同类型，但不能同一个 chunk 重复出现。

### 5.3 返回契约

拟增加 `SearchResponse(results,indexState,candidateTruncated,requestEpoch,snapshotId)`；`SearchResult` 保留旧字段，增加 provenance、matchRanges、matchKind(exact/related)、precision。旧调用方需迁移到 wrapper，不以默认空列表吞掉错误。

无结果、索引构建中、部分文件失效、查询错误区分。候选截断时只说“显示相关结果，候选已截断”，不宣称给出了全部结果；不提供伪准确总数。若未来加入翻页，必须冻结 snapshot 与排序，本期不附带无限滚动新需求。

## 6. 高亮、跳转和 AI 消费

- snippet 从原始文本截取，按反向映射高亮真实命中片段，最多 3 个区间、约 180 个可见字符；在字符边界取窗。
- 长词相关匹配只高亮实际匹配片段，不能连续染色覆盖不存在的整句。主题、大字体和屏幕阅读器可识别命中。
- locator 的 start/end 加 source chunk 原坐标偏移后跳转；若当前 source 已更新走 F1 重锚或显示过期，不跳错同名文件。
- 全局搜索、书内搜索和 AI 的候选读取共用 normalizer、来源有效性及过滤定义；AI 自有上下文重排/预算仍独立，不能因为 UI top50 就丢失 AI 所需父窗口。
- 笔记、书签、AI 回答仍索引各自实体正文。不能把 AI 回答当作对应书籍的原文段落。OCR 文本按 F6 来源标识进入同一管线。

## 7. 迁移、恢复和性能

v10 新增派生表/FTS，旧内容不删。按书/实体增量重建，在后台任务中心可观察、可取消；重启只恢复尚未完成的 generation。备份含主数据与版本，恢复后检测派生一致性，必要时重建而不清笔记。删除实体/书籍同时清两路 FTS、派生项和 generations。

目标负载：10,000 chunks、至少 1,000 万 UTF-16 正文单位；温查询 P95 ≤ 300 ms、冷查询 ≤ 1 秒；查询不在 UI isolate 同步扫描全库。中文派生索引总额外磁盘目标 ≤ 原正文 UTF-8 字节 10 倍，超过时先报告并优化 term/切块，不悄悄删字降召回。记录实际 SQLite 版本、FTS5 编译能力、语料规模、构建耗时与文件大小。

## 8. 实施与验收

F4-A normalization/映射/tokenizer；F4-B v10 与 generation 重建；F4-C 过滤/候选融合/稳定排序；F4-D snippet/reader/AI 契约和冻结评测。

| ID | 场景 | 必须结果 |
| --- | --- | --- |
| F4-01 | 单字、双字、长句、中文空白 AND | 语义符合表定义，核心精确 fixture 必命中 |
| F4-02 | 中英/数字/全角/大小写/emoji | 查询归一化，高亮不切 surrogate pair、不偏移 |
| F4-03 | 其他分类 1,000 高分项、当前分类少量命中 | 先过滤再 limit，目标项不被跨分类预算挤掉 |
| F4-04 | 相同查询反复执行、异步顺序扰动 | 同一快照排序相同，旧请求不覆盖新输入 |
| F4-05 | 引号/SQL/FTS 操作符与超长输入 | 无注入、无未处理异常，超限有反馈 |
| F4-06 | 索引重建/取消/崩溃/来源删除 | 只能查询完整 active 代，不读混合父子块 |
| F4-07 | 不同文件同文、多处命中、重叠窗口 | 正确去重且不吞掉不同来源 |
| F4-08 | 旧库升级、trigger 更新/删除、备份重开 | 双 FTS 与原文一致，删除后无幽灵命中 |
| F4-09 | 原文精确不存在但 bigram 相关 | 标 related，仅高亮实际片段 |

拟新增 `test/core/search/cjk_tokenizer_test.dart`、`test/core/search/search_offset_map_test.dart`、`test/core/database/chinese_search_migration_test.dart`、`test/core/search/search_ranking_test.dart`；扩展 `test/core/database/search_repository_test.dart` 与 `test/features/reader/in_book_search_controller_test.dart`。联合验收要求 60 条搜索题（开发 20/留出 40）、留出 Recall@10 ≥ 95%（至少 38/40）、过滤越界与错位高亮为 0；同时报告旧基线，不以只补题不跑基线宣称提升。

## 9. 外部依据

[SQLite FTS5 官方文档](https://www.sqlite.org/fts5.html) 的 tokenizer、external-content、trigger 和 rebuild 说明作为实现依据；本方案的 CJK 编码、rank fusion 与预算是 PageSage 自身设计，效果须按上述数据验证。
