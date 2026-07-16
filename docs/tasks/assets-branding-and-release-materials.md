# TASK-22：图片资源、图标、默认封面和商店素材

## 目标

按 PageSage 的视觉规范建立图片资源体系，包括 App 图标、空状态插画、默认封面、AI 空状态和商店宣传图，并保证资源不替代常规 UI 图标。

## 来源与边界

- 来源：`docs/assets-plan.md`、`docs/04-ui-design-system.md`。
- 不做：用位图替代工具栏图标、菜单图标、设置项图标或状态图标。
- 约束：图片资源必须保存到项目 `assets/images/` 并加入 `pubspec.yaml`；不覆盖已有资源。

## 功能范围

- App 图标源图。
- Android launcher icon。
- Windows app icon。
- 空书库插画。
- 空搜索插画。
- 空笔记插画。
- AI 面板空状态。
- 默认封面模板。
- 商店宣传图。
- 资源压缩和命名。
- 资源验收和主题适配。

## 实现任务

- [ ] 建立 `assets/images/brand/`。
- [ ] 建立 `assets/images/empty-states/`。
- [ ] 建立 `assets/images/covers/`。
- [ ] 建立 `assets/images/store/`。
- [ ] 生成或设计 `app-icon-source.png`，1024 x 1024。
- [ ] 生成 Android 和 Windows 所需图标尺寸。
- [ ] 生成空书库插画，适配浅色和深色 UI。
- [ ] 生成空搜索和空笔记插画。
- [ ] 生成 AI 面板空状态插画。
- [ ] 生成默认封面：通用、小说、技术、论文、历史、语言学习。
- [ ] UI 中无封面书籍使用默认封面。
- [ ] 商店宣传图等 UI 稳定后再生成。
- [ ] 图片资源压缩，避免包体异常增大。
- [ ] 更新 `pubspec.yaml` assets。
- [ ] 更新发布材料中截图和隐私说明引用。

## 涉及模块和文件

- `assets/images/brand/`
- `assets/images/empty-states/`
- `assets/images/covers/`
- `assets/images/store/`
- `pubspec.yaml`
- `android/app/src/main/res/`
- `windows/runner/resources/`
- `lib/features/library/presentation/`
- `lib/features/search/presentation/`
- `lib/features/notes/presentation/`
- `lib/features/ai/presentation/`

## 数据与接口

- 默认封面可由 `BookCoverResolver` 根据书籍类型或格式选择。
- 资源路径通过统一常量管理，避免散落字符串。
- 封面缓存与导入提取封面区分：默认封面不写入用户 book cover_path，除非明确生成副本。

## UI 与交互

- 空状态插画不抢主按钮注意力。
- 默认封面比例 2:3，标题由 UI 叠加时需避免溢出。
- AI 空状态不能使用强烈科技风。
- 工具栏、菜单、普通按钮继续使用 Flutter Material Icons 或统一矢量图标库。

## 验收标准

- [ ] App 图标 64 x 64 下仍可识别为阅读器。
- [ ] 图片不包含文字、水印或第三方品牌。
- [ ] 空状态在浅色和深色主题下都协调。
- [ ] 默认封面比例稳定且不拉伸。
- [ ] `flutter pub get` 能识别所有 assets。
- [ ] 发布包包含必要图片资源。

## 测试与验证

- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- 手动验证：空书库、空搜索、空笔记、无封面书籍、Android launcher、Windows 图标。

## 依赖与风险

- 依赖：TASK-04 书库 UI，TASK-14 搜索 UI，TASK-12 笔记 UI，TASK-15/16 AI 面板。
- 风险：图片生成风格不统一会削弱产品感，需要统一色彩和构图。
- 风险：资源过大影响包体和启动性能，需要压缩。

