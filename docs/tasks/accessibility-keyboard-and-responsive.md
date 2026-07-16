# TASK-21：可访问性、快捷键和响应式

## 目标

确保 PageSage 在移动端、平板和桌面端都具备可访问、可键盘操作、响应式稳定的体验，满足阅读和知识管理场景的长期使用要求。

## 来源与边界

- 来源：`docs/03-interaction-spec.md`、`docs/04-ui-design-system.md`、`docs/08-ui-ux-redesign-plan.md`、`docs/09-design-system.md`、`docs/testing-ui-ux-checklist.md`。
- 不做：完整屏幕阅读器专项适配认证，但必须满足基础语义和键盘可达。
- 约束：文字不能溢出或重叠；颜色不能作为唯一状态表达。

## 功能范围

- 响应式断点：compact、medium、expanded。
- 移动端单列和底部导航。
- 桌面端三栏布局。
- 键盘快捷键。
- 焦点管理。
- 语义标签。
- tooltip。
- 高对比主题。
- 动画减少。
- 文本溢出防护。
- UI/UX 现代化阶段的截图、主题和真实样本验收。

## 实现任务

- [x] 建立响应式布局工具或 breakpoint helper。
- [ ] compact 使用底部导航、单列页面、阅读器全屏、底部抽屉。
- [ ] medium 支持双栏和侧边目录抽屉。
- [ ] expanded 使用左侧导航、中间主内容、右侧上下文面板。
- [ ] 实现桌面快捷键：Ctrl+O、Ctrl+F、Ctrl+Shift+F、Ctrl+B、Ctrl+Plus、Ctrl+Minus、Ctrl+0、Ctrl+G、Esc、Left/Right、PageUp/PageDown。
- [ ] 所有 icon-only 按钮添加 semantic label。
- [ ] 不熟悉图标添加 tooltip。
- [ ] 弹窗打开后焦点限制在弹窗内。
- [ ] Tab 顺序符合视觉顺序。
- [ ] 列表和搜索结果支持方向键导航。
- [ ] 高对比主题覆盖应用和阅读器。
- [ ] 支持减少动画。
- [ ] 对长标题、长标签、长按钮文本做换行或省略。
- [ ] 按 `docs/testing-ui-ux-checklist.md` 完成响应式、主题、键盘和屏幕阅读器验收记录。

## 涉及模块和文件

- `lib/app/theme/app_theme.dart`
- `lib/app/responsive/`
- `lib/features/library/presentation/`
- `lib/features/reader/presentation/`
- `lib/features/search/presentation/`
- `lib/features/notes/presentation/`
- `lib/features/settings/presentation/`
- `test/accessibility/`
- `test/features/*/`
- `docs/testing-ui-ux-checklist.md`

## 数据与接口

- 快捷键只调用 application/controller 暴露的 command。
- UI 状态应能响应焦点和键盘选中项。
- 用户减少动画偏好通过设置或系统能力传入。

## UI 与交互

- 图标按钮触控区域至少 48 x 48。
- 列表项最小触控高度 48。
- 焦点样式清晰可见。
- 状态同时用图标/文本/位置表达，不只用颜色。
- 阅读器工具栏不能持续遮挡正文。
- 文字不使用 viewport width 动态缩放。

## 验收标准

- [ ] 主要页面在 compact、medium、expanded 下无重叠。
- [ ] 桌面快捷键可触发对应操作。
- [ ] Tab 可以遍历主要交互控件。
- [ ] 屏幕阅读器能读出主要按钮语义。
- [ ] 高对比主题可读。
- [ ] 长书名、长标签、长搜索词不会撑破布局。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- 本轮已验证：`dart format lib test`、`flutter analyze`、`flutter test -r expanded`、`flutter build windows --debug`。
- 当前实现说明：已建立 `lib/app/responsive/app_breakpoints.dart`，统一 compact、medium、expanded 和侧栏阈值；主 shell、书库双栏、笔记双栏、阅读器桌面搜索侧栏已改用该 helper；新增 `test/app/responsive/app_breakpoints_test.dart` 覆盖断点映射。
- Widget 测试：断点布局、焦点顺序、语义标签。
- 手动验证：Windows 键盘、Android TalkBack 基础路径、窗口极窄和宽屏。

## 依赖与风险

- 依赖：TASK-01 shell 和主题，所有页面 task。
- 风险：如果页面各自实现断点逻辑，后续一致性差，需要统一 helper。
- 风险：阅读器沉浸模式容易忽略键盘和屏幕阅读器入口。
