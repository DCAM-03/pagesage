# TASK-09：分类树、标签和多条件筛选

## 目标

实现书库组织能力：分类目录树用于单一主分类，标签用于多对多标记，并与书库筛选、详情、搜索和笔记联动。

## 来源与边界

- 来源：`docs/02-feature-spec.md`、`docs/03-interaction-spec.md`、`docs/06-data-model.md`。
- 不做：云端分类同步、多人共享分类。
- 约束：删除分类不删除书籍；一本书只有一个主分类，可以有多个标签。

## 功能范围

- 默认系统分类。
- 自定义分类和子分类。
- 分类重命名、删除、排序。
- 书籍移动分类。
- 标签创建、改名、颜色、删除。
- 给书籍添加和移除标签。
- 按分类和标签筛选书库。
- 笔记标签基础联动。

## 实现任务

- [x] 建立分类和标签 repository。
- [x] 系统分类策略：全部书籍、最近阅读、收藏、未分类、已读。
- [x] 支持新建分类。
- [x] 支持分类重命名。
- [x] 支持分类排序。
- [x] 删除分类时确认并默认移入未分类。
- [x] 删除分类时提供目标迁移选择。
- [x] 支持将一本书移动到分类。
- [x] 支持创建标签。
- [x] 支持书籍菜单中添加和移除标签。
- [x] 支持标签重命名和颜色编辑。
- [x] 标签名唯一校验。
- [x] 删除标签时解除关联，不删除书籍或笔记。
- [x] 书库查询支持分类、系统分类和标签组合筛选。
- [x] 桌面端分类树支持展开、折叠和键盘导航。
- [x] 移动端分类入口使用抽屉或下拉。

## 涉及模块和文件

- `lib/domain/books/category.dart`
- `lib/domain/books/tag.dart`
- `lib/domain/books/category_repository.dart`
- `lib/domain/books/tag_repository.dart`
- `lib/core/database/daos/category_dao.dart`
- `lib/core/database/daos/tag_dao.dart`
- `lib/features/library/presentation/widgets/category_tree.dart`
- `lib/features/library/presentation/widgets/tag_editor.dart`
- `lib/features/library/application/library_controller.dart`
- `test/features/library/categories_and_tags_test.dart`

## 数据与接口

- `categories.parent_id` 表示目录树。
- `categories.sort_order` 控制同级排序。
- `books.category_id` 保存主分类。
- `tags.name` 唯一。
- `book_tags` 保存书籍和标签关系。
- `note_tags` 预留或实现笔记标签关系。

## UI 与交互

- 桌面左侧栏展示分类目录树。
- 移动端书库顶部提供分类筛选入口。
- 标签显示为小胶囊，带颜色点。
- 删除分类需要确认，并说明不删除书籍。
- 删除标签需要确认，并说明只解除标记。
- 标签颜色不能作为唯一状态表达。

## 验收标准

- [x] 分类树重启后保持。
- [x] 一本书移动分类后书库立刻更新。
- [x] 删除分类不会删除书籍。
- [x] 标签筛选结果正确。
- [x] 标签重命名后所有关联位置同步显示。
- [x] 系统分类与自定义分类行为清晰区分。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 单元测试：分类树构建、循环 parent 防护、标签唯一性。
- Widget 测试：分类树、标签编辑器、删除确认。

## 依赖与风险

- 依赖：TASK-02 categories/tags/book_tags/note_tags。
- 依赖：TASK-04 书库筛选和详情。
- 风险：系统分类若落库和自定义分类混用，需要 reserved 标识或稳定 ID 策略。
- 风险：分类树删除和迁移规则不清会造成用户误解。
