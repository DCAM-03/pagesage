# F1：Markdown 文件夹外部变更同步

状态：应用内实现与自动验证已完成；真实窗口、性能门槛与用户验收待执行。共用来源、定位、迁移与发布规则见 [总规格](README.md)。

## 1. 现状与目标

现有 `lib/features/reader/application/markdown_folder_session.dart` 已经按文件会话读取；`lib/renderers/markdown/markdown_folder.dart` 提供递归 manifest、旧合并定位转换；`markdown_document_loader.dart` 读取时检查文件状态。缺少打开期间的变更监听、差异协调和统一来源版本。

目标是接近 Typora 的文件夹阅读方式：外部编辑器保存后，文件树和当前正文跟进；大纲只显示当前文件。保留阅读位置、页签、目录展开和用户笔记，不把多个 Markdown 文件再拼成一篇。

单文件书仍读取导入后的书库副本，不自动跟踪原始导入路径，也不加入编辑/保存功能。文件夹现有限制保留：最多 2,000 个 Markdown 文件、64 MiB Markdown 总字节，忽略隐藏目录及 `node_modules`，不跟随符号链接。

## 2. 交互与可观察状态

| 状态/事件 | 界面行为 |
| --- | --- |
| 正常 | 不长期显示提示条；文件树保留展开和选中 |
| 非当前文件修改 | 更新文件树状态并重建该文件索引，不切文件、页签或正文 |
| 当前文件修改 | 稳定读取后替换文档；按锚点恢复，短暂状态“已更新”在 3 秒后退场 |
| 当前文件消失 | 保留只读的最近正文并标记“文件已移除，当前为上次内容”；提供重新扫描/选择其他文件，不自动跳第一篇 |
| 文件无法读取/解析 | 保留上次视图和明确错误；不把错误当空文件，不把上次内容送入新检索 |
| 根目录不可访问 | 文件树进入不可访问态，暂停索引，保留进度与笔记；可重试，不移除书籍 |
| 监听降级 | 非阻塞说明“自动检测受限，定期检查中”，提供刷新；不反复弹 toast |
| 没有变化 | 手动刷新只给完成状态，不重排正文或覆盖位置 |

刷新入口在文件树工具区，快捷操作可复用现有“刷新”命令体系；不得与书内搜索或大纲快捷键冲突。状态需有文本/语义标签，不能只用颜色。自动更新不抢焦点；选区菜单打开时见第 5 节。

## 3. 监听与校验算法

### 3.1 Linux 监听不是递归 watch

Dart 官方 `FileSystemEntity.watch` 在 Linux 不支持 recursive，move 还可能拆成 delete/create。采用每个可见子目录独立 watch，最多 256 个 subscription；超过部分及创建 watch 失败均降级轮询，不能仅调用 `root.watch(recursive:true)` 就声明覆盖子目录。

1. 会话启动时注册根目录监听，扫描 manifest，再补子目录监听；注册与扫描之间的事件进入 dirty 集合，随后二次 reconcile，覆盖启动竞态。
2. 事件仅是“需要复核”的提示；按目录合并，尾沿 debounce 400 ms，持续保存时每 2 秒至少开始一次复核。一次只允许一个 reconcile，其间事件留待下一轮。
3. 后台每 30 秒扫描 manifest 元信息；当前文件每 30 秒做内容 hash，补相同大小/mtime 的保存。全目录每 5 分钟低优先级核实 hash；手动刷新、重新获得前台焦点时完整核实。
4. 新目录出现即补 watch；目录移除、切书、页面销毁时取消 subscription、timer 与队列。watch stream 结束/报错转降级，不静默失去检测。
5. 非当前书不保持常驻 watcher；重开完整核实。休眠期间不承诺检测时限。

目标：普通前台单文件保存稳定后 1.5 秒内更新；降级元信息检测 35 秒内，相同元信息非当前文件最迟下次 5 分钟核实。以上是验收目标，非现有实测。

### 3.2 稳定快照

对候选文件执行路径检查 → stat-before → 读取 bytes/hash → stat-after；变化则最多重试 3 次，间隔 200/500/1,000 ms，持续变化进入“等待保存稳定”态。文件长度为 0 在稳定快照下是有效空文件，不永久忽略。

严格 UTF-8 解码失败报告编码错误，不写入替换字符来伪装正文。外部编辑器的临时文件不进入 manifest；同路径 delete/create 若在同一稳定复核内最终存在，按原身份的内容替换处理，不立即删除该文件。

扫描和打开均检查规范相对路径、真实根目录边界、文件类型及 link。拒绝 `..`、绝对地址和越界链接；大小写按文件系统事实处理，不把 Linux 上不同大小写文件合并。原生普通 Dart 文件 API 无法提供所有恶意并发换链的 OS 级原子保证，该限制登记为本地目录信任边界，不以一次字符串前缀检查声称绝对防护。

根目录扫描失败与成功得到空 manifest 必须区分；失败不能把全部文件误判删除。Markdown 引用的本地图片若收到变更事件，定向 evict 当前文件对应的图像缓存并刷新显示，不创建图片正文索引；手动刷新也核实当前可见资源，不扫描/预解码目录内所有图片。

### 3.3 差异与改名

输入：上一份稳定 manifest、新 manifest、source registry、dirty 提示；输出：新增、内容变更、删除、可靠改名、未变化。

- 同一活动相对路径：身份不变；hash 相同只更新观测元信息，不重新解析、索引或抖动进度。
- 确认删除：source 留 tombstone，排除旧索引；批注/书签保留，显示来源缺失。
- 可靠改名：仅接受 watcher 提供成对移动路径并经最终 manifest 校验，旧路径确实消失、新路径唯一且无覆盖冲突。整个目录移动逐文件验证；有可靠移动关联但同时编辑时延续身份并更新 sourceRevision。
- 只凭唯一 hash 的消失/出现也无法区分改名与删旧后复制，因此不能自动延续身份。同 hash 的多副本、无可信移动关联、删除后隔一轮再新建均按删除+新增；不自动迁移批注。可在旧来源入口提供显式选择新文件，用户确认后记录映射，不默认猜测。
- 标题改变不影响身份；排序按现有相对路径规则，排序位置不是 locator 身份。

## 4. 拟议应用接口与状态机

| 责任 | 拟议接口/归属 |
| --- | --- |
| 文件事实 | `MarkdownFolderSource.scanSnapshot(root, verificationMode)`，renderer/data 边界只返回值对象 |
| 生命周期 | `MarkdownFolderRefreshCoordinator.start/refresh/dispose`，位于 reader application |
| 差异 | `MarkdownManifestDiff.compute(previous,current,moveHints)`，纯函数 |
| 来源及索引 | domain repository 暴露 `applyObservedChanges` / `buildAndPublishSource`，UI 不访问 DAO |
| 重锚 | `ReadingAnchorResolver.resolve(oldLocator,oldText,newText)`，返回明确精度状态 |

会话状态：`idle → scanning → reconciling → loadingActive → ready`；无活动文件变更时跳过 loadingActive。任一阶段可到 `degraded/error/disposed`。`refreshEpoch` 递增；parse、重锚、索引发布同时比较 bookId/sourceId/epoch/sourceRevision。dispose 后结果不写状态，旧 parse 不覆盖新 parse。

索引失败与正文刷新分开显示：正文已更新不等于可以搜到。失败不回滚磁盘观测版本，旧代不能继续被当作当前正文检索；只重试失败文件。

## 5. 位置、选区与批注

刷新前捕获最接近视口顶部的文本块锚点、块内 UTF-16 偏移及像素相对位置。刷新后依次解析：

1. textRevision 未变：保留原区间与视口位置。
2. 唯一 exact quote 与 prefix/suffix 一致：映射到新章节偏移，返回 reanchored。
3. 无精确 quote 但原标题路径仍唯一：定位标题后按旧局部比例近似，标记 approximate，不重画旧选区。
4. 重复文本、标题不唯一或锚点删除：保留最近合理视口，明确“原位置已变化”，不误关联另一个同名标题。

标题路径包含层级与同级 ordinal，仅作近似回退，不是永久身份。跨文件改名只更新 source 地址映射；旧历史里的 href、快照原文不批量重写。

选区菜单/批注编辑器打开时先冻结其 `SelectionSnapshot` 与 sourceRevision；正文更新延后到菜单结束，最长保留到用户关闭，不让新正文替换正在引用的文本。来源此时已经变化的事实仍进入 registry；提交批注保留旧版文本并提示待核对，不能把旧 offset 保存成新版本。正在输入的批注草稿不可丢弃。

## 6. 数据、兼容和消费者

SQL 结构复用 S0/v8；旧文件夹合并 locator 仍通过已有 `resolveLegacyPosition` 转换，不能因新增来源注册移除迁移入口。首次建立 manifest 映射前旧 locator 不升级成“已核实”。

| 消费者 | 必须同步的行为 |
| --- | --- |
| 文件树/大纲/面板设置 | 文件状态更新，但不自动切大纲或展开全部树 |
| 进度/书签/批注/笔记 | 可选来源版本往返；缺失不删除；精确与近似展示有区别 |
| 书内/全局搜索 | 变更文件失效并按 generation 重建；删除不返回旧命中 |
| AI 当前上下文/历史 | 新提问核实来源；已发送及历史快照不变 |
| 导出/备份/恢复 | 带 locator provenance；源目录不打包、不写入，恢复后重新检查访问性 |
| 移除书籍 | 清理 registry/监听/索引；绝不删除外部目录 |

错误码拟为 `source_missing/source_unreadable/source_unstable/invalid_encoding/folder_limit_exceeded/watch_degraded/anchor_ambiguous`，保留可重试语义，日志不带文件正文。

## 7. 切片与资源预算

1. F1-A：纯 diff、来源身份与临时文件保存测试。
2. F1-B：watch/poll coordinator、生命周期、source 失效及原子发布。
3. F1-C：当前文件刷新、锚点、选区冻结、缺失状态与 UI。
4. F1-D：旧定位、搜索/AI/批注/导出回归与 Linux 安装。

最多同时读取 2 个文件、解析 1 个活动文档；不为了刷新把整个文件夹正文加载到阅读器。遍历/摘要 hash 分批让出执行权；2,000 文件夹具的扫描目标 2 秒以内，须记录机器、冷热缓存、总字节和实际结果，不能隐藏超过预算的情况。

## 8. 验收用例

| ID | 输入/动作 | 必须结果 |
| --- | --- | --- |
| F1-01 | 根/深层子目录文件原地修改与原子替换 | 更新一次稳定正文；不切侧栏、不抢焦点 |
| F1-02 | 10 次快速保存、旧 parse 人为延迟 | 最后版本胜出，没有旧内容回跳 |
| F1-03 | 前文插入与当前位置引用重现 | 唯一锚点保持位置；重复引用降级不画错 |
| F1-04 | 当前文件删除、不可读、根目录断开 | 保留上次只读正文与笔记；不跳其他文件 |
| F1-05 | 唯一改名、重复 hash、删除后重新创建 | 仅可靠改名延续身份，其他不搬批注 |
| F1-06 | watcher 不支持/达到 256/stream 退出 | 轮询生效，新子目录也可发现 |
| F1-07 | 相同 size/mtime 内容替换 | 当前/手动/完整周期 hash 检测符合承诺窗口 |
| F1-08 | 修改时选区/批注草稿打开 | 草稿保留，历史文本与新 offset 不混用 |
| F1-09 | 索引中取消、崩溃或又修改 | 不发布半代；过期结果不进搜索和 AI |
| F1-10 | 2,001 文件、超 64 MiB、越界链接、非法 UTF-8 | 明确拒绝/错误，不破坏已有书籍 |

拟新增测试：`test/features/reader/markdown_folder_refresh_test.dart`、`test/renderers/markdown/markdown_manifest_diff_test.dart`、`test/domain/books/reading_anchor_resolver_test.dart`。扩展现有 `test/features/reader/markdown_folder_session_test.dart` 与 `test/core/search/search_indexer_test.dart`。最终证据统一登记 [联合验收](07-validation-and-acceptance.md)。

## 9. 外部依据

[Dart FileSystemEntity.watch 官方说明](https://api.dart.dev/dart-io/FileSystemEntity/watch.html)：本方案据此采用 Linux 子目录多监听及复核机制，不把事件流当完整的有序日志。
