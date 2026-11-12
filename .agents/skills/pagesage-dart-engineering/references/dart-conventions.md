# Dart 编码与异步

## 工具与命名

`pubspec.yaml` 和 `pubspec.lock` 控制 SDK/依赖，`analysis_options.yaml` 目前使用
`package:flutter_lints/flutter.yaml`。保持现有分析配置，不为局部功能顺带开启全仓 strict
选项、`dart fix --apply`、修改 lockfile 或全面格式化。依赖/SDK 有变化或本机依赖缺失时才运行 `flutter pub get`。

- 文件、目录和 import prefix 使用 `lowercase_with_underscores`。
- 类、枚举、typedef 和 extension 使用 `UpperCamelCase`；方法、变量和常量使用 `lowerCamelCase`。
- 标识符使用英文并表达语义，用户提示和项目说明保持中文；不把当前实现批量重命名来满足偏好。
- 让 `dart format` 控制缩进与换行，只格式化本次涉及的 Dart 文件。import 分组沿用邻近代码，消除未使用项。

## 类型与模型

- 公开接口、跨层返回值和字段明确类型；局部变量类型清楚时允许推断，不增加无意义标注。
- 默认使用 `final`，能表达编译期常量时使用 `const`。只有确有可变职责时使用可变字段。
- JSON/平台输入在边界校验并收窄为领域类型；无法确定的值用 `Object?` 表达，不让 `dynamic` 扩散到业务层。
- 不用 `!`、`as` 或 `late` 掩盖未解决的状态；已有明确初始化不变量时可以使用，不机械禁止。
- 列表和 map 的只读暴露应避免调用方继续修改原集合；选择必要的防御拷贝或不可变封装，不每次读取都复制大数据。
- `copyWith` 对可空字段须区分“不修改”和“设置为 null”，沿用现有 sentinel 或明确更新接口。
- 用 enum / sealed 类型表达封闭状态；类修饰符按扩展与实现需求选择，不批量加 `final` 或引入代码生成包。
- 优先小而明确的函数和参数，避免布尔参数堆叠、重复 DTO 和无实际消费者的通用抽象。

## 错误语义

- 在能恢复、增加有效上下文或转换用户可理解错误的层捕获异常；原样传播时使用 `rethrow` 保留堆栈。
- 不把读取失败、损坏 JSON、索引失败转换成“没有数据”“空答案”或成功状态。缺数据与失败分开建模。
- 已定义的图像占位、缺少历史字段等降级可以保留，但须有明确触发条件和可观察结果。
- 不把编程错误当正常业务分支，不用广泛 `catch` 隐藏错误。顶层清理/状态收口若捕获未知异常，处理后继续传播或明确报告。
- 用户取消、任务失败和成功是不同终态；取消不能写入完整成功历史，也不触发无穷重试。
- 用 `try/finally` 释放拥有的资源；异常信息与日志不得泄漏密钥、用户正文或完整请求。

## Future、Stream 与竞态

- 优先 `async`/`await`；异步命令返回 `Future<void>`，同步事件回调可以调用受管理的异步方法。
- 应等待的写入必须等待。确有后台任务时明确拥有者、取消和错误处理；`unawaited` 本身不处理异常。
- `await` 之后检查实际拥有者的生命周期；还要检查 bookId、请求 token 或 generation，
  防止旧查询在切书、切文件、切来源或新请求之后覆盖新状态。仅检查 `mounted` 不足以防止过期结果。
- `StreamSubscription`、timer、取消令牌和打开的 I/O 由创建/持有它们的对象在生命周期结束时关闭。
- 独立且有收益的任务可以并行；同一数据库事务、同一可变状态或有顺序依赖的操作保持顺序。
- 大型 EPUB/PDF 解析、哈希和索引计算按测量结果使用现有后台机制；不能把 Widget、
  数据库连接或带资源句柄的对象直接传给 isolate。移动计算前核对消息可传递性与复制成本。

## 参考

延续本地约定；需要查语言细节时使用官方文档，不以参考文档为理由增加全仓重构：

- [Effective Dart: Style](https://dart.dev/effective-dart/style)
- [Effective Dart: Usage](https://dart.dev/effective-dart/usage)
