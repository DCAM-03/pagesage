# PDF OCR 搜索入口与能力状态修复

日期：2026-11-12
状态：修复、定向回归及本地安装完成

## 问题与范围

扫描 PDF 已识别并加入本地索引后，顶部搜索被拦截，工具条仍显示
“搜索不可用”；从 AI 上下文侧栏切到搜索却能检索。
阅读器将 renderer 的原生文本搜索能力误用于整个应用的索引搜索入口，
但书内搜索实际通过 SearchRepository 查询 SQLite 索引，包含已入库 OCR 文本。

统一桌面按钮、Ctrl+F、移动底栏和更多菜单的入口行为。原生文本层缺失
仅影响原生划词与原生搜索高亮，不阻止索引搜索；保留需要识别文字的提示，
已有 OCR 叠层时不再显示“搜索不可用”。不增加持久状态、依赖或数据库迁移。

## 验证计划

- `test/features/reader/reader_ocr_search_entry_test.dart`：临时真实 SQLite、
  真实 image-only.pdf 索引与签名 OCR 缓存，测试真实 ReaderPage 的按钮、
  快捷键、移动入口和状态提示。renderer 以事件替身控制原生能力，
  校验 OCR 结果和跳转的页码，不声称真实窗口或原书验收。
- 验证进入已有 OCR 索引的阅读会话、无几何 OCR 和尚未识别后新增 OCR；原生能力仍为 false
  不得重新阻断索引搜索。
- 受影响阅读器、PDF 渲染和 OCR 搜索链路回归；静态分析与格式检查。
- 静默构建安装 Linux 并比对产物；不打开或重启可见窗口。

证据目录：`.local-data/validation/ocr-search-entry-2026-11-12/`。

## 结果

- 修复前 7 项用例均失败，复现搜索面板无法打开和“搜索不可用”误提示，
  见 `before-final.log`。首次基线的移动端 MediaQuery 夹具不完整，
  已纠正后重新取得上述基线，保留首次 `before.log`，不用其布局异常判断产品。
- 修复后新增 7 项用例全部通过，见 `entry.log`；桌面按钮、Ctrl+F、
  移动底栏和更多菜单都能查询 OCR 文本并发出正确页码的跳转。
  OCR 没有几何信息时仍可搜索；后续原生能力为 false 不会阻断新增索引。
- 阅读器入口、搜索面板、搜索 controller、工具条、OCR 协调与叠层、
  PDF 渲染目录、SQLite OCR 搜索和 `test/widget_test.dart` 合计
  310 项通过，见 `regression.log`。最后仅为测试 if 增加 lint 要求的
  花括号，没有改变被测行为。
- `flutter analyze --no-pub` 最终无问题，见 `analyze-final.log`；
  初次分析发现新增测试缺少 if 花括号，已修正。格式化与差异空白检查通过。
- `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 静默成功，
  安装目录与构建 bundle 的 `diff -qr` 为空；两份 `libapp.so` 的 SHA256
  均为 `fabb5b9761fdad7edda414f0aa56f62eaf38491327baa205a1359a6f38cd4590`。
  未打开新窗口或重启现有进程。
- 未在用户原 PDF 或真实窗口复验，也未进行 Windows/Android 设备测试；
  移动入口证据为离屏 widget 交互。
