# Linux 阅读窗口验收（2026-11-11）

## 范围与方法

用户已授权本轮启动 Linux GTK 测试窗口。使用真实 Flutter engine、生产 ReaderPage、
PDF/Markdown renderer、临时 SQLite 与内存安全存储，输入由 Flutter 测试绑定合成。
不操作用户书库或密钥、不调用外部 AI 服务。该结果不等于人工操作已安装 release。

待证明：OCR 选区的复制、高亮、批注、摘录、AI 入口；双页及翻回后的选择；
Markdown 文件夹切换、外部更新、Mermaid；设置分组与持久化。

样本：仓库 PDF 样本、临时 Markdown 文件，以及用户授权的《匿名数学扫描样本》
物理 20–22 页只读抽取件。原 PDF 不写入。

证据：`/tmp/pagesage-linux-window-*.log`、
`build/integration-captures/`，定向测试及安装日志另列于结果。

## 基线与反例

- 首轮 `reader_s0_test.dart` 与 `reader_markdown_test.dart` 联跑：9 PASS / 4 FAIL，
  日志 `/tmp/pagesage-linux-window-baseline.log`。
- 两个标注测试仍查找旧文字按钮，实际产品为带 tooltip 的图标；
  页码测试点到自动隐藏的工具条；Markdown 文件在第二次启动阶段未连接到 engine。
- 代码审查发现 renderer 仅记住最后一份 OCR 页，而宿主将此前页记为已恢复；
  需证明双页和翻回旧页仍可选择。无效 OCR 几何不应开启选择能力。
- 扫描页不应覆盖绘制不匹配的 OCR 字形；识别前后无选区页面应保持原图。

## 执行状态

- 首轮联合窗口：12 PASS / 7 FAIL，日志
  `/tmp/pagesage-linux-window-acceptance.log`。PDF 原有 12 项全部通过。
- OCR 完成时，`PdfCanvasView.didUpdateWidget` 同步上报能力，父页面 `setState`
  触发构建期异常；旧的画布测试只收集事件，因此未发现该生产接线问题。
  改为帧后上报并检查 mounted，补父宿主实际重建的回归。
- 新 OCR 摘录用例命中了顶部与选区两个同名「笔记」，修正为选区按钮；
  增加测试失败后的卸载，防止后续用例被残留 Overlay / Focus 污染。
- 目视发现批注菜单三等分按钮把「编辑批注」「删除批注」拆成两行，
  改为完整按钮按需换行，并补文字行框回归。
- OCR 选择层保留会话内逐页块及布局；无效几何不激活能力；移除扫描原图上
  再次绘制 OCR 字形的路径。新增 3 项回归先失败后通过，日志
  `/tmp/pagesage-linux-window-ocr-before.log`、
  `/tmp/pagesage-linux-window-ocr-retention.log`。

- 第二轮联合窗口：17 PASS / 2 FAIL，日志
  `/tmp/pagesage-linux-window-acceptance-r2.log`。OCR 复制、高亮、批注点击、
  摘录、AI 选区传递和关闭重开已通过；Markdown 文件、图片、目录和外部保存、
  设置分组及字体持久化已通过。
- 剩余两处窗口反例：在工具条触发 OCR 后，选区关闭将键盘焦点还给工具条，
  左右键无法翻页；Mermaid 已声明标签的节点后续按 ID 引用被误认为冲突定义。
  分别补阅读正文指针获取焦点、节点引用/后置定义解析修复。
- 继续检查设置截图发现切换分组沿用了上一分组滚动位置，顶部标题被裁掉；
  设置内容列表按分组重建，从顶部展示，联合用例断言滚动位置。
- 队列审查补充同一帧连续结果、待发送页被新结果覆盖两种回归；
  仅实际发送页记为已恢复，保留其他待发送页，同页待发送结果使用最新值。

## 窗口结果

第三轮联合窗口 19/19 通过，日志 `/tmp/pagesage-linux-window-final.log`。
随后目视发现当前文件更新后大纲缓存仍按路径复用，改为路径、大小与修改时间共同判定，
强化用例只在侧栏内查新标题；最终候选的目录窗口补测 1/1 通过，
日志 `/tmp/pagesage-linux-window-folder-final.log`，旧大纲已在截图中消失。

| 场景 | 结果与范围 |
| --- | --- |
| PDF 12 项 | 定位恢复、页码跳转、选区菜单、批注点击、窄窗、缩放、旋转、夜间、连续滚动、长按手柄通过 |
| OCR 2 项 | 三页扫描抽样件使用真实本地 Tesseract；复制动作、高亮落库、批注点击、摘录保存、AI 选区范围、重开、双页两侧选择和翻回通过 |
| Markdown 4 项 | 正文、图片、文件树与当前大纲、文件切换不跳页签、外部保存、Mermaid 图形/源码/展开/复位通过 |
| 设置 1 项 | 字体保存与跨分组保留、五组导航、切组回到顶部通过 |

复制动作拦截 `Clipboard.setData` 验证传入文字，未改写用户系统剪贴板。
AI 只验证面板与选区传递，没有发送模型请求。窗口截图来自真实 engine 的
`RepaintBoundary`，不是人工 OS 输入录屏，也不是已安装 release 的人工手测。

目视复核：PDF 选区菜单、OCR 原图/批注/双页/AI 上下文、Markdown 外部保存、
Mermaid 内嵌与展开、设置 AI 分组。截图位于 `build/integration-captures/`。

## 最后坐标复核

AI 侧栏打开后页面缩小并居中，手柄先加居中偏移再按页面大小裁剪，导致手柄偏离原文。
新增缩小居中页的反例复现横向 72.6 px 偏差，
日志 `/tmp/pagesage-linux-window-handles-before.log`；
改为先在页面坐标中裁剪再加父容器偏移，同时在真实 OCR → AI 用例加入四个端点坐标断言。
修复后画布 51 项回归全部通过，日志 `/tmp/pagesage-linux-window-handles-final.log`；
真实 OCR 两项 2/2 再次通过，日志 `/tmp/pagesage-linux-window-ocr-final.log`，
包括 AI 侧栏打开后的端点坐标断言。刷新并目视检查的
`ocr-03-ai-selection-context.png` 中手柄已贴合原文选区。

## 工程验证

- 本轮不同定向测试场景共 181 项通过：首批 157 项、设置 13 项、
  阅读面板 10 项和追加手柄反例 1 项；末次画布 51 项为受影响复测，不重复计数。
  日志分别为 `/tmp/pagesage-linux-window-focused.log`、
  `/tmp/pagesage-linux-window-settings-unit.log`、
  `/tmp/pagesage-linux-window-panels.log`、`/tmp/pagesage-linux-window-handles-final.log`。
- 最终 `flutter analyze` 无问题，日志 `/tmp/pagesage-linux-window-analyze-final.log`；
  仅格式化本轮 Dart 文件。未将此前全仓 1001 项结果冒充本轮全量回归。
- 无新依赖、无数据库迁移、无阅读定位或导出格式变更。OCR 行内字位仍按行宽近似，
  本轮没有升级识别引擎，也没有重新测量 30 页准确率或性能。
- 新联合入口 `integration_test/linux_reader_acceptance_test.dart` 在一个 GTK 测试进程
  内注册四组场景，避免多测试文件重复启动时 debug 连接失败。

## 复现入口

准备只读抽样件后执行；以下测试会启动获授权的 GTK 测试窗口，不另开终端：

```bash
mkdir -p .codex-run/ocr-window
pdfseparate -f 20 -l 22 "${PAGESAGE_TEST_PDF:?请提供已授权的扫描样本路径}" .codex-run/ocr-window/page-%d.pdf
pdfunite .codex-run/ocr-window/page-20.pdf .codex-run/ocr-window/page-21.pdf .codex-run/ocr-window/page-22.pdf .codex-run/ocr-window/scanned-three-pages.pdf
flutter test integration_test/linux_reader_acceptance_test.dart -d linux --no-pub --reporter expanded
```

## 最终安装

- 最终候选经静态分析后执行
  `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，退出码 0；
  日志 `/tmp/pagesage-linux-window-install-final.log`。
- 完整 release bundle 与 `<HOME>/.local/opt/pagesage` 逐文件比较无差异；
  `/tmp/pagesage-linux-window-install-diff-final.log` 为空。
- 两处 `lib/libapp.so` SHA-256 均为
  `b20c33d2e5f8f375b75970654fb0f3a949d63f57a4dd75d7754764205b9b9f85`，
  核对记录 `/tmp/pagesage-linux-window-install-sha256-final.log`。
- 测试窗口已退出，安装后未另开应用窗口；检查时没有运行中的 PageSage 进程。
