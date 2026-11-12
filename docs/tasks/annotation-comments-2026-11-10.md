# 标注批注（Word 式，2026-11-10）

## 目标

让读者选中一段文字后直接写批注，并在阅读器内点击已有划线或高亮查看、编辑，不必先进入笔记页。

## 范围与约定

- 选区菜单新增独立「批注」；创建时先保存标注，再保存关联批注。任一步失败都尽量清理已写入的数据。
- 批注使用 `NoteType.comment`，复用 `annotations.note_id` 与 `notes.annotation_id`，不新增数据库列或迁移。
- 点击标注后，桌面显示浮动卡片，移动端显示底部面板；已有批注直接显示正文。
- 已有批注时可以只删除批注并保留划线；删除后清空标注的 `note_id`，Notebook 会立即去掉批注标记。
- 删除标注时，只有 `NoteType.comment` 的关联笔记随标注删除；普通关联笔记保留，并在确认框中说明。
- Notebook 将批注显示在对应标注条目的副标题中，不再额外列出重复条目。
- 第一版不绘制页边批注气泡，也不支持自由手写批注。

## 契约清单

| 权威来源 | 消费端 | 变更与兼容性 |
| --- | --- | --- |
| `NoteType.comment` | 笔记页、Notebook、批注服务、导出 | 文本列新增枚举值，无 schema 变更；旧数据不受影响 |
| `ReaderAnnotationCommentService` | 选区动作、标注浮层、Notebook | 创建 / 更新 / 只删批注、查询批注、查询任意关联笔记、删除标注 |
| `AnnotationRepository.unlinkNote` | Drift 仓储、笔记页、测试替身 | 清空标注的 `note_id` 而不删除标注，无 schema 变更 |
| `annotations.note_id` | 标注浮层、Notebook、删除规则 | 只把 `comment` 类型解释为批注；普通笔记关联保持原语义 |
| `ReaderSelectionAction.comment` | 桌面选区条、移动底部面板、阅读页动作 | 新增动作，原有高亮 / 下划线 / 笔记 / 搜索 / 复制 / AI 不变 |

## 验证矩阵

| 命名验证 | 精确入口 | 要拒绝的缺陷 / 预期 |
| --- | --- | --- |
| 选区创建批注 | `test/features/reader/reader_selection_actions_test.dart` | 只创建批注笔记不创建标注、原文 / locator 丢失、点击划线看不到正文 |
| 批注只关联一次 | `test/features/reader/reader_notebook_test.dart` | 反复编辑生成多条笔记、关联 id 丢失、Notebook 刷新失败 |
| 删除批注标注 | 同文件 `deleting a comment annotation removes its comment note` | 批注笔记成为孤儿、普通关联笔记被误删 |
| 只删批注 | 同文件 `deleting only a comment keeps the annotation and clears its link`；`test/core/database/annotation_repository_test.dart` | 划线被误删、`note_id` 残留、Notebook 仍显示批注 |
| 普通关联笔记 | 同文件 `image deletion confirms, drops the cache and keeps linked notes` | 普通笔记被当作批注、Notebook 重复显示、删标注时误删笔记 |
| 阅读器回归 | `test/widget_test.dart` | 选区菜单、图片批注、阅读器工具页签和既有标注交互回归 |

## 执行记录

- Implementation State: IMPLEMENTED
- Validation Evidence: TOOLING_PASS（真实 SQLite 内存库、Flutter 控件与模拟阅读器事件）；真实窗口与平台手测未执行。
- `flutter analyze`：无问题。
- 聚焦测试：批注 / Notebook / 标注仓储 / 阅读器 widget 57 项通过。
- 全仓门禁：`bash tool/check.sh` 通过，730 项通过（2 skipped）。
- Linux 安装：`CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 成功；bundle 与 `~/.local/opt/pagesage` 无差异，`libapp.so` SHA256 为 `8f33c19514e1396341254da780697ccffdb71df849a41933c0a508640652a994`。安装时没有运行中的 PageSage 进程。

## 仍未验证

- 真实 EPUB / PDF / Markdown 窗口中的长时间批注阅读。
- 很长批注在桌面浮动卡片和移动底部面板中的布局。
- Windows 与 Android 的触屏、键盘和平台外观。
