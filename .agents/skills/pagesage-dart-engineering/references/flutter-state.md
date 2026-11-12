# Flutter 状态、交互与资源

## 状态归属

- Widget 负责呈现、输入和短生命周期 UI 状态；用例/controller 编排业务；repository 持久化领域数据。
- 沿用本仓库 Riverpod 的装配与 override 方式，不添加第二套状态管理，也不让 UI 直接调用 DAO。
- 响应式展示依赖使用 `ref.watch`；事件触发读取使用 `ref.read`。一次性副作用放在明确的监听或事件边界，避免每次重建重复执行。
- Widget `build()` 不发请求、落库、导入文件或重复启动订阅。Provider / AsyncNotifier 的初始化
  可以加载数据，但要声明依赖和取消/过期策略，不能把这条 Widget 规则误用为禁止所有 provider 初始化。
- 能从现有状态推导的数据直接推导，不复制成多个可变字段后用监听互相同步。
- 对异步数据明确 loading / data / error；错误不能降级为空列表，让用户误以为没有历史或搜索结果。
- 页面持久设置、进度和会话恢复通过现有 repository/controller 保存；不依赖 Widget 存活代替持久化。

## 资源与异步界面

- `State` 自己创建的 controller、focus node、timer 和 subscription 在对应生命周期释放。
- Provider 拥有的资源在其生命周期清理，不由临时 Widget 提前关闭共享对象。测试 override 也要释放实际拥有的资源。
- PDF document/page/image、图片解码和文件句柄明确缓存拥有者、容量与淘汰释放；不在每次 build 中重新解析整本书。
- await 后使用 context、更新 state 或显示 snackbar 前检查存活；对恢复历史、切书、检索同时检查请求身份。
- 跨 `didUpdateWidget` 的旧任务和监听要解除或失效；去掉组件后不能继续写 UI，也不能把旧结果写给新书。
- 长任务区分运行、取消、失败和成功，避免双击启动重复写入；有副作用的操作不能无限自动重试。

## 阅读器 UI

- 复用 `lib/app/theme/` 的 tokens、主题、breakpoints 和现有控件；不把普通阅读器改造成装饰性 dashboard。
- 核对实际可用宽高、文字缩放、键盘与窗口调整；不只在一张固定尺寸截图上判断布局。
- 在实际需要的滚动/分页、侧栏开启/关闭和主题状态下验证，不自动生成全部状态的笛卡尔积。
- 图标按钮补语义和 tooltip；桌面可键盘操作、焦点可见；移动工具栏不长期遮挡正文。
- 点击文件、标题跳转、打开工具栏是不同意图；不要顺带切换用户未选择的文件树/大纲或工具页签。
- 位置信号经现有 locator/event 通道上报，由 Dart 应用层持久化；不让渲染组件自行落业务数据库。

## 界面验证边界

Widget 测试检查交互和状态；离屏截图检查真实渲染后的溢出、遮挡、焦点与标签可读性。
截图不能证明点击、保存和重开流程，widget PASS 也不代表真实桌面或 Android 已验收。
静默约束下不自行启动桌面集成测试或真实窗口，遵循 `validation-harness`。

[Flutter 架构建议](https://docs.flutter.dev/app-architecture/recommendations) 提供原则参考；
本仓库已选择 Riverpod 和现有分层，不因官方示例使用其他方案就更换技术栈。
