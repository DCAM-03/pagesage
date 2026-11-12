# F6：Linux 本地 OCR、选页任务与搜索

状态：F6-A 至 F6-D 的应用内实现已接入并通过自动验证；F6-E 的 30 页冻结质量/性能、真实窗口与用户验收仍待执行。计划 SQL v12；依赖共用来源/索引与 F4 中文搜索。

### F6-A 实施前验证计划（2026-11-10）

- 基线：Tesseract 5.5.4 与中英模型已实测，Linux provider 仍返回 stub；可见页已有 PNG 导出与叠层通道。
- 本轮：通过参数数组静默调用本地引擎，真实 TSV 能力探测、语言白名单、正文/行框转换、有界输出、私有临时文件、取消和超时；接入当前页现有复制/AI/叠层流程。
- 决定性验证：新增 `test/core/ocr/tesseract_process_test.dart`、`test/core/ocr/tesseract_tsv_test.dart`、`test/core/ocr/linux_tesseract_ocr_engine_test.dart`；扩展当前页用例及协调器测试。真实引擎使用本机合成英文页独立 smoke test，不能以 fake process 冒充真实识别。
- 资源反例：非法或越界 TSV、缺输出配置却退出 0、语言缺失、非零退出、输出超限、进程不响应 terminate、取消后迟到结果、临时文件清理；导出 PNG 限制长边/像素并保留白底与显示方向。
- 证据放 `build/ocr-linux-current-page-2026-11-10/`；通过后静默构建安装并对比完整 bundle。不启动真实窗口，不把该切片当作独立 PDF rasterizer、v12、队列/搜索或完整质量验收。

### F6-A 实施边界与结果（2026-11-10）

- Linux provider 现已选择 `LinuxTesseractOcrEngine`，通过当前可见页 PNG → Tesseract → TSV 行框 → 原有当前页 controller/内存与 Drift 页缓存链路，复用既有叠层、复制和 AI 交接。能力信息采用可选领域接口 `OcrCapabilitySource` / `OcrCapability`，不另建重复的应用状态服务。
- 探测真实小图协议，版本/语言正确但 TSV 配置缺失仍判不可用；同一引擎串行执行、限制输出和线程数、超时或取消终止进程。临时目录在写入页面前设为并核对 `0700`，正常、失败和取消路径均清理；不在日志输出页面或原始诊断。
- 当前页 controller 与协调器随阅读器订阅释放；切书或重复请求有请求身份保护，迟到结果不再向旧阅读页显示。可见页导出增加 2,200 px / 5,000,000 像素限制与不透明白底，沿用已有显示方向与裁剪变换。
- 本轮未增加依赖、未修改 schema。显式语言请求绕过未版本化旧缓存；默认请求仍沿用既有 book/page 缓存。完整来源/模型/参数签名、空白页持久化和崩溃遗留临时目录回收尚未实现。
- 真实验证使用自有合成中英页面及无文字层扫描 PDF，包含实际 Linux provider、画布导出、Tesseract 和临时文件 SQLite 重开；不以 fake process 或旧外部引擎评测替代这些证据。结果与安装核对见 [本轮接入验证](../../eval/ocr-linux-current-page-2026-11-10.md)。
- 独立 PDF rasterizer 仍为 stub；未挂载页面导出失败后无法在 Linux 独立重渲染。选页任务、暂停/恢复、OCR 入搜索、词/行偏移 envelope、完整旋转/裁剪语料和性能质量门槛留在 F6-B 至 F6-E。现有结果面板动作沿用，未进行真实窗口手工验收。

### F6-B 至 F6-D 实施结果（2026-11-11）

- Linux 已接入独立 `NativePdfPageRasterizer`，不再依赖当前页 Widget 已挂载；范围任务可在无活动阅读器时按页渲染。原有显示页导出路径仍保留，当前页优先使用用户实际看到的像素。
- `ocr_pages` 已补齐 `sourceRevision`、`cacheSignature`、`textRevision`、`engineVersion`、`pipelineVersion`、`resultState` 与 `indexState`。缓存签名覆盖来源、引擎、语言、DPI、长边、像素预算和文本管线版本；旧未签名缓存只用于阅读叠层，不进入搜索。
- 空识别结果可持久化为 `empty`，重跑时复用，避免空白扫描页反复消耗 OCR。结果保存成功与搜索可用仍是两个 checkpoint。
- 已接入 `ocr_jobs` / `ocr_job_pages` 持久任务：显式页码范围、去重排序、原生文字页跳过、签名缓存复用、空页完成、失败页继续、暂停、取消、继续和崩溃后恢复为 paused。任务中心显示页级进度并可暂停/继续。
- `SearchIndexer` 只消费已签名的 OCR 页；同页有原生文字时原生优先。OCR chunk 标记 `textOrigin=ocr`，结果标题显示“识别文本”，定位精度为 `pageOnly`。删书会同步删除 OCR job、page checkpoint 与 OCR 缓存。
- 新增真实 Drift 链路验证：OCR 任务启动、暂停、继续与完成；OCR 文本写入后进入 FTS；结果返回 `textOrigin=ocr` 与 `pageOnly`；旧来源版本的 OCR 不进入索引；新空结果会重建索引并撤下旧 OCR 命中。
- 验证：新增 7 项真实 SQLite/任务链路测试；OCR、搜索、任务中心与阅读器定向回归 193 项通过；全仓 `flutter test --concurrency=4` 954 项通过、5 项按环境跳过；`flutter analyze` 无问题。日志位于 `/tmp/pagesage-f6-targeted-3.log`、`/tmp/pagesage-f6-new-tests-4.log`、`/tmp/pagesage-f6-full-final-4.log` 与 `/tmp/pagesage-f6-analyze-9.log`。
- Linux release 已静默重建安装，`diff -qr` 无差异；构建与安装的 `pagesage` SHA-256 均为 `ad58a1c45c52438faa74c546cb558e75bad856e7aac4c3ac2eb459f639a47210`，`lib/libapp.so` 均为 `df1239ec6a1288120450bfc8a5a1a437419cc87ef36e98f06ab8d8a01cc0cde7`。安装日志为 `/tmp/pagesage-f6-install-3.log`；安装时没有运行中的 PageSage，未启动窗口。

### 任务中心失败页重试与清除结果（2026-11-11）

- 部分完成/失败任务增加“重试失败页”，只把 `failed` 页重置为 pending；已识别、空页、原生跳过和完成页不重新识别。
- 非运行中的 OCR 任务增加“清除 OCR 结果”。确认后删除该任务页面的会话缓存与 Drift `ocr_pages`、删除 `ocr_jobs`/`ocr_job_pages` checkpoint，并重建该书搜索索引；PDF、原生文字、笔记和批注不删除。
- 清除入口只作用于任务关联的页码，不提供“按书模糊清空”；运行中任务必须先暂停或取消。任务记录保留为 cancelled 并写明清除页数，便于用户确认结果。
- 验证：OCR、任务中心、索引器与真实 Drift 链路 53 项聚焦通过；全仓 961 项通过、5 项按环境跳过；`flutter analyze` 无问题。日志为 `/tmp/pagesage-f6-controls-focused-1.log`、`/tmp/pagesage-f6-controls-full-1.log` 与 `/tmp/pagesage-f6-controls-analyze-1.log`。
- Linux release 已静默安装，bundle 一致；`lib/libapp.so` SHA-256 为 `a35146894a2830225e211e7f5bfec6461610dc592ec3cdd1f10941f85f967412`。安装日志为 `/tmp/pagesage-f6-controls-install-1.log`；安装时无运行实例。

### OCR 范围任务跨任务串行 worker（2026-11-11）

- `OcrJobController` 增加进程内 FIFO 单 worker。多个页码范围任务可分别入队，但同一时刻只执行一个任务；后续任务保持 queued，前序完成后再启动。
- 排队项持有本进程取消令牌，任务中心启动恢复不会把当前会话的 queued 任务误判为上次中断；暂停、取消会先移出队列并清理令牌，不会在 worker 空闲后重新启动。
- 暂停排队任务同步写回 `paused` 并保留页 checkpoint；继续时重新入队。取消排队任务把未完成页标为 cancelled，后续任务继续按队列执行。
- 本约束覆盖 OCR 页码范围批处理任务；当前页交互式 OCR 仍走现有单次路径，未在本次改动中并入同一调度门。
- 验证：控制器队列/暂停/取消 10 项测试通过；OCR、任务中心、数据库与索引器 56 项聚焦回归通过；全仓 964 项通过、5 项按环境跳过；`flutter analyze` 无问题。日志为 `/tmp/pagesage-f6-single-worker-controller-3.log`、`/tmp/pagesage-f6-single-worker-focused-1.log`、`/tmp/pagesage-f6-single-worker-full-1.log` 与 `/tmp/pagesage-f6-single-worker-analyze-1.log`。
- Linux release 已静默安装，`diff -qr` 无差异；`pagesage` SHA-256 为 `ad58a1c45c52438faa74c546cb558e75bad856e7aac4c3ac2eb459f639a47210`，`lib/libapp.so` 为 `fac4db6b079db25589493c69121115135adca26526fd79eef4b28d16ef3e59af`。安装日志为 `/tmp/pagesage-f6-single-worker-install-1.log`；安装时无运行实例。

仍未完成：30 页冻结质量语料与 CER/RSS/耗时门槛、真实窗口手工验收及备份恢复边界实测。上述缺口使 F6 不能标记为完整验收通过。

## 1. 真实基线和交付目标

规格创建时已有 `OcrCurrentPageUseCase`、内存/Drift 页缓存、归一化 block 框、当前页复制/AI 及阅读器叠层；`lib/features/ocr/application/ocr_providers.dart` 当时只为 Android/Windows 选择 method-channel engine/rasterizer，Linux 返回两个 stub。F6-A 现已替换 Linux 图像识别引擎，独立 rasterizer 仍待 F6-B。

`ocr_pages` 当前按 bookId+pageNumber 唯一，缺少文件版本/语言/引擎签名；任务枚举无 `ocrPages`；搜索不自动消费 OCR 页。不能把旧缓存命中当作这版 PDF 已正确识别。

目标：Linux 当前页与选定页范围能本地识别，用户看得到页级进展，可暂停/取消/续做，重开不从头识别；识别完成的无文本层页能被书内/全局搜索并跳到正确页，之后可显式交给 AI。原 PDF 不改写，不生成隐形文字层 PDF。

不做默认整书自动 OCR、云端 OCR、手写/复杂表格/公式语义恢复、VLM、ONNX 模型下载或自动系统安装。整书仅可作为显式页范围 `1–N`，有范围/资源提示，不默认选中。

## 2. Linux 默认技术路线

### 2.1 引擎

实现 `LinuxTesseractOcrEngine`，使用本机 Tesseract 5.x CLI，`supportsPdfPageOcr=false`。语言包可由系统提供，首期推荐 `chi_sim`、`eng`，不打进主安装包。检查实际可执行路径、版本、`--list-langs` 及语言包；显示已安装/缺失语言，不静默把中文请求降成英文。

规格创建时，当前机器只探测到 `pdftoppm`、没有 `tesseract`。用户随后授权安装及实测，已在用户目录配置 Tesseract 5.5.4、中英语言包及输出配置；见 [引擎实测记录](../../eval/ocr-linux-2026-11-10.md)。外部依赖与 F6-A 应用接入是两组独立证据，后者见本轮接入验证。Poppler 不是本方案必需依赖，已有 `pdftoppm` 不能证明 OCR 可用。

已新增 `OcrCapabilitySource` / `OcrCapability` 返回 `available/engineMissing/languageMissing/unsupportedVersion/probeFailed`、engineVersion、语言清单和限制原因；已有 bool isAvailable 由它适配，保留平台 adapter 边界。F6-A 错误反馈提供安装或语言包原因，失败后可再次点击识别重探测；完整能力设置入口与范围任务界面仍待后续切片。无引擎时阅读正常，不创建空跑后台任务。

能力探测除版本/语言外，必须用受控小图实际请求并验证 TSV 表头。实测发现：只配置 traineddata、遗漏 `configs/tsv` 时，引擎可能退出 0 却输出普通文本；不得据版本、语言清单或退出码判定可用。这种情况返回 `probeFailed` 并给出输出配置缺失/协议无效原因，不保存原始 stderr。

进程参数示意（通过参数数组执行，不经 shell）：

```text
tesseract <private-page.png> stdout -l chi_sim+eng --oem 1 --psm 3 tsv
```

语言只能从探测出的白名单组合，路径单独作为参数，不拼接可执行脚本。stdin 不传用户正文；stdout TSV 仅在内存解析，最多 8 MiB；stderr 最多 64 KiB，仅生成脱敏错误摘要，原始内容不写常规日志。超限、非零退出、非法 TSV 分别报告错误。默认 `OMP_THREAD_LIMIT=2`，一次最多一个 OCR 子进程。

### 2.2 PDF 光栅化

实现 reader-independent 的 `NativePdfPageRasterizer`：复用当前 `pdf_document/pdf_graphics/dart_pdf_editor` 图形栈及已有 interpreter worker 思路，按需打开 PDF 并输出 PNG。可见页路径可复用 `PdfPageImageSource`，批处理不得依赖“该页 Widget 已挂载”或抢当前滚动位置。

- 使用 PDF 显示页的 CropBox/Rotate 结果，白底，无阅读主题滤镜/批注覆盖，避免深色模式影响识别。
- 默认 200 DPI、最长边 2,200 px，像素数最多 5,000,000；有效比例取 DPI 和尺寸限制的较小值，记录实际渲染签名。
- 可显式选择高质量 300 DPI/3,300 px/10,000,000 像素预设，提前提示耗时/内存增加。官方建议更高 DPI，本批以开发集比较两预设后冻结默认；不能仅因沿用 200 DPI 就宣称中文质量达标，也不按低 confidence 自动无限重识别。
- 解析/解释可复用 isolate worker；`dart:ui` 测量/绘制/编码按 Flutter 支持边界执行，不在普通 worker 调用不可用的 UI API。渲染服务在无当前阅读器时也可运行。
- 图像/字节/文档资源每页释放，不预渲染全部页。取消时不能即时终止的图像操作按 epoch 丢弃结果，并在完成后释放资源。
- 新 rasterizer 接口明确 maxEdge/maxPixels；同步更新测试 fake 和当前页消费者，不能原生路径限长边、批量路径却无限放大。

页面原生文字优先，按页判断 `nativeText.trim().isNotEmpty`，不能因为整本 hasText 就跳过混合 PDF 的扫描页。非空但乱码的文本首期不自动宣判无效；用户可显式 OCR 作辅助叠层，但默认不替换其原文搜索通道。

## 3. OCR 文本、几何和缓存

### 3.1 TSV 转换

解析 TSV 固定表头与数字范围，按 block/par/line/word 序输出；word 文本不能用简单空格 split 破坏。词框必须在实际图像范围内，轻微浮点误差可 clamp，明显越界的 word 行使该页进入 outputInvalid，不能静默丢字后标成功。

同一行的 CJK-CJK 邻接不额外插空格；闭合标点前、开合标点的内部边界不额外插空格；其他 Latin/数字词边界插入一个空格，行间换行、段间空行。规则固定为 `ocr-text-v1` 并逐例测试；生成正文的同时生成词/行的 UTF-16 `[start,end)`，不能之后靠搜索重复字符串恢复坐标。

保存 word/line 的纯文本及显示空间归一化框。`conf=-1` 为无有效置信度，不当 0%；页级 confidence 是有效词分数按字符数加权后的 `[0,1]` 统计，只用于诊断，不代表页面内容正确的概率。无有效词时为空结果，不保留伪 confidence。

`OcrTextBlock` 拟增可空 startOffset/endOffset 及 granularity(word/line)，新版 envelope 校验范围与正文一致；旧 block 没字段时保留粗框，不伪造精确区间。语言组合按请求顺序保留，不能排序：`chi_sim+eng` 与 `eng+chi_sim` 可能有不同输出，必须是不同签名。

### 3.2 缓存有效条件

cacheSignature 由 sourceRevision、engineId/version、所用语言包摘要、有序语言组合、DPI/maxEdge/maxPixels、PSM/OEM、renderVersion、ocrTextVersion 规范编码后 hash。缺任一必需值的旧缓存标 `legacyUnverified`。语言包文件只在能力/文件状态变化时重新算摘要，批量不逐页重复读取整套模型。

- 同签名可复用；不同 PDF 字节、语言包、识别参数/转换版本都需新识别。
- v12 在 `ocr_pages` 增加 `source_revision?`、`cache_signature?`、`text_revision?`、`engine_version?`、`pipeline_version?`、`result_state`、`index_state`；blocksJson 使用带版本 envelope，兼容旧 list。
- `result_state=recognized/empty/legacy`；`index_state=pending/indexed/failed/notApplicable`。空页是有效完成结果，缓存空结果避免每次重识别。
- 保留 book+page 唯一约束，存当前认可结果；强制重识别在成功完成并核实版本后才原子替换，失败不删旧行。旧行若签名不符不能当当前有效结果。
- 识别结果与搜索文本属于不同 durable checkpoint；入库成功不代表已可搜索。

AI 引用/导出的 OCR snapshot 保存当时文本与签名，不依赖唯一缓存行永远不变。

## 4. 页范围和任务交互

入口：当前页动作、PDF 更多操作的“识别页面…”，任务中心的 OCR 分类/状态；不长期悬浮覆盖正文。

范围支持当前页、连续 N–M、多段 `1–3,8,10–12`；去重排序后校验 1 ≤ page ≤ pageCount。最多 2,000 页/任务，超过提示分批，不静默截断。对话框显示页数、语言、已有原生文本/缓存可复用/待识别数量；无测量数据时不编造预计分钟数。

状态显示 `已处理 x/N；新识别 a；缓存复用 b；原生跳过 c；空页 d；失败 e；待索引 f`。百分比按终态页面数量计算，失败不能伪装成功；显示“正在识别第 k 页”是当前页，不是已完成数。

- 暂停：停止调度新页，取消当前可中止阶段，保留完成结果与未完成 checkpoint，可继续。
- 取消：当前任务终止，保留已成功结果与索引，未处理页记 cancelled；不自动续跑。再次执行创建新任务，缓存可复用，不从头消耗识别。
- 关闭应用/崩溃：重开标“上次中断，待继续”，不自动占满 CPU；由用户继续同一任务。
- 单页失败继续其他页，最后 partial；提供“重试失败页”，不重跑已成功页。
- 原 PDF 版本变化：任务暂停并标 sourceChanged，旧结果保留但不用于新版本；确认后新任务/新签名重建，不将剩余页悄悄应用于新书。

## 5. 持久任务与恢复算法

### 5.1 v12 结构与枚举

| 结构 | 字段 |
| --- | --- |
| `ocr_jobs` | id(UUID)、task_id UNIQUE、book_id、source_revision、config_json(version=1)、status、reason?、created_at、updated_at |
| `ocr_job_pages` | id(UUID)、job_id、page_number、status、attempt、ocr_page_id?、expected_cache_signature、error_code?、updated_at；UNIQUE(job_id,page_number) |

`OcrJobStatus=queued/running/paused/partial/done/failed/cancelled`；`OcrPageJobStatus=pending/rendering/recognizing/recognized/indexing/done/empty/skippedNative/failed/cancelled`。attempt 为非负递增重试次数，异步提交同时核对 attempt 与 jobEpoch。

新增 `PageSageTaskType.ocrPages('ocrPages')`；公共 `PageSageTaskStatus` 补 `paused/partial`，不把可继续任务伪装 queued/done。所有 task center switch、持久枚举、取消/恢复/清理、备份读取与测试替身必须同步；旧未知 type 不能被当作 importBook 执行重试。公共枚举未知值读取失败应成为明确 unsupported 状态/错误，不自动执行导入。

### 5.2 单页流程

```text
pending
  → 校验 book/source/config 与原生文字
    → skippedNative
    → 同签名缓存 recognized/empty
    → rendering → recognizing → recognized 或 empty
  → recognized → indexing → done
  → 任一失败 → failed（带阶段，其他页继续）
```

结果入库和页 checkpoint=recognized 同一事务；索引发布与 page=done/index_state=indexed 同一事务。空页不创建空 chunk，终态 empty。原生页不生成 OCR 正文 chunk，终态 skippedNative。入索引失败保持 recognized result，重试只走 indexing。

新 empty 结果若取代旧 OCR 正文，也要发布一个空 generation，事务撤下该页旧 OCR 命中，再标 empty/indexed；不能因“不创建 chunk”而遗留旧词。native variant 不受清空 OCR 影响。该空发布若失败，同样保留待索引 checkpoint。

调度器每次领取一页并持久化 attempt；全局 OCR worker=1，与当前页 OCR 共用 in-flight 去重/资源门，不开第二套无限队列。交互当前页请求可提升未开始页面优先级，不能打断正在提交的结果事务。关闭阅读器不必终止已明确启动的后台任务，但移除书籍必须先取消并等待写入屏障。

### 5.3 启动恢复

在应用任务层统一恢复，不能每次任务中心挂载就把本进程活跃任务标失败。复用现有 cancellation registry 的 live 检查；OCR 扩展按阶段恢复：

- rendering/recognizing → pending；recognized → 只补索引；indexing → 验证 active generation，已发布则 done，未发布则 recognized。
- 旧进程遗留 running job → paused(reason=interrupted)；本进程仍 live 的任务不改状态。
- done/empty/skippedNative 按 source/config 校验保留；签名失效必须新任务，不覆盖历史状态。
- journal/页数损坏 → failed，保留数据并提供重新创建任务；不猜范围、不自动整书 OCR。

每页完成前检查取消/sourceRevision/jobEpoch；落后进程返回不能在取消后新建有效结果。进程退出后未完成临时文件按专用目录前缀清理，不接触用户 PDF/Markdown 或其他 app 文件。

## 6. 搜索与 AI 接入

OCR 正文 unit 与该 PDF 页共用 documentSourceId，`textOrigin=ocr`、locator 为 PDF page+有效 block 矩形；新 OCR textRevision 含转换规则与结果文本。S0 中 generation 另记录 `text_origin(native/ocr)`，页 unit 只能有一个默认 active 正文变体。

- 有可用原生文本：默认 index native。显式 OCR 结果可供当前页辅助复制/叠层，不重复写默认正文通道。
- 原生无文字且 OCR 认可：按 `ocr-text-v1` 段落切父子块，原偏移来自构造时映射；发布到同一页 unit，双路中文/Latin FTS 一起更新。
- `rebuildIndex` 需要消费有效 OCR 缓存，不能重建 PDF 时删掉 OCR 命中，又要求用户重新识别。
- 搜索结果标“识别文本”，页号必须正确；有框则高亮相应块，没有框只跳页，精度 pageOnly，不伪装精确选词。
- AI 选择 OCR 引用时显示识别来源和可能有错字，版本/范围消费 F2。OCR 文本不是校对后的原文；不得给出“识别正确率 100%”标识。
- `Books.indexingStatus` 先保留原有枚举，正文覆盖率从页 unit/OCR 状态派生；不把部分页 done 当全书可搜，也不因一页失败让书籍不可读。

## 7. 取消、超时、安全和资源

识别每页 45 秒、光栅化 15 秒为初始超时；可在开发集调整并固化 config 版本，不静默无限重试。取消子进程先 terminate，1 秒后仍未退出则 kill，drain 有界输出并清临时文件。Process 启动 runInShell=false，绝不弹终端窗口。

页面临时图像放 app 专用私有临时目录，Linux 验证目录仅当前用户可访问；finally 删除，启动恢复只清专用遗留目录。结果正文最多 1 MiB/页、blocks 最多 20,000；超限是失败，不截断后标成功。

增量内存目标：app 额外 RSS ≤ 128 MiB、OCR 子进程 ≤ 512 MiB；为测量目标，不能声称 Dart 已提供硬 OS 限额。默认单 worker、像素限制、输出限制避免无限膨胀，超过目标作为性能缺陷修复。批量期间阅读/翻页继续可用，不在 UI 同步扫描整个 PDF。

该内存门槛用于冻结质量/性能语料（单 PDF ≤ 64 MiB），以打开同一本书但未开始 OCR 为基线。可见文档与 rasterizer 复用受控引用的文档服务，避免无意复制整份 PDF；更大输入单独报告原文载入与识别峰值，不把有限语料目标冒充任意 PDF 的硬内存上限。

错误码：`ocr_engine_missing/ocr_language_missing/ocr_unsupported_version/ocr_probe_failed/rasterize_failed/rasterize_timeout/ocr_timeout/ocr_output_invalid/ocr_output_too_large/source_changed/ocr_cancelled/ocr_index_failed`。空页是 empty 结果，不用统一 OCR 失败 toast 表示。

## 8. 迁移、导出、备份、删除

- v12 保留旧 `ocr_pages` 文本/框，标 legacy；本机重新核实 source/参数前不进入新默认索引。不能把缺版本缓存补上当前 hash 就宣布可信。
- blocksJson 新旧两种形式读取测试；新增定位字段透传到批注/笔记/导出。历史框无坐标版本信息时显示可读文本，重叠层需校验后才启用。
- 备份包含认可结果、任务与状态，不包含 PNG、子进程、语言包、绝对二进制路径；恢复后能力重探测，任务 paused，不自动启动。
- 删除书籍：停止 worker/取消 token，DB 事务删除 OCR job/pages/result/source/index/FTS，异步返回不得重建孤儿数据。只删除 PageSage 书库副本，不动用户原文件。
- “清除 OCR 结果”是独立破坏性动作，确认后删除 OCR 缓存及 OCR variant 索引；保留原生文字索引、用户笔记、AI snapshot 和原 PDF。
- 清理完成任务可删除 job/checkpoints，但不删除已认可 OCR 结果；paused 不算完成，partial 清理前提示其失败页将不能从旧任务重试。

## 9. 实施与验收

切片顺序：F6-A engine capability 与 Linux 当前页；F6-B 独立 rasterizer/方向/框；F6-C v12 与队列恢复；F6-D 搜索/重建/AI/删除闭环；F6-E 质量与性能。

| ID | 场景 | 必须结果 |
| --- | --- | --- |
| F6-01 | engine/语言缺失、错误版本、进程非零退出 | 具体能力原因；阅读不阻塞；不自动安装 |
| F6-02 | 中文/英文/混合扫描页和混合文本 PDF | 页级原生优先，扫描页可识别，错误不替换原文 |
| F6-03 | 90/180/270 度、CropBox、暗色阅读 | 图片与显示页一致，框不旋转两次、不错位 |
| F6-04 | 多段范围/重复/越界/2,001 页 | 明确验证，最多按合法范围执行，不静默截页 |
| F6-05 | 暂停、取消、崩溃、重启后继续 | 完成页不重识别，阶段恢复正确，无后台自动重跑 |
| F6-06 | OCR 成功后索引失败/发布中断 | recognized 可恢复，只重试索引不重识别 |
| F6-07 | 同页并发、语言顺序/模型包/源 PDF 变化 | 去重有有序签名，失效不串缓存、不写过期结果 |
| F6-08 | 搜索中文 OCR、重建索引、打开 AI 引用 | 来源/页号/版本可核对，重建不丢 OCR |
| F6-09 | 删除书籍、清 OCR、清任务、备份恢复 | 清理边界正确、无幽灵命中、无原文件修改 |
| F6-10 | 空白/乱码 TSV/超限/超时/取消后迟到 | 空白可缓存，错误不当成功，迟到结果不发布 |

拟新增 `test/core/ocr/linux_tesseract_ocr_engine_test.dart`、`test/renderers/pdf/native_pdf_page_rasterizer_test.dart`、`test/core/database/ocr_jobs_migration_test.dart`、`test/features/ocr/ocr_job_runner_test.dart`、`test/features/ocr/ocr_search_index_test.dart`；扩展现有当前页/协调器/任务中心测试。真实 Tesseract 用独立可用性标记，fake process 测试不能冒充引擎质量。

质量数据至少 30 页：清晰英文 10、清晰简中 10、中英/版式/旋转 5、退化/空白 5；逐页人工转写真值、单独冻结。清晰英文 CER ≤ 5%、清晰简中 CER ≤ 15%；CER 用 Unicode 字符编辑距离，先固定空白规范、保留数字/标点，分语种 micro/macro 同报。退化样本不承诺同等识别率，但错误/空白/性能行为必须通过。耗时报告中位数/P95、实际 DPI、CPU/RSS，不预先宣称“轻量/高准确率”。

## 10. 外部依据

引擎参数、语言和 TSV 字段参照 [Tesseract 官方 CLI 文档](https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html)；图像缩放、方向和分割影响参照 [官方质量建议](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html)。这里的缓存签名、调度和质量门槛是 PageSage 设计目标，须以本机真实数据验证。
