# 代码冗余与组织清理（2026-11-09）

## 范围与基线

按用户要求检查不必要兼容、死代码及目录职责，并清理已确认项。保留仓库已有未提交改动，
不修改 IAM 源项目，不调整数据库 schema、定位、AI 请求或阅读行为。

- 基线 `flutter analyze`：通过，无问题；分析器不能证明公开但无人调用的类不是死代码。
- 对 `lib/main.dart` 的静态 import/export/part 链路及 test/tool/integration_test 使用点做交叉检查。
- 123 个非生成应用 Dart 文件；4 个模块未进入生产入口，其中 2 个只有专用测试引用。

## 已确认清理项

| 项目 | 调用证据与处理 |
| --- | --- |
| `AppError` / `DataError` / `FileImportError` / `RendererError` | 无生产、工具或测试调用；删除未接入的错误骨架，保留实际领域异常 |
| `AppLogger` | 无调用；删除日志包装与仅为它声明的 logger 依赖，保留任务错误仍使用的 `PrivacySanitizer` |
| `TaskQueue` | 只有两个自测调用；导入用例逐项 await，状态/取消由现有 repository 与 registry 管理；删除未接入的队列及自测 |
| `EpubSelectionStabilizer` | 只有两个自测调用；实际选区由 EPUB renderer 处理；删除未接入的计时器包装及自测 |
| `RendererBookmarkRequested` | 没有 renderer 发出；删除事件、空消费/转换链及其专属保存方法，工具栏实际书签路径保留 |
| `RendererImagesDetected` / `RendererDetectedImage` | 没有事件生产者或实际消费者；删除预留协议，保留实际吸附使用的 `PdfDetectedImage` 与图片选区事件 |
| 应用层 `ai_context_reference.dart` | 仅转发领域模型；内部调用方统一导入 `domain/ai/ai_context_reference.dart` 后删除转发文件 |
| `sqlite3_flutter_libs` | 已解析版本 `0.6.0+eol` 的包说明与代码确认不再提供功能；当前 SQLite 已为 3.x，移除空包及许可展示中的旧名称 |
| 阅读器装配 | 将配置、可覆盖 provider 与默认格式装配移至 `reader_renderer_host.dart`，调用方同步导入，不留旧路径转发 |
| 未使用成员 | 再核对生产、测试和工具引用后删除 14 个无消费者的方法 / getter：旧单文件导入包装、目录前后文件 helper、未调用的 OCR 查询 / 缓存 / 图片路径 helper、PDF / 上下文辅助成员及重复主题 / 断点 getter |

删除的 4 个测试只证明已退役且未接入的 TaskQueue / Stabilizer 类，不承载实际应用调用链；
真实导入、任务中心、书签、阅读会话和选区消费者仍使用下表现有行为测试验证。
Flutter 生命周期 `didChangeAppLifecycleState` 虽没有显式调用点，实际由框架派发，保持不变；不能仅凭词频删除回调。
旧任务中列出的通用错误、logger 和队列路径属于早期设计，不再代表当前接入情况；本记录明确替代这些实现声明。

## 需要保留的兼容与抽象

- Markdown 旧合并 locator 到文件内坐标的映射：已持久化进度、书签、笔记和 AI 来源仍可能使用旧位置。
- 旧 AI 记录无来源快照、旧线程 ID、旧 settings 缺字段等读取：有真实历史数据语义，不能当死代码删除。
- 自定义字体、旧 PDF 标注几何与 OCR 缓存处理：影响已保存设置或标注，不改数据格式便删除会退化。
- 评测工具的 `LegacyContextRetriever`：固定对照基线，不进入应用包，不能与生产兼容层混为一谈。
- 平台 OCR stub、`PdfPageImageSource` 及可替换 loader：承担平台能力和测试边界，不因当前只有一个生产实现就删除。

## 目录组织结论

feature / domain / core / renderers 的大方向清楚，但职责还未充分收敛：

1. 阅读页同时承载工作台、文件会话、菜单与 Notebook；先拆独立装配，后续按实际职责抽侧栏与设置，不按任意行数拆文件。
2. `drift_content_repositories.dart` 混放 9 类仓储；后续可随对应功能拆 AI、搜索、任务仓储，保持 provider 与数据契约不变。
3. `ReaderSettings` 在领域层直接使用 Flutter 的 Color / ThemeMode；属于现有边界债，迁移会涉及序列化和多处 UI，本轮不批量改模型。
4. renderer 与 OCR provider、core 索引与具体解析器仍有装配耦合；先确认资源和调用边界，不增加空接口或全仓架构重写。
5. 数据仓储从 `renderers/epub/epub_jump.dart` 借用纯定位 helper，导致数据层依赖具体渲染目录；后续将共享定位规则放到恰当的纯模型边界，并同步搜索、笔记与引用消费者。

## 写入前确定的验证矩阵

| 变化 | 命名验证入口 | 预期 |
| --- | --- | --- |
| host 装配 / 事件删除 | `test/widget_test.dart`、`test/ui_screenshots_test.dart`、`test/features/reader/reader_providers_test.dart` | 装配覆写、阅读器交互、书签及进度行为保持 |
| 真实渲染消费者 | `test/renderers/pdf/pdf_canvas_view_test.dart`、`test/renderers/markdown/markdown_rendering_test.dart`、`test/renderers/epub/epub_annotation_rendering_test.dart` | 搜索、选区、标注与 Markdown 文件内阅读不退化 |
| 模型导入 / 评测 | `test/features/ai/ai_context_reference_test.dart`、`test/features/ai/context_retriever_test.dart`、`test/features/ai/retrieval_context_source_test.dart`、`test/tool/retrieval_eval_test.dart` | 来源往返、检索和固定评测基线契约不变 |
| 数据与必要兼容 | `test/core/database/ai_context_snapshot_test.dart`、`test/core/database/search_repository_test.dart`、`test/domain/books/reading_position_test.dart`、`test/renderers/markdown/markdown_folder_test.dart` | 实际 SQLite、重开及旧定位读取保持 |
| 真实任务与隐私 | `test/features/import/import_use_case_test.dart`、`test/features/tasks/task_center_controller_test.dart`、`test/core/logging/privacy_sanitizer_test.dart` | 生产导入/任务取消与恢复、错误脱敏保持 |
| 依赖与许可 | `test/tool/release_readiness_test.dart`、命名文件 format、`flutter analyze` | 不留旧导入和无效依赖，许可与 lock 一致 |
| 未使用成员清理 | `test/renderers/pdf/pdf_annotation_lines_test.dart`、`test/renderers/pdf/pdf_selection_test.dart`、`test/features/ocr/ocr_current_page_use_case_test.dart`、`test/features/ai/context_builder_test.dart`、`test/core/platform/open_file_location_service_test.dart`、`test/core/files/image_cache_store_test.dart`、`test/app/responsive/app_breakpoints_test.dart`、`test/app/theme/app_theme_contrast_test.dart` | 保留的实际行为、资源与主题不变；复跑受影响的 Markdown、导入及实际 SQLite 用例 |
| 本地安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle diff | 静默安装当前候选，不启动或重启窗口 |

## 执行结果

- 已完成上述清理与装配提取，没有增加业务功能。阅读页由 9466 行降为 9294 行，装配文件 138 行；页面主体仍大，不能宣称结构债已清零。
- `dart format` 检查 / 格式化本次涉及文件完成，最终 `flutter analyze` 无问题，`git diff --check` 通过。
- 第一轮矩阵的 18 个命名测试文件：**193 项通过、2 项跳过**。跳过项为缺少现成本地 APK / AAB 的 Android 包内资源检查，并非通过的 Android 验收。日志：`/tmp/pagesage-cleanup-tests.xd90oS.log`。
- 成员清理后对 12 个受影响命名测试文件补验证：**104 项通过**。包含第一轮已有的 Markdown / 导入 / SQLite 场景，因此不把两轮数量相加声称唯一用例总数。日志：`/tmp/pagesage-cleanup-members-tests.LCt87m.log`。其余第一轮结果因没有消费者受本轮成员删除影响而保留。
- 最终数据库源码与本轮前候选对比：仅删除两个无调用 DAO 方法及格式空行，schema 与迁移不变；临时真实 SQLite 升级、关闭 / 重开验证通过。
- 包解析仅移除 `logger 2.8.0`、`sqlite3_flutter_libs 0.6.0+eol`，未新增包或改变其余锁定版本；第三方许可报告重新生成，涵盖 141 个非 SDK 包。
- 提取前后 host 配置与默认装配代码去除注释 / 空白后相同；项目 import 图没有悬空本地路径，非生成应用 Dart 文件没有整文件游离于 main 入口引用链。此结论不等于证明所有分支和公开符号都活跃。
- 已执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建与安装成功，整个 bundle 与 `<HOME>/.local/opt/pagesage` 的 `diff -qr` 无差异。安装日志：`/tmp/pagesage-cleanup-install.2NdkQB.log`。
- 构建及安装的 `libapp.so` SHA256 一致：`be58fed3f25ce9e37c099ed351765f85ae0d2ef63859f36648e645cc9b21c358`。没有启动、关闭或重启用户窗口。

本轮是代码清理及组件 / 持久化验证；未执行 Windows/Android 真机验收或人工视检，不以静态引用分析、组件测试或 Linux 安装代替这些结论。后续整理优先处理阅读页的侧栏 / Notebook / 设置职责，再拆多职责仓储及共享定位边界。

## 第二轮：按职责拆分

用户授权继续拆分。本轮按 `review-code-organization`、`pagesage-dart-engineering` 与
`validation-harness` 执行，只搬迁明确独立的职责，不改变阅读交互、数据库 schema、持久化格式或依赖。

- 将聚合文件中的 9 类 Drift 仓储各归一个文件，沿用同目录现有 book / settings 仓储的命名；共享 locator 解码集中维护。
- 将阅读设置面板、桌面 / 移动目录组件移出阅读页；计时器、控制器、展开状态与生命周期随所属组件一起迁移。
- 跨组件复用的空状态单独归属；快捷主题 chip 仍只服务阅读页，不因原来位于设置块附近便扩大可见性。
- 所有生产、测试和工具消费者直接导入实际实现，不保留旧聚合路径的转发层。Notebook 与页面编排留待独立边界调查。

写入前验证选择（本地 Flutter CLI，离屏组件与临时 SQLite，不启动应用窗口）：

| 待证明不变量 | 精确入口 | 预期信号 |
| --- | --- | --- |
| 仓储映射、排序、索引、保存 / 读取行为不变 | `test/core/database/category_tag_repository_test.dart`、`bookmark_repository_test.dart`、`annotation_repository_test.dart`、`note_repository_test.dart`、`search_repository_test.dart`、`task_repository_test.dart`、`ai_context_snapshot_test.dart`（均位于 `test/core/database/`） | 实际 SQLite 场景全部通过，迁移源码不变 |
| 图片批注历史与仓储消费者保持 | `test/core/database/image_annotation_migration_test.dart`、`test/features/import/import_use_case_test.dart`、`test/features/ai/ai_panel_thread_test.dart` | 迁移 / 重开、导入和历史线程通过 |
| 设置保存、目录文件与大纲、筛选和定位不退化 | `test/widget_test.dart`、`test/features/reader/reader_providers_test.dart`、本轮按实际覆盖缺口补充的设置 / 目录组件测试 | 持久化设置、文件页签保持及定位断言通过；组件卸载无遗留计时器 |
| 依赖与纯搬迁边界 | 命名文件 format、`flutter analyze`、搬迁前后方法体核对、实际消费者 import 检查 | 无分析问题、悬空路径或反向依赖，schema / 生成产物未改 |
| 当前源码已安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle diff | 安装成功且全 bundle 一致；不重启用户进程 |

基线沿用上一轮有效测试，当前阅读页 9294 行、仓储聚合文件 1146 行；本轮前候选另存临时快照，
不以 Git HEAD 代替包含用户未提交工作的起点。最终执行证据在本节追加。

首轮新增面板测试实际触发设置分组的 Flutter 断言：带底色的 `DecoratedBox` 挡住
`ExpansionTile` 内 ListTile 的 Material 点击反馈。该包裹结构在搬迁前已存在；本轮在
原装饰内部补透明 Material，只修复材质绘制边界，保留颜色、边距、展开逻辑与设置语义。
首轮失败日志保留为 `/tmp/pagesage-split-panels-tests.FcaDcw.log`，后续验证使用修复后的候选。

### 第二轮实现与验证结果

- 9 类仓储已拆为同目录的 `drift_category_repository.dart`、`drift_tag_repository.dart`、
  `drift_bookmark_repository.dart`、`drift_annotation_repository.dart`、`drift_note_repository.dart`、
  `drift_search_repository.dart`、`drift_ai_settings_repository.dart`、
  `drift_ai_conversation_repository.dart`、`drift_task_repository.dart`。
  `database_providers.dart` 及全部真实 test / tool 消费者直接导入各实现，旧聚合文件已删除。
- `drift_locator_mapping.dart` 唯一维护原有 locator 数据库解码；helper 改名以便跨文件使用，
  函数体逐字保持。现有 book / settings 仓储、schema、迁移与数据库生成文件未改。
- 阅读页迁出 `reader_toc.dart`（后续第九轮继续拆为桌面 / 移动目录及共享树文件）、
  `reader_settings_sheet.dart`
  和 `reader_context_empty_state.dart`。桌面目录的 loader 由页面按原格式选择后注入，
  快捷主题 chip 仍私有于阅读页。页面从 9294 行变为 7474 行，Notebook 等职责仍未全部拆开。
- 本轮前快照：`/tmp/pagesage-split-baseline.fm861dys`。以 Dart formatter 对齐空白和可选尾逗号后，
  13 组源码对比通过：9 个仓储类、阅读页剩余编排、全部目录代码，以及设置状态 / 预设与预览 / 滑杆。
  预期差异仅包括导入、公开组件命名与 key、共享 helper 命名及 loader 注入；设置分组的透明 Material
  属于上文明确的修复。所有本地 Dart 路径可解析，应用 import 图未发现循环。
- 新增 `test/features/reader/reader_panels_test.dart`，5 项通过：预设连续修改仅保存末次值且保留其他设置、
  重置后卸载刷新待保存值、桌面目录展开 / 防抖筛选 / 精确跳转 / 清空 / 计时器释放、
  移动目录祖先展开、PDF 目录页码与标题偏移返回。
  日志：`/tmp/pagesage-split-panels-tests.lLEal7.log`。
- 12 个既有命名测试文件共 **79 项通过**，包含真实 SQLite 仓储、图片历史迁移、AI 来源关闭 / 重开、
  导入与线程消费者、reader provider，以及文件树切文件后保持页签的阅读页交互。
  日志：`/tmp/pagesage-split-regression.pz8vvT.log`。与新增面板测试合计 **84 项行为测试**，不宣称全量回归。
- 截图测试显式开启后通过；新增 1440×960 与 390×844 的设置面板场景，实际图片已查看，未见面板越界或控件相互遮挡。
  路径：`.codex-run/ui-screenshots/reader-settings-desktop.png`、`reader-settings-mobile.png`；
  日志：`/tmp/pagesage-split-screenshots.Kyos5z.log`。离屏 fixture 的自定义 TextStyle / 默认字体仍有方框字，
  这些截图只作布局证据，不能证明真实设备字体呈现。PNG 导出改用 `tester.runAsync` 避免真实图片 Future
  阻塞后续 fake-async 场景，新增场景显式等待抽屉动画。
- 最终 `flutter analyze` 无问题，日志：`/tmp/pagesage-split-final-analyze.69PpX7.log`。
  本轮命名 Dart 文件已格式化，`git diff --check` 通过。没有启动桌面集成测试或真实应用窗口，
  未将离屏组件验证当作 Windows / Android 真机验收。
- 已实际执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建与本地安装成功。
  安装日志：`/tmp/pagesage-split-install.Vw5URA.log`；整个 bundle 与
  `<HOME>/.local/opt/pagesage` 的 `diff -qr` 无差异。
  构建与安装的 `libapp.so` SHA256 均为
  `620de311125367ad9e105d8d336eab7f15fad31d07bd29f564512af3eab94f42`。
  构建前后数据库 schema / 生成文件及 `pubspec.yaml` / `pubspec.lock` 哈希保持一致，
  未启动、关闭或重启用户应用。下一轮优先拆 Notebook 与页面内操作编排，保留其共享编辑 / 撤销行为。

## 第三轮：Notebook 与共享编辑操作

用户授权继续。本轮使用项目 Dart、代码组织与验证规范，保持仓库已有改动，
将 Notebook 的组件、查询 provider、批注编辑与共享操作按实际调用关系迁出阅读页。

- Notebook 列表、条目映射 / 排序、菜单与笔记动作归属阅读器 Notebook 组件。
- 书签 / 标注 / 笔记查询 provider 移至阅读器 application，页面、Notebook 与渲染器装配使用同一实例。
- 正文菜单和 Notebook 共用的批注编辑 / 关联笔记 / 删除及书签编辑 / 撤销只保留一个实现；
  对话框和 Snackbar 留在 presentation，不伪装成接受 BuildContext 的 application 服务。
- 删除仅转发到同一个 Notebook 内容组件的桌面包装；同步全部真实消费者，不增加旧路径转发。
- 本轮以调整归属和必需的跨文件命名为主；另修复回归测试实际触发的编辑框与撤销生命周期问题，
  详见下文。不修改 schema、序列化、检索算法或交互设计。

基线快照：`/tmp/pagesage-notebook-split-baseline.slpa6aii`，当前阅读页 7474 行；
此前未受影响的仓储与设置验证继续保留，不为新时间戳重复全量回归。

写入前验证选择（本地 Flutter CLI，全部静默）：

| 待证明不变量 | 精确入口 / 场景 | 预期 |
| --- | --- | --- |
| Notebook 内容过滤、排序和跳转保持 | 新增 `test/features/reader/reader_notebook_test.dart`，临时 SQLite + 实际 provider / 组件 | 混合书签、文字 / 图片批注、笔记和 AI 条目正确呈现；排除其他书籍；保留定位与回跳原文 |
| 共享编辑和关联数据不丢失 | 同文件：书签备注清空 / 保存 / 撤销，批注样式与图片 anchor，批注 / AI 转笔记、删除确认和保留关联笔记 | 同 ID 更新、字段保真、provider 刷新及缓存删除符合原行为 |
| 页面装配和正文菜单消费保持 | `test/widget_test.dart`、`test/features/reader/reader_providers_test.dart` | 阅读页 Notebook 打开与工具页签、正文图片批注修改、书签和进度保持 |
| 源码搬迁和依赖边界 | 格式化后的搬迁前后源码核对、精确调用搜索、`flutter analyze`、`git diff --check` | 无未声明的业务变化、悬空导入、循环或 UI 反向依赖；schema / 依赖哈希不变 |
| 本地安装跟随本轮候选 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、全 bundle diff 与 libapp.so 哈希 | 静默安装成功，不启动或重启已有应用 |

### 第三轮实现与验证结果

- 新增 `reader_notebook.dart`、`reader_annotation_editor.dart`、`reader_annotation_actions.dart`、
  `reader_bookmark_actions.dart`，均位于阅读器 presentation；3 个原有查询 provider 统一迁至
  `application/reader_notebook_providers.dart`，保留名称及 Stream / Future 语义。
  正文菜单与 Notebook 直接使用共享实现，删除仅转发同一组件的桌面包装，无兼容转发文件。
  阅读页由 7474 行减至 6433 行，仍负责阅读会话和页面编排。
- 机械搬迁初始候选经过 formatter 对齐后的 6 组源码核对：查询 provider、Notebook 主体、
  书签操作、批注编辑器与颜色、批注操作、阅读页剩余内容。除公开命名、key、导入及删除桌面
  转发包装外，原实现保持。最终候选额外包含下面明确列出的两类修复，不能再视为纯搬迁。
- 首轮完整 Notebook 测试 5 项通过、4 项失败；日志为
  `/tmp/pagesage-notebook-tests.yKevYZ.log`。实际发现原有书签及批注编辑器在对话框退场动画结束前
  释放 `TextEditingController`，以及删除书签后点击撤销仍读取已卸载条目的 `WidgetRef`。
  编辑框改为 `TextFormField` 管理内部控制器生命周期，保留初始值、取消、保存及样式选择；
  书签操作提前捕获仓储，撤销不再访问已销毁组件。未通过延时或吞异常规避失败。
- 新增 `test/features/reader/reader_notebook_test.dart`，最终 **10 项通过**：混合条目按位置排序、
  书籍范围与跳转；书签取消 / 保存 / 清空 / 删除撤销；批注编辑取消后重新打开及样式切换保留输入；
  图片样式修改保留 anchor 和关联笔记；批注去重关联笔记与列表刷新；AI 笔记保留历史上下文与轮次关联；
  图片删除确认与保留笔记；笔记删除确认和缓存查询刷新；移动 Notebook 返回定位并关闭。
  使用实际 provider 和临时内存 SQLite；Drift 测试连接启用官方 `closeStreamsSynchronously` 选项，
  防止退出时遗留流清理 timer，不改生产数据库构造。图片缓存使用记录 delete 的替身，
  因此只证明清理调用的 bookId / anchor 正确，不宣称真实磁盘缓存已验证。
  日志：`/tmp/pagesage-notebook-final.Ep0n1U.log`。
- `test/widget_test.dart`、`test/features/reader/reader_providers_test.dart` 共 **31 项通过**，
  覆盖页面装配、移动 Notebook、文件树页签保持、图片批注修改及阅读 provider 消费者。
  日志：`/tmp/pagesage-notebook-regression.kcjriB.log`。本轮合计 **41 项行为测试**，不是全量回归；
  上轮未受影响的仓储、目录和设置验证继续有效。
- 最终 `flutter analyze` 无问题，日志：`/tmp/pagesage-notebook-analyze.ghXxHz.log`。
  本轮 7 个 Dart 文件格式检查与 `git diff --check` 通过，应用本地 import / export 可解析且无循环。
  相对本轮快照，仅修改原阅读页、新增 5 个生产文件和 1 个测试文件，没有修改其他现有 Dart 文件。
  `pubspec.yaml` / `pubspec.lock`、数据库 schema 与生成文件哈希保持一致。
  没有启动真实应用或桌面集成测试；本轮未验证 Windows / Android 真实平台运行。
- 已执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，本轮 Linux release 构建及
  本地安装成功。日志：`/tmp/pagesage-notebook-install.gYieAG.log`；整个 bundle 与
  `<HOME>/.local/opt/pagesage` 的 `diff -qr` 无差异。构建与安装的 `libapp.so` SHA256 均为
  `6e9b3365e8174f66765fdbd4baaf532a9bc1e90f6a7090d6da110a90729f8bd7`。
  构建后再次核对依赖及数据库文件哈希不变。未启动、关闭或重启用户应用；现有进程需用户重启后
  才加载本次安装的产物。

## 第四轮：书内搜索与工具侧栏

用户要求继续清理，并确认依照已适配的 skill 工作。本轮继续使用 `workstream-triage` 定位
已完成边界，按 `review-code-organization`、`pagesage-dart-engineering` 与 `validation-harness`
实施下一片：书内搜索拥有其输入控制器、结果导航和片段操作；桌面工具侧栏只负责页签装配。
阅读页保留侧栏展开、宽度、页签持久化和跳转等会话编排，不将状态拆成相互转发的包装。

- 基线快照：`/tmp/pagesage-search-split-baseline.yybcvlsa`；阅读页 6433 行。
- 迁出搜索组件及其 UI 返回结果契约、桌面工具侧栏；更新实际消费者，不留兼容转发。
  复用设置中已有的 `ReaderContextTab`，标签与图标留在 presentation 扩展中，删除重复 UI 枚举及名称转换。
- 清理侧栏从未读取的 `onAskAi` 参数；实际 AI 仍由 `AiPanel` 和页面现有入口处理。
- 检查搜索控制器在防抖等待、清空、卸载以及组件切换书籍时的请求身份和资源所有权。
  若新测试证明旧结果覆盖或已释放对象访问，作对应局部修复，不更换搜索算法、schema 或依赖。

写入前验证选择（本地 Flutter CLI，离屏、静默，不打开应用窗口）：

| 待证明行为 | 命名入口 | 预期与证据 |
| --- | --- | --- |
| 防抖、旧请求、清空与释放 | 扩展 `test/features/reader/in_book_search_controller_test.dart` | 可控 Future 完成顺序；旧结果 / 旧异常不能覆盖新查询，卸载后不再通知 |
| 搜索组件输入、导航、重试、清空和关闭 | 新增 `test/features/reader/reader_search_pane_test.dart` | 真实组件事件与来源定位、片段保存 / AI 返回契约正确，切书不使用旧控制器 |
| 工具侧栏与实际页面装配 | 同文件补侧栏页签装配测试；`test/widget_test.dart`、`test/features/reader/reader_providers_test.dart` | 页签变化走原回调，当前工具页签和文件树行为保持 |
| 搬迁范围与依赖 | formatter 对齐源码核对、命名文件 format、analyze、import 图及基线哈希 | 行为变化仅限测试证明的修复，无悬空导入、循环或依赖 / schema 变化 |
| 本地安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle diff 与哈希 | 安装本轮候选且产物一致，不启动或重启应用 |

### 第四轮实现与验证结果

- 新增 presentation 的 `reader_search_pane.dart` 与 `reader_context_pane.dart`，阅读页只通过
  查询、预览、清空、关闭、页签切换及搜索动作回调装配它们；无旧路径转发。
  删除没有消费者的侧栏 `onAskAi` 参数，以及与设置模型重复的 UI 页签枚举。
  标签 / 图标使用 presentation 扩展，持久化继续使用原枚举和值，不改变历史设置。
  阅读页由 6433 行减至 5801 行。
- 迁移初始候选经过 formatter 对齐后的 3 组源码比较：搜索主体和导航 / 返回动作、工具侧栏、
  阅读页剩余部分。除导入、公开命名与 key、移除未用回调、复用原设置枚举及删除名称转换外一致。
  初始迁移版本另存于 `/tmp/pagesage-search-split-baseline.yybcvlsa/extracted`，随后修复明确列在下文。
- 新增控制器反例初次运行 **5 项通过、4 项失败**，日志：
  `/tmp/pagesage-search-lifecycle-baseline.8vpqYW.log`。原实现只在真正开始下一次搜索时递增 generation，
  防抖期间旧请求结果 / 异常可污染新查询；释放时也没有使请求失效，导致异步完成后通知已释放对象。
  修复为输入变化立即递增请求身份并清空旧结果，防抖等待算搜索中；释放时同样使请求失效。
- 初次组件验证 **8 项通过、4 项失败**，日志：`/tmp/pagesage-search-pane-baseline.ousAaf.log`。
  实际证明切书复用旧控制器、外部清空查询不能清空结果、关闭后保存访问失效 WidgetRef、
  切书后保存刷新错书籍这四种旧缺陷。切书时重新建立搜索控制器，旧请求随旧控制器失效；
  外部空查询与输入框、结果一起清空。结果导航、片段去标记、AI 返回定位与文本保持原契约。
- 新增 `application/reader_search_note_service.dart`，拥有搜索片段转笔记与原书籍查询刷新编排。
  presentation 在发起时捕获 bookId，完成后只在同书组件仍存活时显示反馈；
  application 使用其 Provider Ref 生命周期，不读取已卸载组件的 WidgetRef。
  早期修复候选误用了 Riverpod 仅供内部测试的 container getter，编译未通过，
  已改为上述 application 服务与公开 Ref API；不为绕过错误引入内部库依赖或延时。
- `test/features/reader/in_book_search_controller_test.dart` **10 项通过**，
  `test/features/reader/reader_search_pane_test.dart` **12 项通过**，合计 **22 项**。
  覆盖防抖请求范围、已完成 / 未完成旧结果、旧异常、清空、释放，组件切书 / 外部查询同步，
  精确导航、错误重试、片段保存和关闭 / 切书后的原书籍缓存刷新、移动返回及工具侧栏回调。
  使用可控 Future 决定完成顺序；笔记和索引写入使用临时真实 SQLite，查询结果由可控仓储提供，
  不宣称这些组件测试验证了真实 EPUB / PDF 渲染或全文检索质量。
  日志：`/tmp/pagesage-search-split-tests.eEugnV.log`。
- `test/widget_test.dart`、`test/features/reader/reader_providers_test.dart`、
  `test/domain/books/reader_settings_test.dart` 共 **35 项通过**；包含页签持久化、文件树保持、
  搜索结果保存为摘录笔记和原有图片批注消费路径。
  日志：`/tmp/pagesage-search-split-regression.2REjWG.log`。与上述测试合计 **57 项不同用例**，不是全量回归。
- 最后按 `code-quality-audit` 对照实际差异复核请求身份、controller / timer 释放、Provider Ref
  生命周期和定位字段保真，沿用本轮已加载的 Dart / Flutter 参考；没有运行不支持 Dart 的旧扫描脚本。
  分析器提示的两处构造器风格已按同目录的转发构造方式修正，随后复跑受影响的 3 项保存场景通过，
  日志：`/tmp/pagesage-search-note-final.jpiGv8.log`，不重复计入 57 项。
  最终 `flutter analyze` 无问题，日志：`/tmp/pagesage-search-split-final-analyze.D2aNkM.log`。
  7 个本轮 Dart 文件已格式化，`git diff --check` 通过。
- 相对本轮快照，生产代码仅修改阅读页与搜索控制器，新增搜索组件、工具侧栏和搜索笔记服务；
  测试仅扩展原搜索控制器测试并新增搜索组件测试。其他已有 Dart 文件未改；
  `pubspec.yaml` / `pubspec.lock`、数据库 schema 与生成文件哈希不变，本地 import / export 可解析且无循环。
  本轮没有调整布局样式或打开真实窗口；未执行 Windows / Android 真机及真实渲染器验收。
- 已实际执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建和本地安装成功；
  日志：`/tmp/pagesage-search-split-install.AXLytz.log`。整个 bundle 与
  `<HOME>/.local/opt/pagesage` 的 `diff -qr` 无差异；构建及安装的 `libapp.so` SHA256 均为
  `1ddc8c9db5e955d033728807db4c6be3d0b453575defcc4e461498752246aaf6`。
  构建后依赖及数据库文件哈希再次核对保持不变。未启动、关闭或重启用户应用，已有进程仍需用户重启加载新版。

## 第五轮：选区操作与摘录编辑

用户明确选择本次由当前会话继续实施，保留质量检查。本轮实施、测试和源码复查均由当前会话完成，
不称为独立验收。基线为 `/tmp/pagesage-selection-split-baseline.vqlWgBg2`，阅读页 5801 行；
保留已有未提交成果，不修改 IAM 源目录或重新制定多会话规则。

- 将文字 / 图片选区操作组件及其 UI 动作枚举迁出阅读页，菜单展示与动作分发保持原意。
- 将摘录编辑器作为独立 presentation 组件管理输入生命周期；搜索摘录与手写摘录共用 application
  保存服务，持有发起时的书籍和来源，不在异步结束后依赖已卸载页面刷新缓存。
- 重点核对替换选区菜单后的旧 Future 清理、同文不同定位、取消与动作后的高亮规则，以及编辑器退场。
  仅修复反例证明的局部问题，不改变定位序列化、数据库 schema、检索或 AI 触发策略。

写入前验证选择（离屏、静默，不打开应用或终端窗口）：

| 待证明行为 | 验证入口 / 场景 | 预期 |
| --- | --- | --- |
| 菜单生命周期与来源身份 | 新增 `test/features/reader/reader_selection_actions_test.dart` 的实际阅读页事件测试 | 连续替换只保留当前菜单；重复事件不重建；同文不同定位动作使用新来源；取消清除而执行动作保留高亮 |
| 摘录输入与保存 | 同文件：取消 / 保存 / 空正文 / 重新打开，异步写入后卸载页面 | 无 controller 过早释放；标题正文修剪；原文、原书与完整 locator 保真，刷新原书 Notebook |
| 组件动作与响应式 | 同文件：桌面 / 移动动作映射、无图注禁用；必要时离屏截图 | 回调准确，原文预览与菜单可读，无溢出 |
| 实际消费者回归 | `test/widget_test.dart`、`test/features/reader/reader_search_pane_test.dart`、`test/features/reader/reader_notebook_test.dart` | 原搜索保存、文字 / 图片批注和 Notebook 行为保持 |
| 组织与产物 | 搬迁前后源码核对、命名文件 format、analyze、diff 检查、基线哈希及静默安装 | 无旧转发、悬空导入或 schema / 依赖变化；安装 bundle 对应本轮候选 |

### 第五轮实现与验证结果

- 新增 `reader_selection_actions.dart`（文字 / 图片选区动作组件及 presentation 枚举）、
  `reader_excerpt_editor.dart`（摘录草稿与输入生命周期）。原搜索笔记服务改名为
  `application/reader_excerpt_note_service.dart`，统一搜索片段与手写摘录的保存和原书籍查询刷新；
  全部实际消费者直接使用新归属，没有保留旧服务的兼容转发。阅读页从 5801 行变为 5343 行，
  仍持有菜单会话、浮层和业务动作编排，不以文件缩短作为正确性证明。
- 选区组件与页面剩余内容在初始迁出时逐字核对（仅改变公开名称和导入）；最后再次经过 formatter
  对齐核对组件正文，差异只有公开构造器的 key。最终页面相对迁出候选的差异另外审阅，包含以下
  已由反例证明的修复，不能将最终候选描述为纯搬迁。
- 修正测试夹具的窗口尺寸与剪贴板替身后，原实现 **1 项通过、6 项失败**，日志：
  `/tmp/pagesage-selection-baseline-confirmed.tucnx4Ys.log`。确认旧菜单 Future 会清空新菜单身份、
  同文但不同文件 / 偏移被误判为重复、摘录编辑器在退场前释放 controller，以及延迟保存仍依赖页面。
  菜单清理现受 epoch 约束；重复识别包含类型、文件、CFI 与字符范围，仍排除显示几何抖动；
  摘录使用 `TextFormField` 的内部输入生命周期，保存开始前捕获原书籍、来源和 application 服务。
- 移动端新增反例首轮 **1 项通过、1 项失败**，实际观察到两个 `BottomSheet`，日志：
  `/tmp/pagesage-selection-mobile-before.YiWM7hc6.log`。现使用原面板的监听值更新当前选区，
  动作读取最新来源，不为后续选择叠加路由；相关 notifier 和桌面 overlay 均由页面释放。
- 新增 `test/features/reader/reader_selection_actions_test.dart` 的 **12 项行为用例**，包含菜单替换与
  重复事件、文件 / 字符范围身份、几何抖动与复制、摘录取消 / 空正文 / 修剪 / 清空标题、页面卸载后的
  原书籍缓存刷新、移动面板替换与取消、两端全部文字动作及缺少图注时的禁用。
  来源和保存使用实际 repository、provider 及临时真实 SQLite；剪贴板使用平台替身，不访问用户剪贴板。
- 上述测试与 `test/widget_test.dart`、`reader_search_pane_test.dart`、`reader_notebook_test.dart`、
  `reader_providers_test.dart` 一次运行合计 **65 项通过**（12 项新增、53 项已有），日志：
  `/tmp/pagesage-selection-regression.iXhNbJ9v.log`。这是命名范围回归，不是全仓测试或独立验收。
  日志中原有 widget 夹具的 Drift 多实例警告在上一轮日志中也存在，本轮未屏蔽该警告；新增夹具显式
  使用临时内存库并释放 container / 连接。测试截图补上材质底色后，仅复跑受影响的 2 项组件用例通过，
  日志：`/tmp/pagesage-selection-captures.dus61aFu.log`，不重复计入 65 项。
- 实际查看 `build/workbench-captures/selection-desktop.png`（1280×900）与
  `selection-mobile.png`（390×844，1.4 倍文字），字体可读、动作无溢出或遮挡；这是组件离屏截图，
  不代表真实平台阅读验收。最终 `flutter analyze` 无问题，日志：
  `/tmp/pagesage-selection-final-analyze.lQVF4m6L.log`；6 个本轮 Dart 文件格式检查及
  `git diff --check` 通过。局部 import / export 可解析且应用依赖图无循环；依赖、schema 和生成文件
  相对开工快照的哈希保持不变，其他已有 Dart 文件未改。
- 已执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，静默构建与安装成功，日志：
  `/tmp/pagesage-selection-install.Fd8hGOyR.log`。整个 bundle 与 `<HOME>/.local/opt/pagesage`
  的 `diff -qr` 无差异；构建和安装的 `libapp.so` SHA256 均为
  `0ac56433b9d7eeef835d33cbddbb298eb5d1f77539265c23f663ae9687941962`。
  安装后再次核对依赖和数据库哈希不变；未打开、关闭或重启用户应用，未执行 Windows / Android 真机验证。

## 第六轮：OCR 叠加状态与 Markdown 阅读细节

用户要求继续做 Markdown / Typora 阅读体验并把阅读器结构收口。基线为
`/tmp/pagesage-md-typora-baseline.9x8I50`，阅读页 5343 行；本轮没有修改 IAM 源目录，
也没有制定多会话验收，所有实施与自测均在当前会话完成，不称为独立验收。

- 新增 `reader_ocr_overlay_controller.dart`：持有叠加令牌、当前页 / 块快照、双页待应用队列、
  会话内已恢复页集合与恢复代际。识别和缓存查询仍由阅读页发起，控制器只决定渲染器何时看到
  哪一页，避免令牌与块快照分别更新后错配。队列显式调度一帧，不依赖监听者恰好重建。
- 新增 `reader_ocr_result_sheet.dart`：桌面对话框与移动底部面板共用一套复制 / 问 AI 呈现，
  只接收页码、识别结果和宿主回调，不持有书籍、定位或识别流程；阅读页保留
  `_showAiPanel` 与当前 locator 的编排。
- 删除阅读页中的 `_flushPendingOcrOverlays`、五组 OCR 叠加字段与结果面板方法；阅读页从
  5343 行降到 5150 行。减少的行数只用于说明职责迁移，不作为正确性证明。
- Markdown 阅读同轮补 P8：任务列表只保留一个复选框标记，`taskChecked` 驱动真实图标；
  代码围栏的 `language-*` 进入 `codeLanguage` 并显示为面板右上角标签，不进入章节文本；
  分页器与渲染器共用 18 px 标签高度和 11 px 面板内边距。详见
  `docs/tasks/markdown-reading.md` 的 P8。

### 第六轮验证结果

| 待证明行为 | 检查 | 结果 |
| --- | --- | --- |
| 双页叠加逐帧应用、旧恢复失效、卸载后不通知 | `test/features/reader/reader_ocr_overlay_controller_test.dart` | 3 项 PASS：首帧令牌 1、下一帧令牌 2；新恢复代际使旧代际失效；dispose 后队列不再通知 |
| 任务列表 / 代码标签 / 分页高度 | `test/renderers/markdown/markdown_parser_test.dart`、`markdown_rendering_test.dart`、`test/renderers/epub/epub_paginator_test.dart` | 48 项 PASS；任务项只有 `☐` / `☑` 标记，渲染出 checkbox 图标；`dart` 标签可见且不在章节文本；带语言代码块多 18 px |
| 阅读器、OCR、搜索与笔记本回归 | `test/widget_test.dart`、`test/features/reader`、`test/features/ocr/ocr_current_page_use_case_test.dart`、上述 Markdown / 分页测试 | 157 项 PASS；日志 `/tmp/pagesage-reader-ocr-regression.log`。日志中的 Drift 多实例警告在本轮前已存在，未屏蔽 |
| 全仓格式 / 分析 / 测试 | `bash tool/check.sh` | PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 634 passed / 2 skipped；日志 `/tmp/pagesage-check-typora-ocr-20261109.log` |
| 真实窗口 Markdown | `flutter test integration_test/reader_markdown_test.dart -d linux`，离屏 `kwin_wayland --virtual` | 3/3 PASS；截图 `build/integration-captures/markdown-01-prose.png` 显示一个未完成、一个完成复选框和 `dart` 标签；日志 `/tmp/pagesage-md-integration.log`，未在用户桌面开窗 |
| 依赖、schema 与产物 | 基线哈希、`git diff --check`、静默安装、bundle 对比 | `pubspec.yaml` / `pubspec.lock` 哈希不变；`git diff --check` 通过；安装成功，bundle `diff -qr` 无差异 |

已执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`，Linux release 构建和本地安装
成功，日志 `/tmp/pagesage-install-typora-ocr-final-20261109.log`。最终构建与安装的 `libapp.so`
SHA256 均为 `8149b29f2c4c67a4b368e37cf7a79911b12da4f993411e739c34d9e7fa9ecdf0`。未启动、关闭或
重启用户应用，已有进程需用户重启加载新版；Windows / Android 按用户要求暂不处理。

第六轮实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS` + `RUNTIME_PASS`（离屏虚拟 Wayland），
安装版 `E2E` 仍 `BLOCKED`。

### 第七轮：阅读器通用 chrome、PDF 工具条与状态栏拆分（2026-11-09）

本轮只搬动界面边界，不改阅读行为、事件、locator 或持久化：

- `reader_chrome.dart`：`ReaderToolbarButton`、`ReaderFloatingChrome`、
  `ReaderChromeRevealButton`、`ReaderBottomSheetFrame`、`QuickThemeChip`、
  `PanelResizeHandle`。这些组件被桌面工具条、移动端顶/底栏和 PDF 工具条共同使用。
- `reader_pdf_toolbar.dart`：`PageJumpDialog`、`PdfQuickToolbar`、`PdfToolbarChip`、
  `PdfToolbarIconButton`。页码弹窗的控制器生命周期保持原样。
- `reader_status_widgets.dart`：`ReaderStatusBar`、`ReaderErrorPanel`、`ReaderMessage`、
  `ImageBoxModeBanner`、`ReaderStatusBanner`。
- `reader_location_text.dart`：`readerLocationText`、`readerScaleText`、
  `readerFormatLabel`，供移动端、桌面状态栏与后续面板复用。
- 公开组件统一补 `super.key`；`reader_page.dart` 从 4913 行降到 4127 行，减少的部分是
  已迁出的职责，不作为正确性证明。阅读页仍保留工作台编排、文件夹会话、菜单动作和渲染宿主装配。

| 待证明行为 | 检查 | 结果 |
| --- | --- | --- |
| 阅读器、书库与离屏界面回归 | `flutter test test/widget_test.dart test/features/reader test/ui_screenshots_test.dart --concurrency=4` | PASS：99 项；日志 `/tmp/pagesage_reader_split_tests2.log` |
| 格式 / 分析 / 全仓回归 | `bash tool/check.sh` | PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 693 项通过 / 2 skipped；日志 `/tmp/pagesage_check_reader_split.log` |
| 发布准备 | `flutter test test/tool/release_readiness_test.dart --concurrency=4` | PASS：6 项通过 / 2 skipped；日志 `/tmp/pagesage_release_reader_split.log` |
| 本地安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle `diff -qr`、SHA256 | PASS：日志 `/tmp/pagesage_install_reader_split.log`；构建与安装 `libapp.so` 均为 `30a2181de8f7a93556272935fe55aae115204da9879f411c98cc2e38b82f8445` |

第七轮实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。安装后已重启本地实例
（PID `747016`，启动日志 `/tmp/pagesage_restart.log`）；真实窗口与 Windows / Android 仍未验证。

### 第八轮：移动端阅读 chrome 拆分（2026-11-09）

- 新增 `reader_mobile_chrome.dart`：`MobileReaderTopBar`、`MobileReaderBottomBar`、
  `MobileReaderMoreSheet`、`MobileMoreChip`、`MobileReaderActionButton` 与
  `ReaderMoreAction`。
- 阅读页只保留动作分发与面板编排；移动端组件通过显式回调连接，行为、文案、页签和
  “更多”菜单顺序保持不变。
- `reader_page.dart` 从 4127 行降到 3541 行。减少的行数用于说明职责迁移，不作为正确性证明。

| 待证明行为 | 检查 | 结果 |
| --- | --- | --- |
| 阅读器、书库与离屏界面回归 | `flutter test test/widget_test.dart test/features/reader test/ui_screenshots_test.dart --concurrency=4` | PASS：101 项；日志 `/tmp/pagesage_mobile_split_tests.log` |
| 格式 / 分析 / 全仓回归 | `bash tool/check.sh` | PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 695 项通过 / 2 skipped；日志 `/tmp/pagesage_check_mobile_split.log` |
| 发布准备 | `flutter test test/tool/release_readiness_test.dart --concurrency=4` | PASS：6 项通过 / 2 skipped；日志 `/tmp/pagesage_release_mobile_split.log` |
| 本地安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle `diff -qr`、SHA256 | PASS：日志 `/tmp/pagesage_install_mobile_split.log`；构建与安装 `libapp.so` 均为 `41f7acd0ef436d2b1e878274277b9d64a4b33ebdefdfafd659194febada0dfb7` |

第八轮实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。安装后已重启本地实例
（PID `822529`，启动日志 `/tmp/pagesage_restart.log`）；真实窗口与 Windows / Android 仍未验证。

### 第九轮：目录组件按载体拆分（2026-11-09）

本轮继续使用 `review-code-organization` 与 `pagesage-dart-engineering`，只搬迁目录组件的职责，
不改变筛选、展开、自动滚动、页码选择和 locator 语义：

- `reader_toc_tree.dart`：共享的目录行模型、文件夹行模型、展开 / 筛选遍历、祖先展开与父目录副标题。
- `reader_desktop_toc_pane.dart`：桌面目录面板、筛选防抖、文件 / 大纲页签、当前章节 / 页码滚动与
  EPUB、PDF、Markdown 文件夹跳转。
- `reader_epub_toc_sheet.dart`：移动端 EPUB 与 Markdown 文件夹目录、文件树和当前文件大纲。
- `reader_pdf_toc_sheet.dart`：移动端 PDF 大纲 / 页码回退与单一活动项规则。
- 删除原 `reader_toc.dart` 聚合文件；阅读页与面板测试直接导入实际实现，不保留转发层。
  阅读页仍为会话与工作台编排，组件文件行数不作为正确性证明。

| 待证明行为 | 检查 | 结果 |
| --- | --- | --- |
| 目录展开、筛选、精确跳转、移动端祖先展开、PDF 单一活动项 | `test/features/reader/reader_panels_test.dart` | PASS：7 项；日志 `/tmp/pagesage-toc-panels-tests.log` |
| 阅读器、书库与离屏界面回归 | `flutter test test/widget_test.dart test/features/reader test/ui_screenshots_test.dart --concurrency=4` | PASS：101 项；日志 `/tmp/pagesage_toc_split_tests.log` |
| 发布准备 | `flutter test test/tool/release_readiness_test.dart --concurrency=4` | PASS：6 项通过 / 2 项跳过；日志 `/tmp/pagesage_toc_release_tests.log` |
| 格式 / 分析 / 全仓回归 | `bash tool/check.sh` | PASS：`dart format` 0 改动、`flutter analyze` 0 问题、`flutter test` 695 项通过 / 2 skipped；日志 `/tmp/pagesage_check_toc_split.log` |
| 本地安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle `diff -qr`、SHA256 | PASS：bundle 与安装目录一致；构建及安装 `libapp.so` 均为 `6d9fdd66b8c9dafc7630478c4f97d8f4a1245399a925b9f427aa5735915918be`；日志 `/tmp/pagesage_install_toc_split.log` |

第九轮实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。安装后已重启本地实例
（PID `924970`，启动日志 `/tmp/pagesage_restart.log`）；真实窗口与 Windows / Android 仍未验证。

### 第十轮：批注渲染宿主拆分（2026-11-09）

`_ReaderAnnotationsHost` 原本位于阅读页，负责订阅当前书籍批注并装配
`ReaderRendererHostConfig`。本轮将其迁为独立的 `reader_annotations_host.dart`：

- 组件改为公开 `ReaderAnnotationsHost` 并补 `super.key`；字段、默认值和
  `ReaderRendererHostConfig` 参数保持原样。
- 阅读页只传入书籍、进度、设置、事件与 OCR 叠加等会话数据，不再持有批注订阅实现。
- 删除批注宿主后清理阅读页两个失去消费者的导入；没有新增 Provider、缓存或转发层。
- `reader_page.dart` 从 3543 行变为 3467 行，新增宿主 87 行；行数变化只用于说明职责迁移。

| 待证明行为 | 检查 | 结果 |
| --- | --- | --- |
| 分析器与阅读器回归 | `flutter analyze`、`flutter test test/features/reader test/widget_test.dart --concurrency=4` | PASS：分析无问题，100 项测试通过；日志 `/tmp/pagesage_annotations-analyze2.log`、`/tmp/pagesage_annotations-tests.log` |
| 格式 / 全仓回归 | `bash tool/check.sh` | PASS：格式 0 改动、分析 0 问题、695 项通过 / 2 skipped；日志 `/tmp/pagesage_check_annotations_host.log` |
| 本地安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle `diff -qr`、SHA256 | PASS：bundle 一致；构建及安装 `libapp.so` 均为 `fef188b4891c98e8074f4c086dafddd48c48a4f7a2258499abbce115add40172`；日志 `/tmp/pagesage_install_annotations_host.log` |

第十轮实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。安装后已重启本地实例
（PID `947006`，启动日志 `/tmp/pagesage_restart.log`）；真实窗口与 Windows / Android 仍未验证。

## 第十一轮：图片批注菜单与裁图流程（2026-11-10）

继续按实际职责拆阅读页中的图片批注路径，保留共用浮层的状态所有权和现有用户交互：

- 新增 `reader_image_actions.dart`，收纳图片动作枚举、桌面浮动菜单内容及移动端底部菜单；文字与图片菜单仍共用阅读页维护的 overlay 清理与定位生命周期。
- 新增 `application/reader_image_annotation_service.dart`，负责图片批注持久化、PDF 区域渲染与标注图缓存。批注先写入，缓存随后异步生成；区域渲染或缓存失败不回滚批注。
- 阅读页保留动作选择编排、保存路径选择和短暂状态提示；清除原有底部菜单构造与裁图缓存实现。
- 不改数据库、图片锚点、locator、文件格式和导出契约；没有新增依赖。

| 待证明行为 | 检查 | 结果 |
| --- | --- | --- |
| 服务保存顺序与失败隔离 | `test/features/reader/reader_image_annotation_service_test.dart` | PASS：3 项；证明先保存再渲染 / 缓存，缓存渲染失败仍保留批注，缺少渲染源时返回空结果 |
| 菜单动作与图注禁用态 | `test/features/reader/reader_selection_actions_test.dart` | PASS：12 项；图片菜单单项回归通过 |
| 页面图片批注和缓存闭环 | `test/widget_test.dart` 三个图片标注命名用例 | PASS：3 项；锚点、定位、颜色及导出缓存保持 |
| 全仓格式 / 分析 / 回归 | `bash tool/check.sh` | PASS：格式、分析无问题；709 项通过 / 2 skipped，日志 `/tmp/pagesage_check_image_split.log` |
| 安装包与当前运行实例 | `bash tool/install_linux.sh`、bundle diff、SHA256 与重启 | PASS：bundle `diff -qr` 无差异；构建与安装 `libapp.so` SHA256 均为 `afbaafffc9eed4610f7fb9ba31578c179faf97003ee9ab271a945d4508a7392f`；已重启本地实例（PID `3906458`） |

第十一轮实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。全仓格式 / 分析 / 测试 709 项通过、2 项跳过；发布准备 6 项通过、2 项因本地 Android APK / AAB 构建产物缺失而跳过。安装日志 `/tmp/pagesage_install_image_split.log`，启动日志 `/tmp/pagesage_restart.log`。真实窗口视检与 Windows / Android 仍未验证。

## 第十二轮：阅读器 OCR 编排拆分（2026-11-10）

继续按实际调用边界拆分 OCR，不改变用户可见行为、OCR 引擎、缓存格式、数据库或 locator：

- 新增 `application/reader_ocr_coordinator.dart`，集中处理可见页解析、显示页导出、空图
  180 ms 重试和缓存叠加查询。
- `readerOcrCoordinatorProvider` 复用 `OcrPageController`；阅读页只保留识别状态提示、
  结果面板、问 AI 和 overlay 应用。
- `_runOcrCurrentPage` 删除页面发现、导出与重试代码；`_restoreOcrOverlaysForVisiblePages`
  删除逐页缓存循环。翻页 / 卸载后的失效检查仍由阅读页 generation 控制。
- 新增 6 项协调器行为测试：可见页回退、双页导出重试、无渲染源时省略导出、只恢复有几何且
  未绘制的页、翻页后停止恢复，以及 provider 到 OCR 引擎的真实接线。
- 未改 OCR 平台实现；Linux 仍为 stub，Windows / Android 未验证。

| 待证明行为 | 检查 | 结果 |
| --- | --- | --- |
| 阅读器与 OCR 回归 | `flutter test test/features/reader --concurrency=4`、`flutter test test/widget_test.dart --concurrency=4` | PASS：阅读器 82 项、widget 29 项；日志 `/tmp/pagesage-reader-ocr-split-verify.log` |
| 全仓格式 / 分析 / 测试 | `bash tool/check.sh` | PASS：格式、分析无问题；715 项通过 / 2 skipped；日志 `/tmp/pagesage-check-ocr-split-verify.log` |
| 本地安装 | `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`、bundle `diff -qr`、SHA256 | PASS：bundle 与安装目录一致；构建及安装 `libapp.so` 均为 `920a1b32ca1d009c3f6d184a01c33e124296dd8faaa368abb93c87d73f8aa586`；日志 `/tmp/pagesage-install-ocr-split.log` |

第十二轮实现状态：`IMPLEMENTED`；验证证据：`TOOLING_PASS`。安装时未检测到运行中的
PageSage 进程，因此未启动新窗口；真实窗口视检与 Windows / Android 仍未验证。全仓测试日志
仍包含既有 Drift 多实例 debug 警告，本轮未改测试数据库装配，也未屏蔽该警告。补充 provider
测试只改测试文件，应用源码未变，安装产物仍为上面的 `libapp.so` 哈希。
