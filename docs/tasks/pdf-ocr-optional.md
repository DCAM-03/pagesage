# TASK-26：扫描版 PDF 本地 OCR（可选 / 后置）

状态：规划中，**不进入当前 v1.0 实现范围**  
日期：2026-07-16  
优先级：v1.0 之后 / 用户反馈驱动  

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

- PDF 阅读：PDF.js + WebView，可打开扫描版，无文本层时禁用搜索/划词。
- 文本提取：`lib/core/search/pdf_text_extractor.dart` 只读 PDF 文本层。
- 索引：`SearchIndexer._indexPdf` 在 `!hasText` 时直接返回，不写入正文 chunk。
- 任务：`PageSageTaskType` 已有 import / index / backup 等，尚无 OCR 类型。

## 产品策略

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

- [ ] 无文本层 UI 文案与禁用原因统一。
- [ ] 索引状态对「无可索引正文」语义清晰。

### Phase 1

- [ ] 定义 `OcrEngine` / `OcrPageResult` domain 接口。
- [ ] 实现 `PdfPageRasterizer`（优先 Dart 侧 PDF 渲染，后台任务友好）。
- [ ] Android ML Kit 实现。
- [ ] Windows WinRT 实现。
- [ ] Reader「识别本页」入口与结果面板（复制 / 问 AI）。
- [ ] 取消与错误提示。
- [ ] 单元测试：use case + fake engine；双端各至少 1 份扫描样本手测。

### Phase 2

- [ ] `ocr_pages` 表与 migration。
- [ ] `PageSageTaskType.ocrPages` + 任务中心进度。
- [ ] 选页范围 OCR。
- [ ] `SearchIndexer` 增量索引 OCR 页。
- [ ] 书内/全局搜索跳页。
- [ ] 幂等覆盖、删书清理、部分完成后可继续。

### Phase 3+

- [ ] bbox 与高亮定位。
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
