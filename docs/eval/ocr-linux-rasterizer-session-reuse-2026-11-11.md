# Linux OCR 光栅会话复用验证

日期：2026-11-11

## 目的

验证整本 OCR 时，原生 PDF 光栅器逐页重读整份 PDF、反复创建和销毁渲染 worker 是否产生明显开销。OCR 引擎、语言、渲染预算和页序保持不变，只比较复用会话前后的生产光栅器与 Tesseract 链路。

## 样本与环境

- PDF：`<HOME>/下载/匿名数学扫描样本.pdf`，184 页，90,845,801 字节
- SHA-256：`9885d3b6e67512dec686b03425be2a506c85e1aa61152b422a412a1470042263`
- 固定页码：7, 20, 29, 38, 47, 51, 52, 54, 55, 56, 57, 58, 59, 60, 61, 63, 64, 65, 66, 67, 68, 69, 70, 72, 73, 74, 75, 76, 77, 78, 79, 81, 82, 83, 84, 85, 86, 87, 88, 90, 91, 92, 93, 94, 95, 96, 97, 99, 100, 104
- 此页码集是沿用的固定样本，不是均匀随机抽样；不能据此声称代表全书或所有 PDF。
- Linux、Flutter 测试进程、Tesseract 5.5.4；OCR 使用应用当前 `zh-Hans` 语言解析及生产默认渲染预算。
- 基准测试：`test/core/ocr/linux_pdf_pipeline_perf_test.dart`。逐页测原生光栅和 OCR 时间、文本/几何非空状态，并采样测试 Dart 进程的 RSS。

## 前后对比

| 指标 | 每页重建会话 | 复用 PDF 会话 | 变化 |
| --- | ---: | ---: | ---: |
| 光栅化均值 | 424.34 ms | 271.28 ms | 下降 36.1% |
| 光栅化中位数 | 416.5 ms | 258 ms | 下降 38.0% |
| 光栅化 P95 | 475 ms | 318 ms | 下降 33.1% |
| OCR 中位数 | 1601 ms | 1597 ms | 基本不变 |
| 测试进程峰值 RSS 增量 | 851.62 MiB | 680.70 MiB | 下降 20.1% |
| 有文本且含几何的页面 | 50/50 | 50/50 | 一致 |

光栅时间与进程 RSS 是此 Flutter 测试链路的测量，不等于桌面整应用的增量内存。RSS 采样不包含 Tesseract 子进程的 RSS，也未从“同一 PDF 已在阅读器打开”的应用基线相减。上表不能用作产品内存目标是否通过的判定。两次结果都处在测试进程和 Tesseract 同机运行条件下。

测试输出中的 `displayWidthPoints` / `displayHeightPoints` 是 PDF 显示尺寸（点），不是编码 PNG 像素尺寸；PNG 字节数独立记录。当前评测未解码 PNG 头部测像素分辨率。

## 实现

- `NativePdfPageRasterizer` 按绝对路径、文件长度和修改时间复用当前 PDF 的 renderer/worker。
- 文件变化或切书时销毁旧 worker，再加载新文件，避免同时保留两本书的会话。
- provider 销毁时显式释放 renderer worker。
- 页面范围错误发生在 renderer 初始化之后时不再访问未初始化的 `late` renderer，也不会关闭正常复用会话。

## 验证

- `native_pdf_page_rasterizer_test.dart`：重复光栅同页、触发越界页错误、随后继续成功。
- `linux_pdf_pipeline_perf_test.dart`：相同 50 页全部返回文本和几何；复用前后 OCR 中位耗时近似。
- OCR 调用链回归：`ocr_current_page_use_case_test.dart`、`ocr_job_controller_test.dart`、`linux_tesseract_ocr_engine_test.dart` 与光栅器用例，共 42 项通过。
- `flutter analyze`：通过。
- 本次仍未对正在运行的完整 PageSage 桌面应用测 RSS，未验证扫描 PDF 的识别准确率，也未覆盖 184 页整本端到端入队、持久化和搜索索引总耗时。
