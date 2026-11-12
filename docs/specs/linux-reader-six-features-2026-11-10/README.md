# Linux 阅读体验六项功能：统一规格

日期：2026-11-10。状态：F1–F6 的应用内实现已接入并通过自动回归；F2 真实模型质量、F6 冻结质量/性能语料，以及真实窗口、平台和用户验收仍未完成。逐项证据边界见各子规格与 [联合验证](07-validation-and-acceptance.md)。

## 1. 本次交付与阅读顺序

用户要求一次性规划六项功能，形成可一起验收的详细规格。初次交付为文档；后续实施按依赖连续推进，不以每完成一个子任务为理由中断，不额外创建会话、提交或发布流程。实施进度与实际验证分别记入对应子规格和实现清单。

| 任务 | 详细规格 | 交付结果 |
| --- | --- | --- |
| F1 | [Markdown 外部变更同步](01-markdown-live-refresh.md) | 文件树与当前文件大纲独立，外部修改、增删及可靠改名后可继续阅读 |
| F2 | [AI 回答可靠性](02-ai-answer-reliability.md) | 证据不足、索引不可用、来源已变化和正常回答有不同处理，引用可核对 |
| F3 | [多组 AI 配置](03-ai-profiles.md) | 命名配置、独立密钥、请求身份冻结、可恢复迁移 |
| F4 | [中文搜索](04-chinese-search.md) | 中文短词、连续句和中英混合查询可用，过滤、排名及高亮一致 |
| F5 | [Mermaid 图形阅读](05-mermaid-rendering.md) | 离线渲染明确支持的流程图与时序图，其他语法保留完整源码 |
| F6 | [Linux OCR 与页级任务](06-ocr-search-and-jobs.md) | 本地引擎、选页、恢复、取消、结果入库与搜索形成闭环 |
| 共用 | [联合验证与验收](07-validation-and-acceptance.md) | 六项一次交付的用例、数据、证据及通过门槛 |

本文的共用契约优先于各子规格中重复的简称。当前实现仍以代码和实际验证证据为准；除子规格明确记录已实现的内容外，新增类型、接口、表、测试路径仍为拟议设计。

## 2. 实现基线与范围

以下为规格创建时的 2026-11-10 工作区基线，包含已有未提交变更，不能以 Git HEAD 代替；后续进度见各子规格。

| 已核对事实 | 实施影响 |
| --- | --- |
| `lib/core/database/app_database.dart` 当前 schema 为 7 | 升级从真实 v7 结构开始，不各自占用相同版本号 |
| Markdown 文件夹已按单文件会话阅读，文件树、大纲已分离 | F1 延续该结构，不重新合并全部正文 |
| AI 已有父子块检索、历史线程、来源快照 v1 和导出 | F2 补证据决策及回答核验，不重做已有功能 |
| AI 设置表单已有草稿、互斥操作与过期测试保护 | F3 继承这些行为，并增加配置身份 |
| 搜索已有过滤与中文 LIKE 回退，重建会先删除旧索引 | F4 改中文索引与排名；先补原子发布 |
| Mermaid 目前显示源码，数学公式已有原生渲染 | F5 增加图形，不把公式列为未实现 |
| Linux OCR engine 与 rasterizer 在 `ocr_providers.dart` 中返回 stub | F6 先完成 Linux 能力，不把通道接口当作可用引擎 |

本次以 Linux 为实施、安装与实际验收平台。Windows/Android 保持编译边界和已有 adapter，不承诺本轮真机结果。历史文档中 PDF.js、Linux 后置、OCR 后置等描述仅反映当时范围；六项是本轮拟推进的扩展，不表示这些能力已经落地。

不加入云同步、账号、整书自动上传、向用户 Markdown 目录写入、MOBI/AZW、本地大模型运行时或默认云 OCR。F5 首期是明确的 Mermaid 语法子集，不宣称 Typora/Mermaid 全量兼容。

## 3. 共用不变量

1. 文件夹书始终只读、就地读取；单文件导入仍复制至书库。移除书籍不删除外部源目录。
2. 文件树表示目录和文件；大纲只表示当前打开文件的标题。文件刷新不切侧栏页签。
3. 解析、搜索、OCR 和 AI 使用同一来源身份及版本；过期异步结果不能覆盖新版本。
4. 位置中的文本偏移保持现有章节解析字符串的 UTF-16 code unit、左闭右开区间；不能把原始 Markdown、Unicode rune 或分词字符串偏移冒充正文偏移。
5. PDF 对外页码为 1-based，底层数组 pageIndex 为 0-based，只在 adapter 边界转换。矩形为旋转、裁剪后的显示页坐标，归一化至 `[0,1]`。
6. 所有新增实体主键使用 UUID；既有历史复合字符串 ID 保持可读，不为统一格式重写用户关联。时间均为 Unix 毫秒。
7. 来源历史、用户摘录和 AI 请求快照不可被文件刷新或配置切换改写。重新定位是当前视图上的解析结果，不修改历史原文。
8. 搜索重建不先删当前有效结果；新一代完成并校验后事务发布。无法核实当前版本时不把旧文本当作新文本。
9. 普通日志不包含正文、页面图像、密钥、完整提示词或上下文。性能证据只存样本编号、计数与耗时。

## 4. 来源身份、版本与定位

### 4.1 三种身份不可混用

| 名称 | 定义 |
| --- | --- |
| `documentSourceId` | PageSage 分配的 UUID；对应一个 Markdown 文件、EPUB 章节或 PDF 页，不等于标题、排序号或内容 hash |
| `sourceRevision` | 原始来源的 SHA-256 标识。Markdown 为文件原始字节 hash；EPUB 为归档 hash 与规范化 href 的定长编码元组 hash；PDF 为文件 hash 与 1-based 页码元组 hash |
| `textRevision` | `SHA256(extractorVersion + 文本变体 + 原坐标正文)`，采用带长度的规范编码；正文不做搜索归一化。用于判定偏移对应哪份解析文本 |
| `generationId` | 一次索引构建的 UUID，绑定来源版本、解析版本与分词版本，不是文件身份 |

不同文件内容相同也有不同 `documentSourceId`。文件同路径更新沿用尚未删除的身份但改变版本；确认删除后的同路径新建默认新身份。可靠改名条件见 F1，不能靠相同 hash 随意合并。

PDF/EPUB 的原文件 hash 改变会使其来源版本整体失效，首期接受保守重建的成本。不会因为页码相同而复用另一版 PDF 的 OCR。

### 4.2 `ReadingLocator` 拟增可选字段

`documentSourceId`、`sourceRevision`、`textRevision`、`textQuote`。`textQuote` 为 `exact/prefix/suffix`：确切选区最多 256 UTF-16 单位，前后文各最多 64，按字符边界截断，超长选区仍以已有 selectedText 与区间为准。明确记录 quote 是否截断，截断 quote 不足以恢复完整选区。

- 旧 locator 缺字段时仍按原路径读取，标记 `legacyUnverified`，不能假造精确版本。
- 新定位返回 `exact / reanchored / approximate / missing / ambiguous / unreadable`，该状态是运行结果，不伪装成持久化的确定事实。
- 精确区间须满足来源、文本版本及边界；版本变更后只接受唯一且上下文一致的重锚。否则最多跳至文件/章节/页并提示位置可能变化，不画错误划线。
- PDF 无精确字符范围时保留页级定位与 OCR 块框，不从相似文本猜出字符位置。
- 保存进度、书签、批注、笔记、搜索结果、AI 快照和导出都须传递这些字段；旧 JSON 和快照版本的读取有单独测试。

## 5. 共用索引发布契约（S0）

### 5.1 拟新增结构

| 表/改动 | 核心字段与约束 |
| --- | --- |
| `document_sources` | `id, book_id, kind, address, current_source_revision?, state, observed_size?, observed_mtime?, observed_at, created_at, updated_at`；kind 为 `markdown_file/epub_chapter/pdf_page`；state 为 `present/missing/unreadable`；仅活动地址唯一，删除留 tombstone |
| `search_index_units` | `id, unit_key UNIQUE, book_id?, document_source_id?, requested_input_revision, active_generation_id?, state, updated_at`；unit_key 使用规范编码，区分 `metadata/source/note/bookmark/ai` |
| `search_index_generations` | `id, unit_id, input_revision, source_revision?, text_revision?, text_origin, extractor_version, tokenizer_version, state, created_at, published_at?`；text_origin 为 `native/ocr`，state 为 `building/published/superseded/failed` |
| `search_chunks` / `search_parent_chunks` | 增加可空 `generation_id, document_source_id, source_revision, text_revision, start_offset, end_offset`；旧 `source_type/source_id/parent_id` 保留原语义 |

`address` 是书内规范相对路径/章节 href/`page:1`；不写外部绝对路径进可导出 locator。新复合 unit_key 用规范序列化，不能用未转义冒号拼接任意用户路径。`search_index_units.state` 为 `pending/ready/stale/failed`，描述当前可查询性，区别于构建过程。

`inputRevision` 是所有实际索引输入（正文、标题、定位、源版本、提取/分词配置）的规范编码 hash。元数据、笔记、书签、AI 等非文件实体同样必须有 inputRevision；不能以可能相同的 updatedAt 代替，也不能因 sourceRevision 为空就跳过过期检查。更新实体时同时推进 requested_input_revision，发布时比较预期值；实体已删除时禁止重新创建其 unit。

`present/unreadable` 地址至多对应一个活动 source；`missing` 是非活动 tombstone，保留旧定位身份。删除用户书籍时，应用层事务显式清理关联表与 FTS，不假设现有数据库已启用级联。

### 5.2 构建与发布

1. 读取来源与版本；创建 generation，分批构建 parent、child 及派生 term，不改 active 指针。新 parent/child 使用 UUID，同一 generation 内引用闭合。
2. 原坐标正文不可随意 trim；chunk 必须等于该 `textRevision` 下的 `[startOffset,endOffset)` 子串。非正文来源可无 offset。
3. 完成时重新核对 inputRevision、source 的观察版本、解析请求 epoch、取消状态和书籍/实体存在性。磁盘读取采用 stat-before/read/hash/stat-after；变化则丢弃重试。
4. 一个短事务内发布所有受本次操作影响的 unit 指针、FTS 派生行以及状态；父子块不可跨 generation。变更多文件时允许按文件发布，UI 明确部分文件待索引。
5. 查询只读取 active generation；正文还须与来源当前观察版本一致、state 为 present。观察到文件变化后旧代保留用于恢复但不进入正常搜索或 AI。
6. 查询在同一 SQLite 读事务中解析候选、父块与 provenance，返回版本快照。模型请求离开事务前复制实际上下文，不持有数据库长事务等待网络。
7. 当前指针更新后清理旧代；已复制的 AI 历史不会随清理丢失。取消只移除未发布代。崩溃后清理无 active 引用的 building 代，允许重试。

“当前版本”表示最近完整核实的来源，文件系统与 SQLite 无法做跨系统原子事务。F1 的监听/复核周期及点击跳转时再次核实共同限制这个窗口，不宣称磁盘任意时刻的强一致性。

### 5.3 v7 旧索引引导

不得在数据库迁移中读用户目录或猜解旧 sourceId。旧 rows 留存为 legacy 集合，新字段为 null；元数据、笔记、书签、AI 索引按真实关联逐项重建，书籍正文按完整初始构建转换。

- 引导期间可显示旧搜索结果，标记“旧索引，待更新”，跳转时按旧定位核实；不宣称精确高亮。
- AI 的书内自动检索只使用已核实的新代；尚未就绪时说明正在建立索引，不能用“书中没有答案”代替。显式当前选区仍可按可见文本构建快照。
- 首次转换一本书时，所有新正文 unit 完成后事务切换该书至新模式，再排除该书 legacy rows，防止重复或半本缺失。失败保留旧集合与错误状态。后续才按文件/页增量发布。
- 初始重建期间的源变更使整本初始候选失效重试；不能用混合新旧目录声明初始化完成。
- F4 分词升级同样按代发布，不先清空旧 FTS。

## 6. 数据库升级顺序

以下是本批次的顺序规划，不得跳过中间版本；实施期间若其他功能已经增加版本，应以新基线顺延并同步本表及测试，不覆盖已发布迁移。

| 顺序 | 计划版本 | 增量 |
| --- | --- | --- |
| S0 | 7 → 8 | 来源注册、索引 unit/generation、chunk provenance 与旧索引引导 |
| S2 | 8 → 9 | `ai_profiles`、请求 profile 快照、密钥迁移日志状态 |
| S3 | 9 → 10 | 中文/归一化派生 term 与两路 FTS；重建可恢复 |
| S4 | 10 → 11 | `ai_conversations.answer_meta`；来源快照 v2 的读取/写入 |
| S6 | 11 → 12 | OCR 缓存签名、页级任务/checkpoint 与索引恢复状态 |

locator 可选字段与 F5 不单独升 SQL 版本。新增表/列通过 Drift 与生成器管理；FTS/触发器用受迁移测试约束的 SQL。新库和 v7 逐级升级必须收敛到相同结构。

数据库升级失败回滚事务并保留旧库；跨 secure storage 的恢复由 F3 journal 处理。新 schema 不支持旧应用直接降级打开；恢复升级前备份是回退路径，不提供清库或降低 user_version 的捷径。

## 7. 实施顺序与硬依赖

| 阶段 | 完整切片 | 硬依赖 |
| --- | --- | --- |
| S0 | 来源/定位/索引原子发布与真实迁移测试 | 当前 v7 数据契约 |
| S1 | F1 文件监听、差异协调、重锚、文件树状态、搜索失效 | S0 |
| S2 | F3 配置 CRUD、密钥迁移、设置 UI、请求身份快照 | S0；不依赖 F1 UI |
| S3 | F4 中文索引、查询、排名、高亮、回归评测 | S0；需覆盖 F1 动态来源 |
| S4 | F2 证据状态、来源核验、历史与导出、冻结评测 | S2、S3；可先写纯策略测试 |
| S5 | F5 语法子集、布局、原生绘制与源码回退 | 既有 Markdown block；回归 F1 视图刷新 |
| S6 | F6 Linux 引擎、范围任务、缓存、入索引和恢复 | S0、S3；AI 交接消费 S4 契约 |
| S7 | 联合升级/恢复/删除/读书链路与本地安装核对 | 全部六项 |

单个切片包含数据、应用、UI、测试、相关文档与静默安装，不把“写了核心类”当作完成。可以连续完成这些切片，最终按一份联合清单验收。文档统一评审与功能最终验收是两种不同状态。

## 8. 资源与失败策略

- SQLite/Drift 保持唯一持久化主库；不引入 DuckDB、向量数据库或常驻额外服务。
- 文件监听、分词、图布局、OCR 使用有界队列、可取消 epoch、可释放资源。具体预算在子规格；所有性能数字均为待测目标。
- Mermaid 采用原生 Dart 子集 renderer，不附带 Node/Chromium；Linux OCR 采用可选本地 Tesseract，页面光栅化复用现有 PDF 图形栈。无依赖时显示具体缺失能力，不自动安装系统软件。
- 模型 API 的真实费用、耗时和正确率需要独立证据；离线测试不冒充真实模型验证。
- 每次 app-affecting 切片通过必要检查后运行 `bash tool/install_linux.sh` 并核对 bundle；不启动、关闭或重启应用，不开新终端窗口。文档本轮不构建/安装。

## 9. 完成边界

本轮规格完成：六份详细 spec、共用契约、依赖/迁移顺序、联合用例、文档引用检查齐全。

未来功能完成：按 [联合验收](07-validation-and-acceptance.md) 逐项登记真实证据；未测项保持未验证。尤其不能用安装成功替代 OCR 质量、AI 答案质量或真实阅读位置验收。
