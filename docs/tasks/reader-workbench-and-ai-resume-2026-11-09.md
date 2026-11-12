# 阅读工作台与 AI 会话恢复（2026-11-09）

## 范围与约定

- 延续已确认的阅读工作台收口、完整 AI 会话与来源恢复；不扩展检索算法或 Provider。
- 连续滚动不再叠加底部翻章胶囊，翻章仍可通过目录和既有阅读操作完成；正文已有同名标题时不重复生成章节标题。
- 保存桌面右侧当前工具页签，重新打开阅读器恢复；保留 Markdown 文件树与单文件大纲的既有分工。
- 每轮持久化实际发送的结构化引用快照：范围、截断状态、引用 ID、书籍、定位、正文及来源区间。旧记录无快照则明确标为旧版上下文，不推测来源。
- 恢复任一历史轮次时载入同书同线程的全部轮次，按保存顺序继续最新一轮；读取本地历史不调用模型。无 thread_id 的旧记录保持独立，后续续问使用该记录 ID 归组。
- 编辑引用开启新线程，编辑后的正文不再声称与原来源区间逐字对应；原 locator 仅保留为来源跳转。
- 笔记保存保留原回答的定位、上下文及会话关联；结构化来源仍由关联会话持有，导出 AI 记录时携带来源快照。

## 契约清单

| 权威来源 | 消费端 | 变更与兼容性 |
| --- | --- | --- |
| domain AI 引用/快照模型 | 引用编辑、ChatService、Drift 映射、面板、导出、测试替身 | 应用层旧导入路径保留 re-export；字段可空表示旧记录 |
| AiConversation.contextSnapshot | SQLite ai_conversations、生成代码、迁移、备份 | v6→v7 增加 nullable context_snapshot；不清空或回填猜测来源 |
| ReaderSettings.desktopContextTab | JSON 设置、reader_page | 新枚举值 search/notebook/ai；旧设置默认 search |
| EPUB/Markdown 连续渲染 | 章节标题、连续滚动操作、组件测试 | 去重同名标题；删除正文上的浮动翻章控件 |

## 验证矩阵（写入前声明）

| 命名验证 | 精确入口 | 要拒绝的缺陷 / 预期 |
| --- | --- | --- |
| 来源往返 | test/features/ai/ai_context_reference_test.dart | 跨书 ID、定位、来源区间丢失；编辑后伪称精确区间；未知快照版本不可静默伪造 |
| 真实 SQLite 升级与重开 | test/core/database/ai_context_snapshot_test.dart | v6 数据丢失、旧记录伪造引用、新快照无法跨连接恢复 |
| 历史续问 | test/features/ai/ai_panel_thread_test.dart | 只恢复选中一轮、跨书/跨线程串话、编辑后复用旧线程、恢复触发网络 |
| 历史读取失败 | 同文件 history read failure is visible instead of claiming no history | 读取/解码失败不能伪装成没有历史 |
| 保存恢复的回答 | 同文件 saving restored answer keeps its original locator and conversation link | 原始定位被当前页替换、上下文或会话关联丢失；通过真实 Drift 笔记仓库验证 |
| 请求保存与取消 | test/features/ai/ai_chat_service_test.dart | 快照与请求脱节、取消产生完整历史记录 |
| 工作台设置恢复 | test/domain/books/reader_settings_test.dart；test/widget_test.dart 的命名阅读器用例 | 页签未序列化、点击页签不保存、重开恢复错误 |
| 连续阅读布局 | test/renderers/markdown/markdown_rendering_test.dart；test/renderers/epub/epub_image_rendering_test.dart | 标题重复、浮动翻章覆盖正文；paged Markdown keeps chapter controls inside its layout 另外证明分页导航仍在页内 |
| 来源导出 | test/features/export/export_service_test.dart | AI Markdown 导出丢失来源与定位 |

测试使用合成正文和临时 SQLite，不访问用户书库或调用远端模型。命令限命名文件/用例、并发 4，静默执行；UI 使用无可见窗口的截图测试。另运行 format/analyze、Drift 生成、Linux release 安装与 bundle 校验。已有迁移测试需同步回退新增列，保留原语义断言。

## 执行记录

- Implementation State: IMPLEMENTED
- Validation Evidence: RUNTIME_PASS（真实本地 SQLite 迁移、磁盘重开与笔记写入）；控件/模拟 Provider 边界为 TOOLING_PASS，未声称整条桌面真实进程或远端模型 E2E。

### 命令与结果

- `dart run build_runner build --delete-conflicting-outputs`：成功生成 Drift 代码；当前 build_runner 提示该选项已弃用并忽略，实际生成成功。只有数据库生成文件出现相关追踪变更。
- 首轮按矩阵运行十个命名测试文件：60 通过、2 失败。失败是新增断言把唯一原文标题误写成不存在，以及使用了错误的编辑按钮 tooltip；均已修正。首轮中来源往返、v3/v4/v5/v6 升级、磁盘 SQLite 重开、设置序列化的有效 PASS 予以复用。
- `flutter test --concurrency=4 --dart-define=CAPTURE_READER_WORKBENCH=true test/features/ai/ai_panel_thread_test.dart test/features/ai/ai_chat_service_test.dart test/renderers/markdown/markdown_rendering_test.dart test/features/export/export_service_test.dart`：35 通过。日志 `/tmp/pagesage-ai-resume-tests-final.log`。截图辅助代码初次编译缺少 ValueKey 导入，修正后此轮全通过。
- `flutter test --concurrency=4 test/features/ai/ai_panel_context_test.dart test/features/ai/ai_panel_cross_book_test.dart test/features/ai/ai_thread_messages_test.dart test/renderers/epub/epub_image_rendering_test.dart`：26 通过。日志 `/tmp/pagesage-ai-resume-dependents.log`。
- `flutter test --concurrency=4 test/widget_test.dart --name 'desktop reader restores and saves the active tool tab|desktop reader keyboard shortcuts open panels and actions|desktop reader keyboard shortcuts navigate search and zoom PDF'`：3 通过。既有 PDF 模拟用例有缺少 path_provider 平台实现的调试警告，不当作 PDF 真机证据。新页签用例随后改用 RendererReady 事件，避免无关 OCR 查询；一次试用虚拟 EPUB 文件导致等待真实文件的测试超时，已回到隔离的 PDF 工具面板夹具。
- 增补历史读取失败提示后：`flutter test --concurrency=4 --dart-define=CAPTURE_READER_WORKBENCH=true test/features/ai/ai_panel_thread_test.dart`：7 通过，日志 `/tmp/pagesage-ai-resume-thread-final.log`。此轮同时断言续问沿用 old.xhtml 第四章，而非当前阅读页；旧记录未知定位保持 null。
- 最后补充分页布局和测试替身字段传递：`flutter test --concurrency=4 test/widget_test.dart test/renderers/markdown/markdown_rendering_test.dart test/features/export/export_service_test.dart --name 'desktop reader restores and saves the active tool tab|paged Markdown keeps chapter controls inside its layout|AI and notebook exports preserve structured cross-book sources'`：3 通过，日志 `/tmp/pagesage-workbench-final-regression.log`。
- `flutter test --concurrency=4 test/features/ai/ai_panel_thread_test.dart --name 'saving restored answer keeps its original locator and conversation link'`：1 通过，日志 `/tmp/pagesage-ai-restored-note.log`。该检查通过真实 Drift/SQLite 保存笔记，断言原始 locator、问题、回答、上下文和会话到笔记的关联。
- 按本轮涉及的 Dart 文件格式化；`flutter analyze` 无问题；`git diff --check` 通过。未对其他已有变更做全局格式归一。

### 视觉检查与安装

- 无窗口截图并目视检查：`build/workbench-captures/markdown-continuous.png`（1200×800）、`ai-restored-sources.png`（520×1100）、`ai-restored-rail.png`（420×860）。确认同名标题只保留一次、连续正文无底部翻章遮挡、恢复的来源/旧轮次入口/发送按钮均在布局内。截图使用控件夹具，不能替代整机主题、长文滚动或触屏验收。
- 执行 `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh`；补充历史错误提示后再次执行，最后日志 `/tmp/pagesage-ai-resume-install-final.log`。均构建并安装成功，没有启动或重启 PageSage。
- `diff -qr build/linux/x64/release/bundle <HOME>/.local/opt/pagesage` 无差异；构建与安装的 libapp.so SHA256 均为 `adf3d660291ac3ded5712c022ff0465b349e5081f1032e92f2f420043af70629`。最终生产代码变更后已重新安装；随后仅补充测试与文档。

### Contract Closure Matrix

| 契约/消费者 | 结论 | 证据与边界 |
| --- | --- | --- |
| domain 引用/快照与应用层旧导入路径 | VERIFIED | 来源字段 JSON 往返、未知版本失败、编辑后撤销精确区间；应用层 re-export 保留所有既有引用调用方 |
| ChatService / Provider 输入 / 历史恢复 | VERIFIED | payload 与快照一致性、完整轮次顺序、同书同线程过滤、恢复不调用 Provider、取消不保存完成记录；远端模型效果不在本轮声明内 |
| Drift schema、生成文件、迁移与仓库 | VERIFIED | v6→v7 保留上下文/线程/笔记关联，旧来源为 null；实际磁盘数据库关闭重开保留结构化引用，时间相同仍按插入先后恢复 |
| AI 面板与跨书路由 | VERIFIED | 精确来源标签/locator 恢复，跨书打开原书第 42 页，历史读取错误不是空历史，异步恢复不向当前页面伪造位置 |
| 笔记保存、AI/Notebook 导出 | VERIFIED | 实际 SQLite 笔记保存原位置与上下文，会话持有来源快照；两种导出包含完整来源快照。未新增独立 notes.references 字段 |
| ReaderSettings 与 reader_page | VERIFIED | JSON 兼容默认、页签点击保存、卸载控件后重开仍恢复 AI 工具；搜索/缩放快捷键既有验证继续适用 |
| EPUB/Markdown 共同连续渲染与分页消费者 | VERIFIED | 连续渲染同名标题去重和遮挡去除，图文回归；单独分页用例证明导航仍在页内 |
| repository 测试替身 | VERIFIED | widget_test、ui_screenshots_test、export_service_test、ai_chat_service_test、ai_panel_thread_test 均接受并传递快照与线程字段 |
| 数据库 ZIP 备份 / 恢复 | NOT_AFFECTED | 既有路径打包 SQLite 文件而非按旧列名单重建表；新增列随数据库文件保留，没有修改 ZIP 契约 |
| Linux 官方本地安装入口 | VERIFIED | release 构建及安装脚本成功，整个 bundle 与安装目录一致；运行中的旧进程保持不动 |

### 仍未验证的范围

- Windows/Android 真机、运行中的真实书库升级、真实 Provider 的完整答案质量、本轮后的 30 分钟阅读体验未执行。请重启现有 PageSage 后进行真实使用验证，不能用控件或构建 PASS 代替这些结论。
- 旧会话未存储的来源无法事后还原；外部 Markdown 文件变化后，快照仅证明当时发送内容，不能证明当前文件未变。
- 单独笔记仅沿用既有 source_text/locator/会话关联，未扩展独立多来源笔记模型；若清空关联 AI 历史，结构化来源需由此前的 AI/Notebook 导出保留。
