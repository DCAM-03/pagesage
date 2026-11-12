# Linux 当前可见页 OCR 接入验证

日期：2026-11-10。对应 [F6-A](../specs/linux-reader-six-features-2026-11-10/06-ocr-search-and-jobs.md)，本轮仅交付 Linux 引擎与当前可见页，不代表六项功能或完整 OCR 任务/搜索已验收。

## 1. 实际接线

```text
阅读器当前可见页
  → PdfCanvasRenderer 导出白底 PNG（显示方向、裁剪空间）
  → OcrPageController / OcrCurrentPageUseCase
  → LinuxTesseractOcrEngine（本机 Tesseract 5.5.4）
  → 严格 TSV → 正文与归一化行框
  → 现有内存/Drift 页缓存、叠层、复制与 AI 交接
```

- Linux provider 已从 stub 切到真实图像引擎；独立 `PdfPageRasterizer` 仍为 stub。没有可用可见页导出时，Linux 尚不能靠独立 rasterizer 补救。
- 版本、语言清单及受控小图实际 TSV 协议共同决定可用性，成功探测缓存一分钟，失败允许下次重新检测；不因退出码为 0 就报告可用。
- 保留语言组合顺序，缺中英模型有明确原因，不自动用英文替代中文请求；默认 `--oem 1 --psm 3`。
- 单引擎串行进程、`OMP_THREAD_LIMIT=2`、单页识别 45 秒；stdout 8 MiB、stderr 64 KiB 上限，解析结果 1 MiB / 20,000 词上限。未给出操作系统硬内存上限。
- 可见页 PNG 最长边 2,200 px、最多 5,000,000 像素，不透明白底；引擎边界还拒绝超过 3,300 px / 10,000,000 像素或 32 MiB 的输入。
- 页面写入前强制核对临时目录 `0700`，异常/取消/正常退出均清理图像。不保存原始 stderr 或用户页面日志。
- 取消 Linux 进程先 terminate，1 秒后仍未退出则 kill；输出管道 drain 有界，退出后的进程不再接收终止信号。阅读器解除订阅会取消当前页工作，旧请求不回填旧页面。
- 未新增依赖、未改 schema。`OcrEngine.recognize` 的取消信号为可选参数；Android/Windows adapter 仅保持接口兼容，未因此获得经验证的原生进程取消能力。

## 2. 最终自动验证

证据目录：`build/ocr-linux-current-page-2026-11-10/`。工作区本来已有其他未提交变更，本轮保留；候选生产文件 hash 记录于 `source-manifest.sha256`。本轮只格式化相关 Dart 文件。

| 项目 | 实际结果 | 证据 |
| --- | --- | --- |
| 定向回归与真实引擎 smoke | 220 项通过，包含 3 项真实引擎测试 | `final-regression.log` |
| 全仓静态分析 | `No issues found` | `final-analyze.log` |
| Dart 格式 | 相关文件格式化完成 | `final-format.log` |
| 构建/安装、完整 bundle 与产物 hash | release 构建安装成功，全 bundle 对比一致 | `install.log`、`install-bundle-diff.log`、`install-sha256.log` |

定向测试覆盖：

- `test/core/ocr/tesseract_process_test.dart`：无 shell 参数、线程限制、输出超限、非零退出、启动/流错误、串行排队、取消、terminate 无响应后的 kill、退出后 drain。
- `test/core/ocr/tesseract_tsv_test.dart`：固定协议、数字/层级/重复 word/范围错误、中文与标点拼接、阅读顺序、连续行框、置信度与大小限制。
- `test/core/ocr/linux_tesseract_ocr_engine_test.dart`：provider 接线、受控能力探测、缺引擎/模型/版本、TSV 配置缺失、语言参数注入、非法 PNG、超时取消与私有文件清理。进程为 fake，仅用于这些契约反例。
- `test/features/ocr/ocr_current_page_use_case_test.dart`、`ocr_page_controller_test.dart`：缓存、显式语言、并发去重、取消旧 owner、不存迟到结果、controller 与阅读器协调器订阅释放。
- 现有阅读器协调器/叠层/provider/面板、任务中心 controller、导入用例、搜索索引器、PDF 画布契约/视图/选区及应用 widget 命名回归。

真实引擎复现时，在常规测试命令前设置以下环境变量；不设置时 smoke 测试会跳过，不能据常规测试通过宣称实际 OCR 可用：

```bash
PAGESAGE_OCR_SMOKE_IMAGE=build/ocr-linux-current-page-2026-11-10/english.png \
PAGESAGE_OCR_SMOKE_CHINESE_IMAGE=build/ocr-linux-current-page-2026-11-10/chinese.png \
PAGESAGE_OCR_SMOKE_PDF=build/ocr-linux-current-page-2026-11-10/synthetic-scan.pdf \
flutter test test/core/ocr/linux_tesseract_smoke_test.dart --concurrency=4 --reporter expanded
```

## 3. 三项真实 OCR 证据

全部使用自有合成文本，不读取用户书库，也不把旧外部引擎基准的 116 次测量计入应用接入验证。

1. 英文 PNG（1,200 × 1,600）→ 实际 Linux provider/controller → Tesseract：识别出预期英文片段，几何全部位于归一化页面内；结果写入临时文件 SQLite，关闭数据库重开，正文、语言、图像尺寸与行框完全一致。
2. 中文 PNG（1,200 × 1,600）→ 真实引擎：`zh-Hans` 对应 `chi_sim+eng`，断言识别出预期中文片段及行框。
3. 无文字层扫描 PDF → 实际 `PdfCanvasRenderer.exportPageImage` → 当前页 controller/Tesseract：先断言没有原生文本层，再断言英文片段及行框；导出图为 1,600 × 2,133，文件为 `pdf-export.png`，已查看导出图。

这些断言证明生产链路能运行及缓存能重开，不代表字字正确、30 页语料 CER 达标、实际窗口选区已人工验收或任意复杂版式可用。

## 4. 发现并修正的问题

- 第一轮扩展测试出现 8 个引擎测试失败：本机 Dart `createTemp` 实际为 `0755`，私有目录检查正确拒绝。已改为写图前通过有界参数数组调用 `chmod 0700` 并再次核对；之后 11 项引擎测试以及最终回归通过。原失败记录保留于 `focused-tests.log`，不计为通过证据。
- 当前页 provider 原先常驻，单纯注册 `ref.onDispose` 不能证明退出阅读器会取消。已将 controller/协调器改为随订阅释放，并由阅读页固定订阅；测试在释放协调器订阅后验证取消信号到达且迟到结果不入库。
- 进程退出、但输出管道尚未关闭时，取消定时器不应再向该进程发送信号。已在 exitCode 到达时解除进程引用并取消 kill 定时器，增加针对 drain 阶段的测试。
- 初次采用有原生文字的合成 PDF 做 headless OCR smoke 时返回空结果，原因未证实，诊断保留 `pdf-smoke-diagnostic.log`；最终以真正无文字层的合成扫描 PDF 验证目标链路。不把失败样本或未证实的字体原因当作已通过结论。
- 静态分析发现的一处 if 大括号和两处跨 await 的 context 存活检查已修正，最终分析无问题。

## 5. 安装核对

执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，退出码 0。安装目录为 `<HOME>/.local/opt/pagesage`。

- `diff -qr build/linux/x64/release/bundle "$HOME/.local/opt/pagesage"` 退出码 0，完整 bundle 无差异。
- 构建与安装 `pagesage` 的 SHA-256 均为 `ad58a1c45c52438faa74c546cb558e75bad856e7aac4c3ac2eb459f639a47210`。此壳程序 hash 可能与历史版本相同，不能单独证明 Dart 应用代码已更新。
- 构建与安装 `lib/libapp.so` 的 SHA-256 均为 `85fca0a0d861c59ad8b806d9de5ac1b3281795130d52552af54dc9b005e8d31a`。
- 安装前后 `pgrep -x pagesage` 均无运行实例，记录于 `pids-before.txt` / `pids-after.txt`；未启动窗口，也未关闭或重启应用。

## 6. 剩余边界

- F6-B：独立 PDF rasterizer，真实旋转 90/180/270 度、CropBox、暗色显示及复杂书籍的导出/框对齐。当前已有组件级旋转导出尺寸与白底测试，不能冒充完整语料验收。
- F6-C：版本化缓存、blank/legacy 状态、词/行 UTF-16 偏移、崩溃遗留目录回收、持久页范围任务与恢复。显式语言请求目前绕过旧缓存；默认请求仍使用未签名的 book/page 缓存。
- F6-D：OCR 正文进入书内/全局 FTS、重建与来源版本、删除/备份/AI 快照闭环。
- F6-E：冻结 30 页真实质量语料与 CER、耗时/RSS 门槛；本轮没有测量应用集成后的峰值内存。
- 未启动真实应用窗口，未手工操作用户书籍的划词、复制/AI，未验证 Windows/Android。
