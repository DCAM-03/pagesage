# AI 检索正确性修复执行记录

> 隐私维护（2026-11-12）：本文保留历史实验结论，样本身份、原始题集和指纹已移除。
> “恢复”“重放”“哈希匹配”均描述当时的验证，不能作为当前脱敏文件可独立复现的证明。
> 下方命令为脱敏参考，需要另备本地私有输入；完整新报告只保存到 `.local-data/`。

日期：2026-11-08

状态：`IMPLEMENTED`

验证结论：`TOOLING_PASS`。首轮证据与第一轮监督复核补修均保留；补修后的最终结果见第 9 节。这里不把聚焦测试、离线评测或安装核验升级为 LLM 回答质量、真实跳转正确率、运行时索引重建或跨书泛化的证明。

## 1. 工作区与身份

- 仓库：`<PROJECT_ROOT>`
- 分支：`main`
- HEAD：`3dbbec36b867d8c76fad398e8ed12cc1ad7cc198`
- 使用现有未提交工作区，未新建分支、工作树或提交，未重置既有改动。
- 未修改 `AGENTS.md`、模型配置、Skill 或协调任务文件 `docs/tasks/ai-retrieval-correctness-2026-11-08.md`。
- 监督会话已在当前执行会话的实际 turn context 中独立核验模型为 `workbuddy/deepseek-v4.1-flash`、推理档位 `max`、cwd 为目标仓库；本执行记录转述该核验结果，不自行读取进程 metadata。

本轮正确性修复没有新增数据库字段或迁移。父子块表和 `parent_id` 属于此前未提交的 schema v6 工作；本轮复用已有 `sourceKey`、locator 和原文跨度，没有清库或重建用户数据。

## 2. 四个缺陷的修复前后证据

复现入口：

```bash
dart --packages=.dart_tool/package_config.json \
  /tmp/pagesage_retrieval_review.dart
```

修复前记录：

| 场景 | 错误结果 |
| --- | --- |
| 完整备选集合 | 输入同时含 `alpha beta gamma` 时，`gamma` 的 1/1 完整集合存在，但旧评分选择 `alpha/beta/missing` 的 2/3 部分集合，导致该题判为失败 |
| 同父重复上下文 | 第 0、2 个子块命中后返回 2 条引用，但只有 1 份唯一文本 |
| Unicode 窗口末尾 | 1599 个 UTF-16 单位后接 emoji，窗口以孤立高代理项 `d83d` 结束 |
| 重复子文定位 | 真实子块偏移为 2138；旧窗口按第一次 `indexOf` 从父文 0 开始，包含 `FIRST_CONTEXT` 而不含 `SECOND_CONTEXT`，locator 仍停在子块位置 |

修复后实际输出：

```text
{"case":"complete_alternative","expectedSuccess":true,"actualSuccess":true,"selectedSet":1,"recall":1.0}
{"case":"duplicate_parent_context","referenceCount":1,"uniqueTexts":1,"parentLength":1316}
{"case":"unicode_window","length":1599,"lastCodeUnit":"61","endsWithUnpairedHighSurrogate":false}
{"case":"repeated_child_lookup","childOffset":2138,"returnedLocatorOffset":1958,"windowContainsFirstContext":false,"windowContainsSecondContext":true}
```

重复子文案例中的 `returnedLocatorOffset=1958` 是修复后 1600 单位窗口从真实子块偏移前导 180 单位后的正确起点，不是旧行为或子块猜测位置；旧行为从父文 0 开始，locator 仍为 2138。修复后窗口已包含第二次出现的 `SECOND_CONTEXT`，且不包含 `FIRST_CONTEXT`。

监督会话的 R1 复现入口 `/tmp/pagesage_supervision_review.dart` 在补修前输出：

```text
legacy_child_excerpt: textLength=687, startsWithLowSurrogate=true, declaredSpanLength=897, locatorChapterOffset=1000
ambiguous_pdf_child_excerpt: textLength=687, startsWithLowSurrogate=true, declaredSpanLength=897, locatorChapterOffset=null
```

补修后输出：

```text
legacy_child_excerpt: textLength=688, startsWithLowSurrogate=false, declaredSpanLength=688, locatorChapterOffset=1209
ambiguous_pdf_child_excerpt: textLength=688, startsWithLowSurrogate=false, declaredSpanLength=688, locatorChapterOffset=null
```

Markdown 起点从 1000 移到实际片段起点 1209；PDF 没有伪造字符级 locator，仍保持页级定位。两条路径的 `startOffset`/`endOffset` 都与返回文本长度一致。

## 3. 实现修复

### 3.1 上下文文本、源跨度和 locator 同步

`lib/features/ai/application/context_retriever.dart` 新增内部 `_ContextSlice`，把以下值作为同一决策生成：

- 实际发送文本
- 同源标识 `sourceKey`
- 半开源跨度 `[startOffset, endOffset)`
- 当前命中焦点 `[focusStart, focusEnd)`
- 完整源文和源 locator

可重排文本（EPUB、Markdown）从子块与父块 locator 的 `chapterOffset` 差值取得真实父内偏移，并验证该偏移上的正文确实等于子块文本。窗口 locator 随窗口起点和终点同步更新。

PDF 没有可重建窗口起点的字符偏移。仅在子文本于父文中唯一出现时使用唯一匹配扩展；重复时退回子块文本、保留其页级 locator，不猜测第一次出现的位置，也不伪造字符级 locator。

### 3.2 完整父块、局部窗口和内容去重

- 父块不超过 `ContextRetriever.maxBlockChars`（1600 UTF-16 单位）时继续发送完整父块，保留同父较早事实。
- 父块超限时围绕真实子块偏移截取窗口，保留约 180 单位前导；窗口严格不超过预算。
- 选择阶段和最终输出都按 `sourceKey + 实际跨度` 去重，不再按文本是否相同推断来源相同。
- 同父下不重叠的独立证据保留为不同引用。
- 两个同父窗口部分重叠时，在两侧命中之间切分，避免重复发送同一段上下文。
- 非相邻子块选中同一完整父块时合并为一条引用，不再因位置差重复发送父文。

### 3.3 Unicode 安全边界与真实相对跨度

`_safeWindow` 统一用于父块局部窗口和旧索引/PDF 的 `_excerpt` 回退路径，同时检查窗口首尾：

- 起点落在低代理项且前一单位是高代理项时，回退 1 个代码单元。
- 终点切开代理对时，回退 1 个代码单元。
- 返回文本、`startOffset`、`endOffset` 和 locator 都使用调整后的实际区间。
- 调整后仍严格不超过 `maxBlockChars`。

旧索引回退路径不再把整块声明为实际片段：Markdown locator 的 `chapterOffset`/`chapterEndOffset` 随截取起点和终点移动；PDF 保持页级 locator，不伪造字符级 locator。无法表达为单一连续源区间的多成员拼接引用将 `sourceKey`/跨度置空，不把虚构拼接长度冒充真实源跨度。

旧索引和重复 PDF 回退都有起点/终点正式回归测试；真实 EPUB 样本没有非 BMP 字符，因此真实书库不能替代该合成边界检查。

### 3.4 引用携带可选源跨度

`lib/features/ai/application/ai_context_reference.dart` 为运行时引用增加可选 `sourceKey`、`startOffset`、`endOffset`。字段不改变读者看到的正文或 locator，只供选择、去重和离线评测识别实际源区间。没有数据库 schema 变更。

## 4. 评测器口径修复

`tool/retrieval_eval/evaluation_core.dart` 与 `tool/evaluate_chunking_effect.dart` 已修正：

1. 任意完整备选证据集合优先。完整集合不会再被“命中片段更多”的部分集合压过。
2. `payloadChars` 使用最终实际拼接文本的 `joinedText.length`，包含来源标题和分隔符。
3. 删除“黄金短语出现次数”伪重复指标；上下文重复按同一 `sourceKey` 下声明源跨度的重叠长度计算。
4. 把原先容易被误读为跳转正确率的 `locatorValid` 拆为：
   - `locatorPresentCount`
   - `locatorPresentRate`
   - `allLocatorsPresent`

   它们只表示 locator 非空，不表示能跳到正确位置。
5. 无答案题分开报告 `emptyOnNoAnswer` 与 `nonEmptyOnNoAnswer`。非空结果既包括无关召回，也包括已有部分词面证据但无法回答。
6. `EvaluationReference` 增加可选源跨度，评测器不依赖“同一段文字出现几次”猜测重复。
7. 缺失 `sourceKey`/跨度不再被当成“已测得零重复”：新增 `sourceRangeReferenceCount`、`sourceRangeCoverageRate`，未知跨度不进入重复率分母；没有可测引用时，`contextDuplicateRate` 与汇总重复指标输出 `null`。
8. 多段拼接且无法用单一连续源区间表达的引用不伪造 `sourceKey`/`startOffset`/`endOffset`。

评测集校正：

- 原 33 题 `real_books_2026-11-08.json` 从交接快照恢复为 version=1，不再用同一路径和版本号静默替换。
- 将源文实际包含 QPACK 的 `question-45` 改为按源文作答的 `question-26`，新增不含查询词的真正无答案题 `question-27`，作为 version=2 的 `real_books_2026-11-08-v2-corrected.json` 单独保存。
- 诊断集由旧 33 题变为 34 题 v2；旧结果 `docs/eval/retrieval-effect-2026-11-08.json` 保留不动，不能与新 34 题百分比直接比较。
- 评测输出包含数据集内容 SHA-256，避免只靠路径和 version 识别输入。

## 5. 评测结果

### 5.1 34 题 v2 真实书库诊断（补修后重放）

数据源为 4 本真实书：匿名样本 01、匿名样本 02、匿名样本 03 和 Markdown 文件夹 匿名样本 04。主评测数据库按只读方式打开，为现有 schema v5 用户库；评测器自行从源文生成两路候选，不写入用户库。

命令：

```bash
dart run tool/evaluate_chunking_effect.dart \
  --dataset .local-data/retrieval-eval/real_books_2026-11-08-v2-corrected.json \
  --database "${PAGESAGE_EVAL_DATABASE:?请提供私有测试数据库路径}" \
  --output .local-data/retrieval-eval/retrieval-effect-2026-11-08-v2-supervised.json
```

| 指标 | 旧基线 | 父子块候选 |
| --- | ---: | ---: |
| 完整证据覆盖 | 15/34（44.1%） | 19/34（55.9%） |
| 可答题完整覆盖 | 14/31 | 18/31 |
| 证据召回均值（仅可答题） | 56.2% | 62.1% |
| 逐题结果 | — | 4 胜 / 0 负 / 30 平 |
| 平均实际 payload 字符 | 1,995.4 | 2,211.1 |
| 平均引用数 | 2.06 | 1.94 |
| 证据密度均值 | 2.93% | 5.51% |
| 可测源跨度引用 | 0/70（未测量） | 66/66（100%） |
| 上下文跨度重复率 | 未测量 | 0.0% |
| locator 非空率 | 100% | 100% |
| 检索 p50 / p95 | 72.3 / 167.5 ms | 72.7 / 168.6 ms |
| 无答案题返回空结果 | 1/3 | 1/3 |
| 无答案题返回非空结果 | 2/3 | 2/3 |

4 个改善题为 `question-13`、`question-19`、`question-38`、`question-41`。30 个平局中仍有大量可答题未找齐全部证据，且 2/3 无答案题仍返回非空结果；不能把总体改善解释为无答案能力已解决。

新结果文件写入数据集 SHA-256 `<PRIVATE_DATASET_SHA256>`。首轮 `retrieval-effect-2026-11-08-corrected.json` 保留不改。34 题集合参与缺陷发现和实现验证，不是独立留出，也不是统计显著或跨书泛化证明。候选平均 payload 增加约 10.8%，不能只看覆盖率而忽略额外预算。

### 5.2 真实 EPUB 冻结留出

使用未参与前 33 题调参的《匿名样本 05》原始 EPUB：

- 路径：`<PRIVATE_SOURCE>`
- SHA-256：`<PRIVATE_SOURCE>`
- 题目：`.local-data/retrieval-eval/epub_holdout_2026-11-08.json`
- 10 题在首次运行前按实际解析正文人工取证；首次运行后未据此调参

命令：

```bash
dart run tool/evaluate_chunking_effect.dart \
  --dataset .local-data/retrieval-eval/epub_holdout_2026-11-08.json \
  --database /tmp/pagesage_epub_holdout_20261108.sqlite \
  --output .local-data/retrieval-eval/retrieval-epub-holdout-2026-11-08-supervised-audit.json
```

临时 SQLite 仅供评测器读取真实 EPUB 的书籍元数据行；其中的 UUID 是评测本地 ID，不是 PageSage 用户数据库或产品数据。

| 指标 | 旧基线 | 父子块候选 |
| --- | ---: | ---: |
| 完整证据覆盖 | 7/10（70.0%） | 7/10（70.0%） |
| 可答题完整覆盖 | 7/9 | 7/9 |
| 证据召回均值（仅可答题） | 83.3% | 88.9% |
| 逐题结果 | — | 0 胜 / 0 负 / 10 平 |
| 平均实际 payload 字符 | 2,087.0 | 2,589.3 |
| 可测源跨度引用 | 0/20（未测量） | 20/20（100%） |
| 上下文跨度重复率 | 未测量 | 0.0% |
| locator 非空率 | 100% | 100% |
| 无答案题返回空结果 | 0/1 | 0/1 |
| 检索 p50 / p95 | 14.9 / 17.9 ms | 14.9 / 18.3 ms |

首轮结果 `retrieval-epub-holdout-2026-11-08.json` 保留不改；本次是修复后的审计重放，不是新的独立留出。该留出只覆盖一本 EPUB、10 个问题。候选证据召回提高但完整覆盖未提高，平均 payload 增加约 24.1%，且唯一无答案题两路都错误返回非空结果。不能据此声称跨书泛化或模型回答质量提升。

### 5.3 原 33 题数据集恢复后的审计重放

原 33 题数据集已从交接快照恢复，SHA-256 为 `<PRIVATE_DATASET_SHA256>`，version=1。为证明旧路径仍可复现且不覆盖首轮快照，使用新输出文件：

```bash
dart run tool/evaluate_chunking_effect.dart \
  --dataset .local-data/retrieval-eval/real_books_2026-11-08.json \
  --database "${PAGESAGE_EVAL_DATABASE:?请提供私有测试数据库路径}" \
  --output .local-data/retrieval-eval/retrieval-effect-2026-11-08-v1-supervised-audit.json
```

结果：完整覆盖 13/33 → 17/33，可答题 13/30 → 17/30，召回 54.7% → 60.8%，4 胜/0 负/29 平，平均 payload 2,011 → 2,255，可测源跨度引用 0/70（未测量）→ 66/66（100%），候选重复率 0.0%。该结果只用于审计恢复后的历史数据集，不是新留出或调参依据。

## 6. 命令与验证结果

### 6.1 首轮缺陷复现与聚焦回归（历史）

```bash
flutter test --concurrency=4 \
  test/core/database/search_parent_migration_test.dart \
  test/core/database/search_repository_test.dart \
  test/core/search/search_indexer_test.dart \
  test/core/search/structure_chunker_test.dart \
  test/features/ai/context_retriever_test.dart \
  test/features/ai/parent_context_effect_test.dart \
  test/tool/retrieval_eval_test.dart
```

结果：`58/58` 通过，退出码 0。

其中直接锁定本轮缺陷的断言包括：

- 完整备选证据集合 `gamma` 胜出，`selectedSet=1`、`recall=1.0`。
- 1316 单位重复父块只返回 1 条引用和 1 份唯一文本。
- 同父不重叠证据保留 2 条；部分重叠窗口在两侧命中之间切开。
- 重复子文使用存储偏移，窗口包含 `SECOND_CONTEXT`、不包含 `FIRST_CONTEXT`。
- 窗口尾部不出现孤立高代理项；起点为低代理项时回退 1 单位，locator 同步回退。
- payload 统计等于实际拼接文本长度且大于两段正文裸长度之和。
- 同源跨度重叠按重叠字符计，不把黄金短语重复当上下文重复。
- 任意完整备选集合优先于更高部分召回；无答案空结果单独判定。

### 6.2 首轮静态与完整回归（历史；监督补修后未重跑全量）

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test --concurrency=4
flutter test --concurrency=4 test/tool/release_readiness_test.dart
```

- `flutter analyze`：`No issues found!`
- 格式检查：214 个 Dart 文件，0 改动。
- 完整 `flutter test`：562 个测试通过、2 个环境相关测试跳过、0 失败，退出码 0。跳过项与本地未生成 Android/Windows 构建产物有关。
- 文档新增后运行 release readiness，确认文档链接、发布资产等检查仍通过。

### 6.3 监督复核补修验证

补修只重跑受影响的命名文件，不重新执行全量测试：

```bash
flutter test --concurrency=4 \
  test/features/ai/context_retriever_test.dart \
  test/tool/retrieval_eval_test.dart
flutter analyze
dart format --output=none --set-exit-if-changed .
```

- 两个命名测试文件共 42 个测试通过；新增 4 个旧索引/PDF 回退双端断言、1 个原始 2/3 对 1/1 回归，以及未测量/部分测量/真实零/真实重叠断言。
- `flutter analyze`：`No issues found!`
- 补修后 `dart format --output=none --set-exit-if-changed .`：214 个文件、0 改动；不重跑全量测试。
- 受影响评测使用 version=2 数据集、原 33 题 v1 审计和 EPUB 审计三个新输出文件，均不覆盖首轮快照。

### 6.4 Linux 构建与安装

```bash
CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh
```

结果：release bundle 构建成功并安装到 `<HOME>/.local/opt/pagesage`。

- 主 Dart 载荷 `<HOME>/.local/opt/pagesage/lib/libapp.so`：14,025,616 字节，mtime `2026-11-08 23:27:15 +08:00`，SHA-256 `cf7ea7746937067ce2913da41217f1818f03798323dc5dea32110643260999db`。最终重装在 23:31 完成，应用代码未再变化，载荷保持同一哈希。
- 安装载荷与 `build/linux/x64/release/bundle/lib/libapp.so` 哈希一致。
- `pagesage` 启动壳 SHA-256 `ad58a1c45c52438faa74c546cb558e75bad856e7aac4c3ac2eb459f639a47210`，与构建 bundle 一致；启动壳本身未重新链接，应用代码在已更新的 `libapp.so` 中。
- 桌面入口 `<HOME>/.local/share/applications/dev.pagesage.pagesage.desktop` 已在最终重装时更新，`Exec` 指向新安装路径。
- 未启动新窗口，未终止或重启已运行的 PageSage。运行中的旧进程不会自动获得新构建，需要用户自行重启后才使用本次安装。

## 7. 仍存在的限制

1. PDF 中同一子文本重复出现时，没有真实字符偏移可恢复窗口起点。实现会退回子块文本本身并保持页级 locator，不扩展父窗；这避免了猜错，但截取跨度的来源只是该子块提取文本，不是 PDF 页内字符坐标。
2. 34 题 v2 诊断参与调参，1 本 EPUB 留出只覆盖 10 题；EPUB 重放是修复后审计，不是新的独立留出。两者都不证明跨书、跨语言或跨格式泛化。
3. `locatorPresentRate=100%` 只表示 locator 非空，不是跳转正确率。本轮没有人工点击验证真实 EPUB/PDF 跳转。
4. 主评测数据库是 schema v5 旧索引；评测器从源文自行生成 v6 候选。没有验证应用运行时对用户现有书籍完成索引重建、快照发布或并发读取。
5. 无答案题仍为 1/3 空结果、2/3 非空结果；词法检索尚未解决证据不足判定。
6. 未评测 LLM 最终答案正确性、引用忠实性或“无法回答”措辞。
7. 未在 Windows 实机或 Android 真机验证；完整测试中的平台构建跳过项不能算平台验收。
8. 真实 EPUB 没有非 BMP 字符；Unicode 首尾安全仅由合成边界测试覆盖。
9. 模型身份由监督会话在实际 turn context 中核验；本执行环境没有独立读取该 metadata。

## 8. 本轮直接改动文件

应用与评测：

- `lib/features/ai/application/context_retriever.dart`
- `lib/features/ai/application/ai_context_reference.dart`
- `tool/retrieval_eval/evaluation_core.dart`
- `tool/evaluate_chunking_effect.dart`

回归测试：

- `test/features/ai/context_retriever_test.dart`
- `test/tool/retrieval_eval_test.dart`

评测数据与结果：

- `.local-data/retrieval-eval/real_books_2026-11-08.json`
- `.local-data/retrieval-eval/real_books_2026-11-08-v2-corrected.json`
- `.local-data/retrieval-eval/epub_holdout_2026-11-08.json`
- `docs/eval/retrieval-effect-2026-11-08-corrected.json`
- `docs/eval/retrieval-epub-holdout-2026-11-08.json`
- `docs/eval/retrieval-effect-2026-11-08-v1-supervised-audit.json`
- `docs/eval/retrieval-effect-2026-11-08-v2-supervised.json`
- `docs/eval/retrieval-epub-holdout-2026-11-08-supervised-audit.json`

算法与复核文档：

- `docs/15-parent-child-chunking.md`
- `docs/16-chunking-research-review-2026-11-08.md`
- `docs/tasks/ai-retrieval-correctness-2026-11-08-execution.md`

工作区还包含此前已存在、属于父子块第一版和阅读器/UI 的未提交改动；本记录不把那些改动全部归为本轮正确性修复。没有提交、合并、删除用户原书或改写协调任务文件。

## 9. 第一轮监督复核补修结论

- R1：旧索引和重复 PDF 回退共用 Unicode 安全的实际截取区间；Markdown locator 随片段移动，PDF 只保留页级 locator；多成员拼接不伪造单一跨度。两条回退路径均有起点/终点回归。
- R2：正式测试改为 `['alpha','beta','missing']` 对 `['gamma']`、正文 `alpha beta gamma`，断言选择 1/1 集合并成功；旧评分实现会因优先 2/3 部分集合而失败。
- R3：未知源跨度输出未测量/`null`，新增可测引用数与覆盖率；只有带 `sourceKey` 和有效半开区间的引用进入重复率分母。没有元数据、部分元数据、真实零重叠和真实重叠均有测试。
- R4：原 33 题 v1 数据集已恢复；34 题校正集另存为 version=2；旧 33 题、首轮 34 题和首轮 EPUB 结果均未覆盖；评测报告写入数据集内容 SHA-256。旧重复子文行为已更正为窗口从 0 开始、locator 仍为 2138，1958 是修复后窗口起点。
- 验证只重跑两个命名测试文件、`flutter analyze`、格式检查和三个受影响评测审计输出；没有重新跑全量测试，也没有据结果调参。应用代码变化后再次安装，主 `libapp.so` 为 `2026-11-08 23:27:15`，SHA-256 `cf7ea7746937067ce2913da41217f1818f03798323dc5dea32110643260999db`。
- 未启动应用、未终止或重启用户已运行实例；真实跳转、运行时索引重建、LLM 回答质量和 Windows/Android 实机仍未验证。
