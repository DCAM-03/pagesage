# 收起目录后的阅读位置保持

日期：2026-11-18

## 用户问题与范围

- 用户反馈目录跳转完成后，收起目录会跳回之前的位置。
- 排查阅读页侧栏增删时的 renderer 生命周期，以及宽度变化后的 EPUB/Markdown 定位。
- 不改用户数据库、书籍文件、定位序列化或检索逻辑。

## 修改前验证计划

1. 在真实 `ReaderPage` 中装配 EPUB renderer 和合成文档，经目录回调跳转，再点击
   目录收起/展开与工具侧栏开关；断言 renderer State、加载次数和当前章节保持。
2. 覆盖连续阅读、分页阅读及共享该 renderer 的 Markdown。
3. 检查分页尺寸变化时是否保留当前正文 offset，而非旧页码或初次进度。
4. 执行命名回归、静态分析、差异审查和静默 Linux 重建安装。

验证入口：

- `test/widget_test.dart` 的侧栏切换位置保持用例。
- `test/renderers/epub/epub_chapter_navigation_test.dart` 的布局宽度与位置用例。
- 日志目录：`.local-data/validation/reader-panel-position-2026-11-18/`。

## 结果

### 根因与修复

- 阅读区位于含可选目录和拖动柄的 `Stack.children` 内，外层 `Positioned` 没有稳定 key。
  收起目录移除前面的两个同类型节点时，Flutter 按位置匹配兄弟节点，原有正文子树被
  销毁。正文重新挂载后会再次读取首次打开时的进度快照，而不是刚刚跳转后的会话位置。
- 为正文的顶层 `Positioned.fill` 增加稳定 key；目录增删、工具侧栏切换或响应式断点
  不再替换 renderer State、重新加载文档或重新应用初始进度。
- 另外复现分页宽度变化仍沿用旧页码的问题：窗口/侧栏改变版心后，同一个页码已不再
  对应原来的文字。重排前保存当前页的章节和正文 offset，重排后定位到包含该 offset
  的页；旧分页结果的延迟恢复回调通过页面列表身份校验失效。
- 不改进度仓储、数据库 schema、用户书籍、依赖和定位序列化；不靠额外读写数据库
  掩盖组件生命周期问题。

### 验证

- 修复前，EPUB/Markdown × 连续/分页的四项阅读页用例全部在「收起目录不得销毁
  renderer State」断言失败。最初的测试夹具因目录文件 I/O 处于 fake-async 环境而
  超时，调整为显式 real-async 等待后才取得上述四项决定性失败证据。
- 分页宽度用例也在修复前失败：旧 offset 为 7382，而缩窄后仍沿用旧页码，
  该页结尾仅到 3915。
- 修复后的五项命名验证全部通过：
  - 阅读页目录跳转到章节内非零 offset 后，收起/展开目录、打开/关闭搜索侧栏，
    EPUB/Markdown 两种模式均保持原 State、加载次数与目标章节。
  - 1440→850→1440 的窗口变化跨越侧栏断点，同样不重新挂载正文。
  - 分页宽度连续调整三次，当前页始终覆盖变化前的正文 offset。
- `flutter test --no-pub test/renderers/epub test/renderers/markdown
  test/features/reader test/widget_test.dart --concurrency=4 --reporter expanded`：
  **319 PASS / 1 SKIP / 0 FAIL**。跳过项为显式启用的真实文件性能测试，已另行运行。
- 真实《老舍全集》只读性能复测：2168 章、7,540,056 个正文字符，四次跳转目标
  均正确，离屏计时 104 / 48 / 51 / 50 ms；不含首次解析的 2930 ms。
  不输出正文，不把测试进程/离屏结果当作桌面整机体验验收。
- `flutter analyze --no-pub` 无问题，定向格式和 `git diff --check` 通过。
- 日志：`baseline-fixed-harness.log`、`baseline-width.log`、`focused-final.log`、
  `regression.log`、`real-epub.log`、`analyze.log`。

### 安装与边界

- `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 成功；
  完整 bundle 与 `~/.local/opt/pagesage` 的 `diff -qr` 无差异。
- 构建和安装 `libapp.so` SHA-256 均为
  `04583f50348ed0641a5671dfe4865ebe7309a33d553e01da178f4d80d4c4e462`。
- 安装证据：`install-linux.log`、`install-diff.log`、`install-hashes.log`。
- 未启动可见窗口或操作当前运行的应用；本轮不声称 Windows/Android 真机验收。
