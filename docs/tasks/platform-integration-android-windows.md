# TASK-20：Android/Windows 平台集成

## 目标

把 PageSage 的文件选择、窗口行为、WebView、权限、快捷键、拖拽导入和平台打包差异隔离在平台层，保证 Android 和 Windows 都有符合平台习惯的体验。

## 来源与边界

- 来源：`docs/01-product-requirements.md`、`docs/03-interaction-spec.md`、`docs/05-technical-architecture.md`。
- 不做：iOS/macOS/Linux 具体发布，但代码不能写死 Android 或 Windows 专属业务模型。
- 约束：平台能力通过 adapter 暴露，不让业务层直接依赖平台实现。

## 功能范围

- Android 系统文件选择器。
- Windows 文件选择器。
- Windows 拖拽导入。
- Android 返回手势。
- Windows 窗口缩放。
- Windows 右键菜单。
- WebView 能力差异封装。
- 本地文件访问适配。
- 打开文件所在位置，桌面优先。
- 平台权限和错误映射。

## 实现任务

- [x] 完善 `FilePickerService`，支持单选和多选。
- [ ] Android 权限和文件 URI 处理统一封装。
- [ ] Windows 文件路径、长路径和中文路径处理验证。
- [ ] 实现 Windows 拖拽文件到窗口导入。
- [ ] Android 返回手势在阅读器中返回上一页。
- [x] Windows 右键菜单接入书库。
- [ ] Windows 右键菜单接入文本选择和搜索结果。
- [ ] WebView capabilities 判断 JavaScript bridge、本地文件、worker 支持。
- [ ] PDF 本地服务或文件访问方式封装为平台无关接口。
- [x] 桌面端支持打开应用书库目录和原文件所在位置。
- [ ] 平台错误映射为用户可读消息。
- [ ] 手动验证 Android 手机、Android 平板、Windows 桌面。

## 涉及模块和文件

- `lib/core/platform/file_picker_service.dart`
- `lib/core/platform/webview_capabilities.dart`
- `lib/core/platform/window_service.dart`
- `lib/core/platform/drag_drop_service.dart`
- `lib/core/platform/open_file_location_service.dart`
- `lib/renderers/pdf/pdf_renderer_server.dart`
- `android/`
- `windows/`
- `test/core/platform/`

## 数据与接口

- 平台服务只返回 domain/application 可理解的结果，不返回 UI widget。
- 文件选择返回原始路径或可读文件引用，由 import use case 复制到应用目录。
- 平台错误使用 `PlatformError`，再映射到 `AppError`。

## UI 与交互

- Android 竖屏优先，平板适配横屏。
- Android 阅读器工具栏默认自动隐藏。
- Windows 支持窗口缩放和三栏布局。
- Windows 支持右键菜单和键盘快捷键。
- Windows 拖拽导入时显示导入状态。
- 平台不可用能力要隐藏或禁用，并说明原因。

## 验收标准

- [ ] Android 可通过系统文件选择器导入 EPUB/PDF。
- [ ] Windows 可通过文件选择器导入 EPUB/PDF。
- [ ] Windows 拖拽导入可用或明确标记待实现状态。
- [ ] Android 返回手势在阅读器中行为正确。
- [ ] Windows 窗口缩放布局不重叠。
- [ ] EPUB native renderer 和 PDF WebView renderer 在两平台都能打开本地文件。

## 测试与验证

- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter doctor -v`
- 本轮已验证：`dart format lib test`、`flutter analyze`、`flutter test -r expanded`、`flutter build windows --debug`。
- 当前实现说明：`FilePickerService` 已通过 `FilePickerAdapter` 隔离第三方 picker，支持 EPUB/PDF 单选、多选和备份 zip 单选；导入用例和设置页恢复备份均通过平台服务选择文件；新增 `test/core/platform/file_picker_service_test.dart` 覆盖请求参数和取消路径。`OpenFileLocationService` 已封装 Windows explorer 调用；书库桌面详情面板和书籍操作菜单已支持打开书库副本位置和原文件位置；新增 `test/core/platform/open_file_location_service_test.dart` 覆盖 explorer 参数、文件缺失和平台不支持路径。书库网格卡片和桌面列表行已支持鼠标右键打开书籍操作菜单。
- 手动验证：Windows、Android 手机、Android 平板或模拟器。

## 依赖与风险

- 依赖：TASK-01 工程基础，TASK-03 导入，TASK-06/TASK-07 renderer。
- 风险：Windows WebView 和 Android WebView 文件访问差异大，需要保留平台适配层。
- 风险：Android 文件权限变化会影响原始路径访问，所以导入必须复制文件。
