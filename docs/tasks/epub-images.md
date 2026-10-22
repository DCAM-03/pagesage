# TASK-30：EPUB 真实图片渲染（B3）

## 目标

让 EPUB 阅读器真正显示书中的插图。当前加载器只取 XHTML 的 `innerText`，`<img>` 被丢弃，渲染端的图片占位分支因此不可达。这是独立的功能缺陷，不是图片批注的子任务。

## 来源与边界

- 来源：`docs/13-image-annotations.md` §2、§9（B3）。
- 不做：SVG 动画、字体图标、远程图片（本地优先，`http(s)` 图片一律不加载）。
- 不做：图片批注（那是 B4，见 `image-annotations.md`）。

## 现状证据

- `lib/renderers/epub/epub_document_loader.dart` 的 `_extractText` 只取 `innerText`。
- `lib/renderers/epub/epub_paginator.dart` 的 `_detectBlockType` 只在文本以 `[image` / `image:` / `figure:` 开头时返回 `imagePlaceholder`，而加载器从不生成这种文本。
- `lib/renderers/epub/epub_renderer_view.dart` 的 `_EpubImagePlaceholder` 因此永远不显示。

## 功能范围

- 解析 spine 文档中的 `<img>`、`<svg><image>`、`<figure>/<figcaption>`。
- 图片与正文按文档顺序排版，占正确的位置和比例。
- 图注（`figcaption` / `alt`）作为可读文本参与排版。
- 解码缓存与像素上限；失败降级为带说明的占位块，而不是空白。

## 实现任务

- [ ] `EpubChapter` 增加结构化块序列（文本块 / 图片块），而不是单一 `text` 字符串。这会影响分页器、进度计算和选区偏移，需要先确认 `epub_paginator.dart` 的字符偏移模型能否扩展。
- [ ] 加载器从 archive 读取图片字节：相对路径按 XHTML 所在目录解析，支持 `data:` URI，拒绝 `http(s):`。
- [ ] 图片解码缓存（按 archive 路径 + 字节长度做键），上限按总像素计而不是按张数。
- [ ] 解码失败 / 超预算：显示 `_EpubImagePlaceholder` 的降级形态，文字说明原因。
- [ ] `figcaption` 作为普通段落参与排版与搜索。
- [ ] 阅读进度与 locator：确认插入图片块后 `chapterOffset` 语义不变（偏移仍只针对文本，图片不占字符）。

## 涉及模块和文件

- `lib/renderers/epub/epub_document.dart`、`epub_document_loader.dart`、`epub_paginator.dart`、`epub_renderer_view.dart`
- `test/renderers/epub/`

## 数据与接口

- 不涉及数据库变更。
- `EpubDocument` 的公开形态变化会影响 `AiContextSource` 取章节文本（`docs/12-ai-retrieval-strategy.md` §7.1），需同步检查。

## UI 与交互

- 图片按容器宽度等比缩放，不超过页宽。
- 夜间主题下不做反色或滤镜（会破坏照片）。
- 图注使用次级文字色，与正文区分。

## 验收标准

- [ ] 带图片的 EPUB 打开后能看到插图，位置与书中的顺序一致。
- [ ] 图片在分页模式下不被跨页截断（或明确允许截断并有视觉处理）。
- [ ] 图片加载失败时有可读的占位说明，不是空白。
- [ ] 阅读进度、跳转、划词在高亮偏移上不受影响。
- [ ] `AiContextSource` 取章节文本仍返回纯文本，不含图片标记。

## 测试与验证

- 单元测试：路径解析（相对路径、子目录、`../`）、`data:` URI、拒绝远程 URL。
- Widget 测试：含图 EPUB 的分页与滚动渲染。
- 真实样本：补一本图文混排 EPUB 到 `docs/manual-samples.md`（现有 `image.epub` 可先用作冒烟）。
- `dart format .`、`flutter analyze`、`flutter test`。

## 依赖与风险

- 依赖：无。可与 `image-annotations.md` 的 B1 并行。
- 风险一：这是本组任务里最大的一块。`EpubChapter.text` 目前是单一字符串，插入图片意味着改动分页器、进度和偏移模型，回归面很广。实施前应先加一层「文本块序列」并在纯文本路径上跑通全部现有测试，再接入图片。
- 风险二：解压炸弹。单图解码后像素预算必须硬限制，且要在解码**前**从图片头部读尺寸，不能先解再查。
- 风险三：进度语义漂移。图片不占文本字符，若分页器把图片当字符计入，历史进度会错位。
