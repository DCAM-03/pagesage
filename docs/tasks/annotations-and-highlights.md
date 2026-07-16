# TASK-11：划线、高亮、选区定位和渲染

## 目标

实现阅读中的文本标注能力，让用户能选中文本后添加高亮或下划线，修改样式，删除标注，并在重启后恢复渲染。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`、`docs/06-data-model.md`。
- 不做：手写批注、图形批注、扫描版 PDF OCR 标注。
- 约束：EPUB 以 href/chapter/progress 定位为主，CFI 可后续增强；PDF 坐标高亮可渐进增强，但必须先保存文本和页码定位。

## 功能范围

- 文本选择菜单。
- 高亮颜色：yellow、blue、green、red、purple。
- 样式：highlight、underline。
- 创建、修改、删除标注。
- 从标注创建笔记。
- 标注列表和阅读器渲染恢复。
- 标注参与搜索或笔记联动。

## 实现任务

- [x] 建立 `Annotation` domain model 和 repository。
- [x] 实现 `AnnotationDao`。
- [x] 文本选择后显示浮动菜单或右键菜单。
- [x] 高亮操作保存 selected_text、locator、color、style。
- [x] EPUB renderer 支持 applyAnnotations 和 removeAnnotation。
- [x] PDF renderer 支持文本层可用时保存页码和选区信息，坐标渲染可分阶段完成。
- [x] 支持修改高亮颜色和样式。
- [x] 支持删除标注，若关联 note 需确认是否保留笔记。
- [x] 支持从高亮创建笔记，并写入 `note_id` 关联。
- [x] 阅读器加载时按书籍读取所有标注并注入 renderer。
- [x] 标注点击打开操作菜单或关联笔记。
- [x] 夜间模式下降低高亮饱和度，保证文字可读。

## 涉及模块和文件

- `lib/domain/annotations/annotation.dart`
- `lib/domain/annotations/annotation_repository.dart`
- `lib/core/database/daos/annotation_dao.dart`
- `lib/features/reader/presentation/widgets/text_selection_menu.dart`
- `lib/features/reader/presentation/widgets/annotation_menu.dart`
- `lib/features/reader/application/reader_controller.dart`
- `lib/renderers/epub/epub_renderer_view.dart`
- `lib/renderers/common/renderer_event.dart`
- `assets/renderer/pdf/bridge.js`
- `test/features/reader/annotations_test.dart`

## 数据与接口

- `annotations.selected_text` 保存用户选中文本。
- `annotations.locator` 保存稳定定位。
- `annotations.color` 使用受控枚举。
- `annotations.style` 使用受控枚举。
- `annotations.note_id` 可为空。
- Renderer event 需要提供 `textSelected`，包含 selectedText 和 locator。

## UI 与交互

- 移动端选中文本后显示：高亮、笔记、复制、AI、更多。
- 桌面端右键菜单显示：高亮、添加笔记、复制、在本书搜索、全局搜索、AI。
- 高亮颜色使用色块，不只用文字。
- 未选中文本时不显示文本相关操作。
- PDF 无文本层时提示无法选择文本。

## 验收标准

- [x] EPUB 选中文本后可以添加高亮。
- [x] 标注重启后仍显示。
- [x] 可以修改颜色或下划线样式。
- [x] 可以删除标注。
- [x] 从标注创建笔记后关联关系正确。
- [x] 删除标注不会无提示删除关联笔记。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 单元测试：annotation 枚举、locator 序列化、删除规则。
- 手动验证：EPUB 标注恢复、PDF 文本层可用时选词、PDF 文本层缺失降级。

## 依赖与风险

- 依赖：TASK-02 annotations 表，TASK-05 reader core，TASK-06/TASK-07 文本选择事件。
- 依赖：TASK-12 笔记关联。
- 风险：PDF 高亮坐标跨缩放和页面尺寸恢复较复杂，需要分阶段验收。
