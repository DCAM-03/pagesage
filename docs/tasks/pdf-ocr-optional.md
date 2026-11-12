# TASK-26：扫描版 PDF 本地 OCR（可选 / 后置）

状态：Phase 0/1 已落地代码（2026-07-17）；2026-11-10 扩展 Linux 当前可见页；2026-11-11 完成 Linux 当前 OCR 页文本划词闭环
日期：2026-07-17
优先级：v1.0 不阻塞；当前页 OCR 已接入 Android/Windows 原生通道

## 目标

在 **用户主动触发** 的前提下，为无文本层（扫描版）PDF 提供本地 OCR，使页级文本可用于复制、AI 上下文，并在后续阶段写入 FTS 搜索索引。

## 来源与边界

- 来源：`docs/00-overview.md`、`docs/01-product-requirements.md`（长期目标含 OCR；首版非目标含扫描版 OCR）、`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`、`docs/tasks/pdf-reader.md`、`docs/tasks/global-search-and-indexing.md`。
- **当前不做**（与权威文档一致）：
  - 导入后默认整书自动 OCR。
  - 默认云端 OCR 或上传页面图像。
  - 有文本层 PDF 再强制 OCR。
  - 手写批注识别、复杂表格结构还原、VLM 重型 OCR。
  - 把 OCR 当作 M0–M4 阻塞项。
- 约束：
  - 本地优先；结果只存本机。
  - 文本层优先：`PdfTextExtractorService.hasText == true` 时走现有路径。
  - WebView / PDF.js 不写业务数据；OCR 结果由 Dart 落库。
  - 失败不影响阅读。

## 现状（实现基线）

- PDF 阅读：可打开扫描版；无原生文本层时初始禁用搜索/划词，识别出该页 OCR 几何后允许划词。
- 文本提取：`lib/core/search/pdf_text_extractor.dart` 只读 PDF 文本层。
- 索引：`SearchIndexer._indexPdf` 在 `!hasText` 时直接返回，不写入正文 chunk。
- 任务：`PageSageTaskType` 已有 import / index / backup 等，尚无 OCR 类型。

## 2026-11-11 增量：OCR 文本划词闭环

- 已有 OCR 几何的页面现在可点击选词、拖动跨行选择，并复用标准 `RendererTextSelected` 事件；复制、高亮、下划线、批注、摘录笔记和继续问 AI 不需要单独的 OCR 通道。
- OCR 块坐标本来就是相对显示页的 0..1 值，因此选择模型直接使用显示页坐标，不再经过 `PdfPageGeometry` 或 `/Rotate` 二次投影。
- 选区按 OCR 行输出归一化矩形，可持久化为普通批注；重绘时 OCR 行块同时作为标注行带，避免保存后的高亮被原生文本行带错误裁剪。
- 选区文本按行拼接，摘录仍经 `pdfSelectionText` 折叠空白。跨页选择只会在有文本层或已有 OCR 几何的页面产生内容；未识别的扫描页不会被伪造为可选中文本。
- renderer 的原生搜索能力仍按原生文本层上报；OCR 搜索复用已落库文字的 FTS 路径，
  不依赖画布选择层，也不据此声称尚未识别的页面可搜索。
- OCR 覆盖页现在上报 `textSelection=true`、`ocrTextLayer=true`；无 OCR 的扫描页仍上报不可划词及原因。
- 验证：新增 OCR 选择模型 13 项测试、PDF 画布 46 项回归、选择/标注契约 64 项、阅读器选区动作与 OCR 覆盖层 23 项，全部通过；全仓 1001 项通过、6 项按环境跳过；`flutter analyze` 无问题，`git diff --check` 无输出。
- Linux release 已静默重建安装，完整 bundle 与安装目录一致，`libapp.so` SHA-256 为 `1f6c8e37cd8eb95538a60c543dc63ce4fd2bb086deeb01ecdc230ee41eb75f96`。安装时没有运行中的 PageSage 实例，未启动新窗口；真实窗口和 Windows/Android 验收仍未执行。

## 产品策略

2026-11-11 窗口增量：真实 Tesseract 三页扫描样本完成选区动作、关闭重开、
双页两侧与翻回、AI 侧栏重排后的手柄坐标验证；修复页缓存、结果队列、重复绘字、
能力上报及指针焦点问题。完整日志、失败历史与验证边界见
[Linux 窗口验收记录](linux-window-acceptance-2026-11-11.md)。

| 该做 | 不该做 |
| --- | --- |
| 仅扫描/无文本层 PDF | 有文本层再 OCR 一遍 |
| 用户主动触发 | 导入后默认整书 OCR |
| 当前页 / 选页范围优先 | 一上来强制整书 |
| 结果只存本地 | 默认上传云 OCR |
| 失败不影响阅读 | OCR 失败导致无法打开书 |
| 进度可取消、可重试 | 阻塞 UI 同步跑几百页 |

推荐默认交互：

```text
打开扫描 PDF
  → 可阅读
  → 搜索/划词禁用，提示「无文本层」
  → 提供：
      [识别本页]           ← 默认主按钮
      [识别第 N–M 页…]     ← 次要
      [识别整本书…]        ← 二次确认 + 预估时间
```

隐私文案建议：

> 文本识别在本地完成，不会上传书籍页面。

若未来增加云引擎，必须单独开关并明确上传范围。

## 分阶段交付

### Phase 0 — 零 OCR 体验补丁（可与主线并行）

- 强化无文本层文案与禁用原因。
- 索引对无文本层标记为可理解状态（避免长期 `failed` 误解）。
- 成本低，不引入引擎。

### Phase 1 — 当前页 OCR（最高 ROI）

目标：本页可复制、可问 AI。

```text
用户点「识别本页」
  → 渲出当前页图（约 200–300 DPI）
  → OcrEngine.recognize(image, lang)
  → 得到纯文本（bbox 可先不存）
  → 页级缓存 / 临时结果
  → 「本页文本」面板：复制 / 问 AI
  → 不强制进全局搜索
```

### Phase 2 — 范围 OCR + 搜索索引

目标：选页 OCR 后书内/全局搜索可命中并跳页。

```text
用户选页范围
  → TaskQueue 排队 ocrPages
  → 逐页 rasterize → preprocess → OCR → 落库
  → 进度展示，可取消
  → SearchIndexer 增量写入 OCR 页
  → 启用已识别页的搜索
```

### Phase 3 — 精确定位（后置）

- 保存行/块 bbox。
- 搜索命中高亮、划词坐标映射。
- 不与 Phase 1/2 绑死。

### Phase 4 — 引擎升级（按需）

- 中文/扫描质量不足时，按需下载 Paddle/RapidOCR 等 ONNX 轻量模型。
- 仍实现同一 `OcrEngine` 接口；模型不打进默认安装包。

## 架构

```text
Presentation
  Reader 无文本层横幅 / OCR 入口
  Task Center 进度

Application
  OcrUseCase
    - 创建任务、页范围校验
    - 驱动引擎 + 落库 + 触发索引增量

Domain
  OcrRequest / OcrPageResult / OcrEngine 接口

Data
  ocr_pages 表（推荐）或 search_chunks 带 ocr 标记
  TaskRepository 扩展 type: ocrPages

Platform
  AndroidOcrEngine  (ML Kit)
  WindowsOcrEngine  (WinRT)
  （预留）OnnxOcrEngine

Renderer / Files
  PdfPageRasterizer：PDF 页 → 位图
  不在 bridge.js 内直接 OCR
```

依赖方向：

```text
UI → OcrUseCase → OcrEngine / PdfPageRasterizer / OcrResultStore / SearchRepository
```

### 引擎选型

| 阶段 | 引擎 | 说明 |
| --- | --- | --- |
| 第一版 | 平台原生：Android ML Kit、Windows WinRT | 轻量、离线、双端可落地 |
| 第二版可选 | RapidOCR / Paddle 轻量 ONNX | 中文与复杂扫描更强；按需下载 |
| 不推荐默认 | 云 OCR、重型 VLM、默认打满多语言 Tesseract 包 | 隐私或体积/成本不匹配 |

接口草图：

```dart
abstract interface class OcrEngine {
  Future<bool> isAvailable();
  Future<List<String>> supportedLanguages();
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
  });
}
```

### 与现有模块衔接

1. **文本层优先**  
   `SearchIndexer._indexPdf`：先 `PdfTextExtractorService`；有文本走现路径；无文本再读 `ocr_pages`。

2. **任务系统**  
   扩展 `PageSageTaskType.ocrPages`；复用 `TaskQueue` 与 `TaskCancelToken`。

3. **搜索**  
   OCR 切块可复用现有 PDF 切块逻辑：  
   - `sourceId`: `${bookId}:ocr:${page}:$i`  
   - `locator`: `ReadingLocator.pdf(page: ...)`  
   - `sortOrder`: `page * 10000 + i`

4. **AI**  
   `ContextBuilder`：无选区时可用本页 OCR 文本，上下文说明含页码与「OCR」来源。

## 数据模型建议

推荐独立表，便于重跑与清理：

```text
ocr_pages
  id            TEXT PK
  book_id       TEXT
  page_number   INT
  text          TEXT
  language      TEXT
  engine        TEXT      -- mlkit / winrt / onnx
  confidence    REAL?     -- 可选
  created_at    INT
  UNIQUE(book_id, page_number)
```

books 可选字段：

```text
text_source: native | ocr | mixed | none
ocr_status:  none | partial | complete | failed
```

删除书籍时必须级联删除 OCR 数据。Schema 变更走 Drift migration，禁止清库捷径。

## 实现任务（待启动时勾选）

### Phase 0

- [x] 无文本层 UI 文案与禁用原因统一。
- [x] 索引状态对「无可索引正文」语义清晰（`indexingStatus=no_text`）。

### Phase 1

- [x] 定义 `OcrEngine` / `OcrPageResult` domain 接口。
- [x] 实现 `PdfPageRasterizer`（平台 MethodChannel：Android PdfRenderer / Windows WinRT PDF）。
- [x] Android ML Kit 实现（`pagesage/ocr` + `pagesage/pdf_raster`）。
- [x] Windows WinRT 实现（`windows/runner/pagesage_native_channels.cpp`）。
- [x] Reader「识别本页」入口与结果面板（复制 / 问 AI）。
- [x] 取消与错误提示（generation + TaskCancelToken；会话缓存）。
- [x] 单元测试：use case + fake engine；双端真实扫描样本手测仍待人工。
- [x] 性能热路径（2026-07-17）：
  - 原生一站式 `recognizePdfPage`（无 PNG 跨桥往返）
  - PDF 文档句柄缓存 / OCR 引擎复用
  - 默认 DPI 200、maxEdge 2200；会话 LRU + 并发去重
  - `isAvailable` 结果缓存

### P0 性能采样（2026-11-10）

先只加 Timeline 埋点，不改变默认识别路径。DevTools 中按 `ocr.` 前缀查看：

- `ocr.page`：单页总耗时
- `ocr.cache.memory` / `ocr.cache.disk`：缓存命中与磁盘读取
- `ocr.export.renderer`：显示页导出
- `ocr.engine.image` / `ocr.engine.nativePdfPage`：两条识别路径
- `ocr.engine.available`：引擎可用性检查
- `ocr.rasterize`：无原生 PDF OCR 时的栅格化
- `ocr.persist`：OCR 结果落库

采样矩阵：中文密排、英文、小字号、表格、旋转页各至少 2 页；单页与双页各测一次。
分别比较显示页导出路径和原生直接渲染路径，并用 `1400/1600/1800/2200` 最长边测试。
记录总耗时、各阶段耗时、输入图片尺寸/字节数、失败或空结果。

对比开关只在性能采样时使用，默认关闭：

```bash
# 默认：显示页 PNG 路径
flutter run --profile -d <device>

# 原生直接渲染路径；dpi/maxEdge 可按样本调整
flutter run --profile -d <device> \
  --dart-define=PAGESAGE_OCR_NATIVE_FAST_PATH=true \
  --dart-define=PAGESAGE_OCR_DPI=200 \
  --dart-define=PAGESAGE_OCR_MAX_EDGE=1600
```

Android 用真机或模拟器均可，但两种路径必须在同一设备、同一 PDF、同一页面上比较。
Windows 用 `-d windows`，并先确认系统已安装中文 OCR 语言包。Linux 当前仍是
`StubOcrEngine`，不能作为 OCR 性能样本。

决策门槛：只有原生直接渲染在样本上稳定减少总耗时，且 OCR 坐标与当前页面几何一致，
才把它改为默认路径；否则保留显示页导出，优先做自适应分辨率和缓存版本化。

### Phase 2

- [x] `ocr_pages` 表与 migration（schemaVersion 3；文本 + blocks JSON 本地落库）。
- [x] 识别结果会话缓存 + 磁盘缓存；翻回已识别页自动恢复叠加，无需再识别。
- [x] 删书时级联清理 `ocr_pages`。
- [ ] `PageSageTaskType.ocrPages` + 任务中心进度。
- [ ] 选页范围 OCR。
- [ ] `SearchIndexer` 增量索引 OCR 页。
- [ ] 书内/全局搜索跳页。
- [ ] 部分完成后可继续（任务队列语义）。

### Phase 3+

- [x] 当前页 / 可见页 bbox 叠加（display-space export + 词级框；样式持续打磨）。
- [x] 当前 OCR 页文本划词：点击选词、拖动跨行、复制/高亮/批注/笔记/AI 复用标准选区事件。
- [ ] 可选 ONNX 引擎与按需模型下载。
- [ ] 设置项：引擎、语言、清除 OCR 缓存。

## 建议模块路径

```text
lib/
  domain/ocr/
    ocr_models.dart
    ocr_engine.dart
  features/ocr/application/
    ocr_use_case.dart
    ocr_providers.dart
  core/ocr/
    pdf_page_rasterizer.dart
    ocr_result_store.dart
  platform/ocr/
    android_mlkit_ocr_engine.dart
    windows_winrt_ocr_engine.dart
    stub_ocr_engine.dart
```

## UI 与交互

- 阅读器：非打断式横幅；主 CTA「识别本页」；次要「识别更多页」。
- 任务中心：`OCR《书名》 12/40`；失败可重试；与 import 任务分离。
- 有文本层：不展示 OCR 主入口，或灰掉并说明已有文本。
- 设置（可选）：引擎、默认语言、清除缓存。

## 验收标准

### Phase 1

- [ ] 有文本层 PDF：不误走 OCR 主路径。
- [ ] 无文本层：识别本页得到可读文本；可复制；可基于本页问 AI 且上下文含页码。
- [x] Linux 当前 OCR 页：识别文本可点击选词、拖动跨行，并进入现有复制/标注/笔记/AI 动作。
- [ ] 识别中可取消；失败有明确错误。
- [ ] Android + Windows 各至少 1 份真实扫描样本通过。

### Phase 2

- [ ] 选页 OCR 进任务中心，进度正确。
- [ ] 完成后书内/全局搜索可命中并跳到对应页。
- [ ] 重复 OCR 幂等；删书清理 OCR 数据。
- [ ] 约 100 页扫描书不 ANR/OOM（可慢，必须可取消）。

### 样本建议

- 清晰印刷扫描。
- 轻微倾斜手机拍页。
- 中英混排。
- 双栏论文（允许质量下降，不可崩溃）。
- 有文本层 PDF（回归：仍走原路径）。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 引擎相关：fake engine 单测 + 真机/真机 Windows 手测。
- 不在 CI 默认依赖大模型下载或云 OCR。

## 依赖与风险

| 风险 | 缓解 |
| --- | --- |
| 双端引擎质量不一致 | 统一接口；中文可后续 ONNX |
| 包体膨胀 | 原生引擎优先；ONNX 按需下载 |
| 大书 OOM/耗电 | 串行或低并发；可取消；默认非整书 |
| 定位精度不足 | Phase 1/2 只保证到页；bbox 后置 |
| 与「首版不做 OCR」冲突 | 本 task 明确为 post-v1.0 可选 |

## 决策摘要（2026-07-16）

1. **值得做，但不值得现在做**：扫描 PDF 对论文/资料画像价值高，但工程与质量成本大，不阻塞 M0–M4。
2. **上线路径**：Phase 1 当前页 → Phase 2 选页+索引；不要从整书自动 OCR 或坐标叠加起步。
3. **引擎**：先平台原生，接口预留 ONNX。
4. **产品口径**：用户触发、范围明确、本地存储、文本层优先。

## 相关文档

- `docs/tasks/pdf-reader.md`（文本层缺失提示，明确不做 OCR）
- `docs/tasks/global-search-and-indexing.md`（PDF 文本层索引边界）
- `docs/01-product-requirements.md`（首版非目标 / 长期 OCR）
- `docs/implementation-status.md`（明确不做含 OCR）

## 2026-11-10：Linux 当前可见页接入（F6-A）

本节为后续实现增量，前文 PDF.js、双端优先及后置策略保留其历史语境；本轮以 Linux 画布阅读器为验证入口，完整范围见 [F6 规格](../specs/linux-reader-six-features-2026-11-10/06-ocr-search-and-jobs.md)。

- 新增 `LinuxTesseractOcrEngine`、串行进程执行器、严格 TSV 解析与可选能力契约。发现引擎并实际识别受控小图后才报告可用；缺语言不自动换成英文，PSM 3/OEM 1、线程上限 2，单页识别超时 45 秒。
- 当前阅读页导出白底 PNG，限制长边与像素；TSV 按阅读序合并为连续行框，保存归一化显示坐标和语言。复用原有当前页 controller、缓存、叠层及结果面板，不引入第二套 PDF 阅读器。
- 取消信号透传 Linux 子进程；先 terminate，超时再 kill，进程退出后不再发终止信号。阅读器解除订阅会释放当前页任务；迟到结果不回填旧页面。Android/Windows 仅保持新参数的编译兼容，本轮未验证其原生取消能力。
- 发现本机 Dart 临时目录默认权限为 `0755`，修正为写页面前先设置并验证 `0700`；完成、错误或取消后清理临时图像。限制 stdout 8 MiB、stderr 64 KiB，诊断原文不入常规日志。
- 未新增包或迁移。旧缓存仍缺来源/模型/参数签名，显式语言请求绕过旧缓存；空白页在引擎层是有效空结果，但应用持久缓存仍按旧行为处理，待后续阶段补齐。

验证包括受控进程错误/超时/取消、协议与几何边界、阅读器订阅生命周期、PDF 显示页导出，以及真实中英合成页识别与临时 SQLite 文件关闭重开。准确计数、日志、安装产物核对及未验证边界见 [本轮接入验证](../eval/ocr-linux-current-page-2026-11-10.md)；旧外部引擎评测不能作为应用接入证据。

独立 PDF rasterizer、版本化缓存、选页与持久任务、OCR 入 FTS、真实窗口及完整质量/性能语料尚未交付，不将当前页接入标为完整 Phase 2 或完整 F6。

## 2026-11-11：F6-B 至 F6-D 接入

- 独立 `NativePdfPageRasterizer` 已接入 Linux，支持无活动阅读器时按页渲染，并保留显示页导出优先路径。
- `ocr_pages` 已增加来源、缓存、文本与索引状态字段；缓存签名覆盖来源版本、引擎/版本、语言、渲染预算与文本管线。旧未签名缓存只供阅读叠层，不进入搜索；空结果可持久化为 `empty` 并复用。
- 持久 OCR 任务已接入显式页码范围、页级 checkpoint、暂停/取消/继续、崩溃恢复、原生文字页跳过、签名缓存复用和失败页继续。任务中心可观察进度并操作暂停/继续。
- 搜索索引只消费已签名 OCR 页；原生文字页优先，OCR chunk 带 `textOrigin=ocr`，搜索结果标“识别文本”并使用 `pageOnly` 定位。删书会清理 OCR job、page checkpoint 与 OCR 缓存。
- 新增真实 Drift 任务与搜索链路测试；OCR/搜索/任务中心/阅读器定向回归 193 项通过；全仓 954 项通过、5 项跳过；`flutter analyze` 无问题。Linux 安装版已静默更新且 bundle 一致。
- 任务中心已补“重试失败页”和“清除 OCR 结果”；清除会删除关联页文本、任务 checkpoint、会话缓存并重建搜索索引，不碰 PDF、原生文字或笔记。
- OCR 范围任务已接入进程内 FIFO 单 worker：多个任务可入队，但按提交顺序逐个执行；排队任务可暂停/取消，不会在恢复检查中被误判为中断。该约束不包含当前页交互式 OCR。
- 仍未完成：30 页冻结 CER/RSS/耗时门槛、真实窗口验收和备份恢复边界。不能据此声明完整 F6-E 或最终 F6 验收通过。
