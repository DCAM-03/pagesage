# PDF 搜索跳转后划词高亮

日期：2026-11-12
状态：修复、定向回归及本地安装完成

## 问题与范围

用户截图中当前 PDF 为第 195 页，划词菜单和 AI 选区却仍引用第 48 页，
正文未显示对应选区。检查发现 PDF view 长期保存页面的全局矩形快照，
既未在页面卸载时移除，也不能随滚动变换即时更新。命中测试遍历旧矩形时
可能命中已经离开的页面，造成选中文字、locator 和可见高亮不一致。

仅修正 PDF 可见页面的几何生命周期；保持搜索、批注和 AI 的领域事件契约。
不改用户书库、原始 PDF、发布标签或已发布安装包。

## 验证计划

- 新增真实 `large-text.pdf` 的 widget 回归：搜索结果跳转后鼠标拖选，
  检查选区页码、正文矩形、可见手柄及离屏截图中的实际蓝色高亮。
- 同页滚动后点击划词，确保使用当前屏幕位置而非上一次布局快照。
- 分页模式跳转、来回跳转及窗口缩放后仍命中当前页。
- 复用现有 PDF 划词、OCR、高亮、导航与阅读器选区操作回归；静态分析。
- 静默构建安装 Linux 并核对安装文件；不启动或重启可见窗口。

证据：`.local-data/validation/pdf-selection-after-search-2026-11-12/`。

## 结果

- 修复前 3 项回归稳定失败：跳至第 40 页拖选却上报第 1 页；
  分页跳至第 40 页却上报第 37 页；同页滚动后点击第二行得到第一行 `Large`，
  而非目标词 `Generated`。证据为 `before.log`。
- view 改为登记仍挂载的页面 key，手势命中时读取当前 RenderBox 的全局位置和实际尺寸；
  页面卸载 / 复用时按 key 身份移除登记，不再保留过期矩形或每次 build 安排坐标快照回调。
  原生划词转换也使用实际显示尺寸，覆盖滚动、缩放与分页位置变化。
- 新增 5 项回归全部通过：搜索跳转后拖选、同页滚动、分页往返、窗口缩放、
  触摸长按。拖选用例验证 locator、矩形、手柄属于当前页，并采集像素确认蓝色选区
  确实出现在目标文字带内，而非只检查事件存在。
- 离屏截图 `build/workbench-captures/pdf-search-jump-selection.png` 已检查，
  选区和手柄落在第二行；样本未嵌入字体，测试环境字形为占位块，
  此截图只作为几何与高亮证据，不用于原书字体质量验收。
- PDF 渲染目录与 `reader_selection_actions_test.dart` 合计 217 项通过，
  证据为 `regression-final.log`。首次宽回归误含不存在的
  `reader_annotation_editor_test.dart`，保留 `regression.log` 失败记录；
  更正测试入口后重跑上述完整定向集合并通过。
- `flutter analyze --no-pub` 无问题，格式化及 `git diff --check` 通过。
- `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 静默成功，
  安装目录与 bundle 的 `diff -qr` 为空；未启动、关闭或重启应用。
- 未在用户原 PDF / 真实窗口、Windows 或 Android 设备重验；
  本轮手势与渲染验证为 Linux 上运行的真实样本离屏 widget 回归。
