# PageSage 产品技术文档

版本：0.1  
日期：2026-06-12  
状态：产品与技术启动稿  
目标平台：Android、Windows，后续扩展 iOS、macOS、Linux  

> 当前执行范围以 `docs/00-overview.md` 到 `docs/07-roadmap.md` 为准。本文件是早期启动稿，仍保留 MOBI/Calibre 和 epub.js/WebView EPUB 设想；当前 Flutter 首版暂只处理 EPUB/PDF，MOBI/AZW 与 Calibre 转换已暂缓，EPUB 技术路线已调整为 Flutter-native renderer。

## 1. 产品定位

PageSage 是一个本地优先的跨平台智能阅读器。核心目标是让用户在一个统一的书库中阅读 EPUB、MOBI、PDF，管理阅读进度、目录、书签、划线、笔记，并在需要时对选中文本进行 AI 问答、解释、总结和翻译。

产品关键词：

- 本地优先：书籍、笔记、阅读进度默认保存在本机。
- 跨平台：优先 Android 和 Windows，后续支持 iOS、macOS、Linux。
- 多格式：EPUB、PDF 原生阅读体验，MOBI 通过导入转换进入统一阅读体系。
- 可检索：书籍正文、标题、作者、书签、笔记、AI 回答均可全局搜索。
- 可沉淀：划线、书签、笔记、AI 回答可以形成可复习的知识库。
- 可控 AI：AI 请求明确展示将发送的上下文范围。

## 2. 目标用户与场景

### 2.1 目标用户

- 重度电子书读者：希望统一管理 EPUB、MOBI、PDF。
- 学生和研究者：需要在 PDF、教材、论文中搜索、标注、做笔记。
- 技术人员：需要阅读技术书、规格文档、论文，并对片段进行解释和问答。
- 语言学习者：需要划词解释、翻译、例句和笔记沉淀。
- 知识管理用户：希望把阅读内容、摘录、AI 回答转化成可检索资产。

### 2.2 核心使用场景

- 导入一本 EPUB，调整字号、行距、背景，阅读后自动记忆进度。
- 导入一本 PDF，按页阅读、缩放、搜索正文、添加书签。
- 导入 MOBI 文件，应用自动转换为 EPUB 后进入书库。
- 在全局搜索中查找某个概念，结果同时命中书籍正文、笔记和 AI 回答。
- 在阅读时划词，点击 AI 按钮，询问“这段话是什么意思”。
- 将 AI 回答保存为笔记，并关联到原文位置。
- 按“技术/小说/论文/待读/已读”等目录分类管理书籍。

## 3. 产品原则

1. 阅读优先  
   阅读界面必须安静、稳定、少打扰。工具栏和面板默认收起，用户需要时再出现。

2. 本地数据可控  
   书籍、进度、笔记、搜索索引默认只保存在本机。AI 请求会展示将发送的上下文范围。

3. 跨格式一致  
   EPUB 和 PDF 的底层渲染不同，但书签、笔记、搜索、目录、AI 问答的产品模型尽量一致。

4. 渐进增强  
   基础阅读不依赖 AI。AI 是增强能力，不应阻断导入、阅读、搜索、做笔记等核心流程。

5. 可恢复  
   阅读进度、书签、笔记、索引任务、MOBI 转换任务必须能在应用重启后恢复或重试。

## 4. 平台范围

### 4.1 第一阶段

- Android 手机和平板
- Windows 桌面端

原因：

- 当前开发环境已有 Android SDK、Java、Visual Studio Native Desktop workload。
- Flutter 适合同时覆盖 Android 和 Windows。
- 文件导入、本地存储、WebView 渲染、SQLite 索引在这两个平台上可控。

### 4.2 第二阶段

- iOS
- macOS
- Linux

限制：

- iOS 和 macOS 构建需要 macOS 与 Xcode。
- Linux 桌面需要额外验证 WebView、文件选择器和 PDF 渲染行为。

### 4.3 Web 版本

Web 可以作为后续只读或轻量版，但不建议作为首发重点。原因是浏览器文件系统权限、后台索引、MOBI 转换、离线持久化能力会限制完整阅读器体验。

## 5. 技术栈

### 5.1 客户端

- UI 框架：Flutter
- 语言：Dart
- 状态管理：Riverpod
- 路由：go_router
- 本地数据库：SQLite
- Dart ORM：Drift
- 全文搜索：SQLite FTS5
- 本地文件选择：file_picker
- 路径管理：path_provider
- 权限管理：permission_handler
- WebView：（未采用——两个阅读器均为 Flutter-native，见 §5.2 说明）
- 本地安全存储：flutter_secure_storage
- 日志：logger 或 talker
- 崩溃记录：本地日志优先，后续可选 Sentry

### 5.2 阅读渲染

> **已过时（2026-10-21）**：现行实现是 EPUB 与 PDF 都走 Flutter-native 渲染。
> EPUB 使用 Flutter 原生 renderer，PDF 使用 `pdf_graphics` + Flutter Canvas；
> 文中 epub.js / PDF.js / WebView 方案未采用。见 `docs/05-technical-architecture.md`
> §11.4 与 `docs/10-pdf-renderer-migration.md`。

- EPUB：epub.js
- PDF：PDF.js
- MOBI：导入时调用 Calibre 的 ebook-convert 转成 EPUB

说明：

- EPUB 本质是 HTML/CSS/资源包，使用 epub.js 能更好控制字号、行距、主题、分页和位置。
- PDF 是固定版式，PDF.js 跨平台一致性好，适合首版快速实现。
- MOBI 生态复杂，不建议首版自研解析器。统一转换为 EPUB 后进入同一阅读流程。

### 5.3 AI 能力

- Provider 抽象：OpenAI-compatible Chat Completions 或 Responses API 风格接口
- 可选 Provider：
  - OpenAI
  - Azure OpenAI
  - 本地 Ollama
  - 其他 OpenAI-compatible 服务
- 请求模式：用户主动划词或提问后发送上下文
- 输出模式：流式输出优先，支持保存为笔记

### 5.4 后台任务

- 导入任务：复制文件、解析元数据、提取封面、建立索引
- 转换任务：MOBI 转 EPUB
- 索引任务：正文切块、写入 FTS5
- 清理任务：删除孤立文件、重建索引、压缩缓存

首版可在应用内任务队列实现。后续再按平台引入更强后台能力。

### 5.5 测试

- 单元测试：Dart test
- UI 测试：Flutter widget test
- 集成测试：integration_test
- 渲染回归：关键书籍样本截图对比
- 索引测试：固定语料搜索结果验证

## 6. 总体架构

PageSage 采用分层架构：

```text
UI Layer
  Screens, widgets, reader panels, dialogs

Application Layer
  Use cases, controllers, task orchestration

Domain Layer
  Book, ReadingPosition, Bookmark, Annotation, Note, SearchResult, AiConversation

Data Layer
  Drift DAOs, file repository, search index repository, settings repository

Rendering Layer
  EPUB runtime with epub.js, PDF runtime with PDF.js, JS bridge

Platform Layer
  File picker, secure storage, WebView, Calibre command bridge, OS integrations
```

### 6.1 模块划分

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  features/
    library/
    reader/
    search/
    notes/
    ai/
    settings/
    import/
  core/
    database/
    files/
    tasks/
    logging/
    platform/
    security/
  renderers/
    epub/
    pdf/
assets/
  renderer/
    epub/
    pdf/
  images/
docs/
```

### 6.2 数据流

导入书籍：

```text
FilePicker
  -> ImportController
  -> FileRepository copy to app storage
  -> FormatDetector
  -> MetadataExtractor
  -> TextExtractor
  -> SearchIndexer
  -> BookDao insert/update
  -> Library UI refresh
```

阅读书籍：

```text
ReaderScreen
  -> BookDao load metadata
  -> ProgressDao load last position
  -> RendererController open book
  -> WebView loads EPUB/PDF runtime
  -> JS bridge reports location changes
  -> ProgressDao debounce save
```

AI 问答：

```text
Text selection
  -> ContextBuilder
  -> User confirms action
  -> AiProvider stream response
  -> AiConversationDao save
  -> Optional NoteDao save linked note
```

## 7. 功能范围

### 7.1 书库

基础功能：

- 导入 EPUB、PDF、MOBI
- 批量导入
- 扫描指定文件夹
- 展示封面、标题、作者、格式、阅读进度
- 书籍详情页
- 重命名展示标题
- 修改作者、标签、分类
- 删除书籍
- 从书库移除但保留源文件
- 打开原文件位置，桌面端优先
- 重建索引
- 重新提取封面

排序：

- 最近阅读
- 最近导入
- 标题
- 作者
- 阅读进度
- 文件大小
- 格式

筛选：

- 全部
- 在读
- 未读
- 已读
- 有笔记
- 有书签
- EPUB
- PDF
- MOBI 转换书籍

视图：

- 网格视图
- 列表视图
- 紧凑列表

### 7.2 分类与目录

功能：

- 创建目录
- 创建子目录
- 重命名目录
- 删除目录
- 将书籍移动到目录
- 一本书支持多个标签，但主目录只有一个
- 默认目录：
  - 全部书籍
  - 最近阅读
  - 未分类
  - 收藏
  - 已读

交互：

- 桌面端左侧栏展示目录树。
- 移动端在书库页顶部提供分类下拉或抽屉。
- 支持拖拽移动，移动端使用长按后选择“移动到”。

### 7.3 EPUB 阅读

功能：

- 分页阅读
- 滚动阅读
- 目录跳转
- 字号调整
- 字体选择
- 行高调整
- 段落间距调整
- 页边距调整
- 背景切换
- 前景文字颜色切换
- 主题切换
- 亮度控制，移动端优先
- 记忆阅读位置
- 书内搜索
- 添加书签
- 划线高亮
- 添加笔记
- 划词 AI 问答

阅读位置：

- EPUB 使用 CFI 或章节 href 加偏移作为主定位。
- 同时保存章节序号、阅读百分比、更新时间作为备用信息。

### 7.4 PDF 阅读

功能：

- 单页模式
- 连续滚动模式
- 双页模式，桌面和平板优先
- 缩放
- 适合宽度
- 适合页面
- 页码跳转
- 目录跳转，如果 PDF 有 outline
- 文本选择
- 书内搜索
- 添加书签
- 添加批注和笔记
- 划词 AI 问答

阅读位置：

- PDF 使用页码、页内滚动偏移、缩放比例保存。
- 搜索和 AI 引用保存页码、文本片段、坐标区域，坐标可在后续版本补充。

### 7.5 MOBI 支持

首版策略：

- 用户导入 MOBI。
- 应用检测本机是否安装 Calibre。
- 如果已安装，调用 ebook-convert 转换为 EPUB。
- 转换成功后将 EPUB 加入书库。
- 保留原始 MOBI 文件引用。
- 转换失败时展示错误原因和手动安装指引。

不做：

- 首版不自研 MOBI 渲染器。
- 首版不保证所有 DRM 文件可导入。

### 7.6 阅读进度

功能：

- 自动保存当前阅读位置。
- 回到书库后显示百分比。
- 打开书籍时自动恢复上次位置。
- 支持“从头开始阅读”。
- 支持手动标记已读、未读。

保存策略：

- 阅读位置变化后 1 到 3 秒 debounce 保存。
- 应用进入后台时立即保存。
- 关闭书籍时立即保存。

### 7.7 书签

功能：

- 一键添加或取消当前页书签。
- 书签可添加简短备注。
- 书签列表按书籍、时间、位置查看。
- 阅读器内可以从书签面板跳转。
- 全局搜索可命中书签备注。

### 7.8 划线与笔记

划线类型：

- 黄色高亮
- 蓝色高亮
- 绿色高亮
- 红色重点
- 下划线

笔记类型：

- 原文摘录
- 手写文本笔记
- AI 回答保存
- 问题卡片

功能：

- 选中文本后弹出浮动菜单。
- 可选择高亮、复制、搜索、AI 提问、添加笔记。
- 笔记可编辑、删除、定位回原文。
- 笔记页支持按书籍、标签、时间筛选。
- 全局搜索可命中笔记正文。

### 7.9 全局搜索

搜索范围：

- 书名
- 作者
- 分类
- 标签
- EPUB 正文
- PDF 可提取文本
- 书签备注
- 笔记
- AI 问答

搜索能力：

- 关键词搜索
- 短语搜索
- 按书籍筛选
- 按格式筛选
- 按分类筛选
- 按结果类型筛选
- 结果片段高亮
- 点击结果跳转到对应位置

索引策略：

- 每本书按章节或页切块。
- 每个 chunk 保存 book_id、location、title、text、type。
- 使用 SQLite FTS5 建全文索引。
- 导入后后台建立索引，未完成时书籍仍可阅读。

### 7.10 AI 问答

入口：

- 阅读器选中文本后的浮动菜单。
- 阅读器右侧 AI 面板。
- 笔记页对已摘录内容提问。
- 全局搜索结果中对命中片段提问。

常用动作：

- 解释这段话
- 总结这一页
- 总结本章
- 翻译
- 提取要点
- 生成问题
- 用更简单的话说明
- 联系上下文回答
- 自定义提问

上下文策略：

- 默认发送选中文本。
- 用户可选择附加前后段落。
- EPUB 可附加当前章节标题。
- PDF 可附加页码和前后文本块。
- 发送前在 AI 面板展示“将发送的上下文范围”。

隐私策略：

- 默认不自动上传书籍内容。
- AI 请求会展示将发送的上下文范围。
- 设置中允许关闭所有联网 AI 功能。
- API Key 存在系统安全存储中。

保存策略：

- AI 对话保存到 ai_conversations。
- 用户可将回答保存为笔记。
- 保存为笔记时关联 book_id、location、source_text。

### 7.11 设置

设置分组：

- 阅读设置
- 外观主题
- 文件与存储
- 转换工具
- AI 设置
- 隐私与安全
- 备份与导出
- 关于

阅读设置：

- 默认字号
- 默认字体
- 默认行高
- 默认页边距
- 默认阅读模式
- 打开书籍时恢复上次位置

AI 设置：

- Provider
- Base URL
- API Key
- 模型名称
- 温度
- 最大上下文长度
- 是否流式输出
- 默认系统提示词

导出设置：

- 导出全部笔记为 Markdown
- 导出某本书笔记为 Markdown
- 导出书签 CSV
- 导出数据库备份

## 8. 信息架构与菜单布局

### 8.1 移动端主导航

底部导航 4 个 Tab：

1. 书库
2. 搜索
3. 笔记
4. 设置

阅读器不放在底部导航中。打开书籍后进入沉浸式阅读界面，通过返回手势或返回按钮回到书库。

### 8.2 桌面端主布局

桌面端采用三栏结构：

```text
左侧栏：导航与分类
中间区：书库、搜索结果、笔记列表、设置页面
右侧栏：详情、过滤器、AI 面板或笔记预览
```

左侧栏：

- PageSage 标识
- 书库
- 搜索
- 笔记
- 分类目录树
- 设置入口

顶部工具栏：

- 导入
- 扫描文件夹
- 搜索框
- 视图切换
- 排序
- 筛选

右侧栏：

- 未选中时隐藏或显示快捷统计。
- 选中书籍时显示书籍详情。
- 阅读时显示目录、书签、笔记或 AI。

### 8.3 阅读器布局

移动端：

```text
顶部工具栏：返回、标题、搜索、目录、更多
正文区域：全屏阅读
底部工具栏：进度、上一章、下一章、字号、主题
浮动菜单：高亮、笔记、复制、搜索、AI
```

桌面端：

```text
顶部工具栏：返回、书名、页码/进度、搜索、布局、设置
左侧可收起面板：目录
中间阅读区：EPUB/PDF
右侧可收起面板：书签、笔记、AI
底部状态栏：当前位置、缩放、字数/页码
```

### 8.4 右键和长按菜单

文本选中菜单：

- 高亮
- 添加笔记
- 复制
- 在书内搜索
- 全局搜索
- AI 解释
- AI 翻译
- AI 总结

书籍卡片菜单：

- 继续阅读
- 详情
- 移动到目录
- 添加标签
- 重建索引
- 重新提取封面
- 从书库移除
- 删除文件

搜索结果菜单：

- 打开位置
- 保存为笔记
- 复制片段
- 对片段提问

## 9. UI 与视觉设计

### 9.1 视觉方向

PageSage 的视觉应保持安静、清晰、适合长时间阅读。整体不做营销感首页，启动后直接进入书库。界面密度中等偏高，桌面端重视扫描效率，移动端重视单手可达和阅读沉浸。

关键词：

- 安静
- 克制
- 清晰
- 低干扰
- 高可读
- 专注内容

### 9.2 色彩

基础色：

- 背景：浅灰白，而不是纯白
- 主文字：接近黑色的中性灰
- 次级文字：中灰
- 强调色：深青色或墨绿色
- 警示色：柔和红色
- 信息色：蓝色

阅读主题：

- 白昼：浅灰白背景，深灰文字
- 纸张：浅暖色背景，深棕灰文字
- 夜间：深灰背景，浅灰文字
- 高对比：黑底白字或白底黑字
- 护眼：低饱和绿色或灰绿色背景

要求：

- 阅读主题可以偏色，但应用主界面不能被单一颜色支配。
- 文本对比度应满足 WCAG AA。
- 高亮颜色不能影响正文可读性。

### 9.3 字体

中文默认：

- 系统字体优先
- Android：Noto Sans CJK 或系统默认
- Windows：Microsoft YaHei UI 或系统默认

英文默认：

- 系统 UI 字体

阅读字体：

- 系统默认
- 衬线字体
- 无衬线字体
- 等宽字体，技术书可用
- 用户自定义字体，后续版本

### 9.4 组件规范

按钮：

- 工具栏使用图标按钮。
- 主要命令使用图标加文字按钮。
- 危险操作使用确认对话框。

卡片：

- 书籍卡片圆角不超过 8px。
- 卡片只用于书籍、笔记、搜索结果等重复项目。
- 页面区域不做嵌套卡片。

面板：

- 桌面端右侧面板可固定、收起、调整宽度。
- 移动端面板使用底部抽屉或全屏页。

输入：

- 搜索框支持即时建议，但回车后进入完整搜索结果页。
- 设置项用开关、分段控件、滑块、下拉菜单等符合语义的控件。

### 9.5 状态设计

空状态：

- 空书库：显示导入按钮和扫描文件夹按钮。
- 空搜索：展示搜索范围提示和重建索引入口。
- 空笔记：展示最近阅读书籍入口。

加载状态：

- 导入中显示任务进度。
- 索引中不阻塞阅读。
- MOBI 转换显示当前阶段。

错误状态：

- 转换失败：展示 Calibre 安装状态、错误日志入口、重试按钮。
- PDF 文本不可提取：提示可阅读但无法全文搜索，后续可 OCR。
- AI 请求失败：展示 provider、模型、网络和密钥相关错误提示。

## 10. 核心交互流程

### 10.1 首次启动

1. 用户打开应用。
2. 显示空书库。
3. 主按钮为“导入书籍”。
4. 次按钮为“扫描文件夹”。
5. 底部或设置中提供 AI 配置入口，但不强制配置。

原则：

- 不做冗长引导页。
- 不要求登录。
- 不要求先配置 AI。

### 10.2 导入 EPUB/PDF

1. 用户点击导入。
2. 选择一个或多个文件。
3. 应用复制文件到内部书库目录。
4. 提取元数据和封面。
5. 写入 books 表。
6. 后台建立全文索引。
7. 书籍立即出现在书库中。
8. 索引进度在书籍详情或任务中心显示。

### 10.3 导入 MOBI

1. 用户选择 MOBI 文件。
2. 应用检测 ebook-convert。
3. 若未安装，提示安装 Calibre。
4. 若已安装，进入转换任务。
5. 转换成功后导入生成的 EPUB。
6. 转换失败时保留任务日志，支持重试。

### 10.4 阅读并记忆进度

1. 用户点击书籍卡片。
2. 应用加载上次进度。
3. 阅读器跳转到对应位置。
4. 用户翻页或滚动。
5. 应用 debounce 保存位置。
6. 用户返回书库。
7. 书籍卡片显示最新进度。

### 10.5 添加书签

1. 阅读器中点击书签图标。
2. 当前页或当前位置创建书签。
3. 图标进入已收藏状态。
4. 用户可打开书签面板编辑备注。
5. 再次点击可取消书签。

### 10.6 划线和笔记

1. 用户选中文本。
2. 浮动菜单出现。
3. 用户点击高亮。
4. 高亮保存并立刻渲染。
5. 用户点击笔记则打开笔记输入面板。
6. 保存后笔记关联到原文位置。

### 10.7 全局搜索

1. 用户进入搜索页。
2. 输入关键词。
3. 应用同时搜索书籍元数据、正文索引、笔记和 AI 回答。
4. 结果按类型分组或混排。
5. 用户可筛选书籍、格式、分类、类型。
6. 点击结果跳转到书籍位置或笔记详情。

### 10.8 划词 AI 问答

1. 用户选中文本。
2. 点击 AI。
3. AI 面板打开，显示选中文本和快捷动作。
4. 用户选择“解释”或输入问题。
5. 应用展示将发送的上下文范围。
6. 用户确认或直接发送，取决于隐私设置。
7. AI 流式输出回答。
8. 用户可复制、重新生成、保存为笔记。

## 11. 数据模型

### 11.1 books

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| title | text | 标题 |
| author | text | 作者 |
| format | text | epub/pdf/mobi_converted |
| original_file_path | text | 原始文件路径 |
| library_file_path | text | 应用内文件路径 |
| cover_path | text | 封面路径 |
| file_hash | text | 去重 hash |
| file_size | integer | 文件大小 |
| language | text | 语言 |
| description | text | 简介 |
| category_id | text | 主分类 |
| created_at | integer | 导入时间 |
| updated_at | integer | 更新时间 |
| last_opened_at | integer | 最近阅读时间 |
| indexing_status | text | pending/running/done/failed |

### 11.2 categories

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| parent_id | text | 父目录 |
| name | text | 名称 |
| sort_order | integer | 排序 |
| created_at | integer | 创建时间 |

### 11.3 tags

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| name | text | 标签名 |
| color | text | 标签颜色 |

### 11.4 book_tags

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| book_id | text | 书籍 id |
| tag_id | text | 标签 id |

### 11.5 reading_progress

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| book_id | text | 书籍 id |
| locator | text | JSON 定位信息 |
| progress | real | 0 到 1 |
| chapter_title | text | 当前章节 |
| page_number | integer | PDF 页码 |
| updated_at | integer | 更新时间 |

locator 示例：

```json
{
  "type": "epub",
  "cfi": "epubcfi(...)",
  "href": "chapter-01.xhtml",
  "chapterIndex": 1,
  "progress": 0.1234
}
```

```json
{
  "type": "pdf",
  "page": 12,
  "scrollOffset": 320,
  "zoom": 1.25,
  "progress": 0.218
}
```

### 11.6 bookmarks

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| book_id | text | 书籍 id |
| locator | text | JSON 定位 |
| title | text | 书签标题 |
| note | text | 备注 |
| excerpt | text | 附近原文 |
| created_at | integer | 创建时间 |

### 11.7 annotations

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| book_id | text | 书籍 id |
| locator | text | JSON 定位 |
| selected_text | text | 选中文本 |
| color | text | 高亮颜色 |
| style | text | highlight/underline |
| note_id | text | 关联笔记 |
| created_at | integer | 创建时间 |
| updated_at | integer | 更新时间 |

### 11.8 notes

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| book_id | text | 书籍 id |
| annotation_id | text | 关联标注 |
| title | text | 标题 |
| content | text | Markdown 内容 |
| source_text | text | 原文 |
| locator | text | JSON 定位 |
| created_at | integer | 创建时间 |
| updated_at | integer | 更新时间 |

### 11.9 ai_conversations

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| book_id | text | 书籍 id |
| locator | text | JSON 定位 |
| provider | text | AI provider |
| model | text | 模型 |
| prompt | text | 用户问题 |
| context_text | text | 发送上下文 |
| answer | text | 回答 |
| source_text | text | 选中文本 |
| created_at | integer | 创建时间 |

### 11.10 search_chunks

普通表：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | text | UUID |
| book_id | text | 书籍 id |
| source_type | text | book/note/bookmark/ai |
| locator | text | JSON 定位 |
| title | text | 章节或来源标题 |
| text | text | 可搜索正文 |
| sort_order | integer | 书内顺序 |

FTS5 虚拟表：

```sql
CREATE VIRTUAL TABLE search_chunks_fts USING fts5(
  title,
  text,
  content='search_chunks',
  content_rowid='rowid'
);
```

## 12. 搜索设计

### 12.1 文本切块

EPUB：

- 优先按章节切块。
- 章节过长时按段落合并到 800 到 1500 字左右。
- 保存章节 href、章节标题、段落序号。

PDF：

- 优先按页切块。
- 单页文本过长时按段落或行块拆分。
- 保存页码和页内序号。

笔记和 AI：

- 一条笔记一个 chunk。
- 一条 AI 回答一个 chunk，同时索引问题和回答。

### 12.2 排名

排名因子：

- 标题命中高于正文命中。
- 书名、作者命中高于书内正文。
- 最近阅读书籍加权。
- 完整短语命中高于分词命中。
- 笔记命中可单独提升，因为它代表用户已关注内容。

### 12.3 搜索结果展示

结果卡片包含：

- 来源类型
- 书名
- 章节或页码
- 命中片段
- 高亮关键词
- 最近修改或导入时间
- 快捷操作：打开、复制、提问、保存为笔记

## 13. 阅读渲染设计

### 13.1 EPUB 渲染

WebView 加载本地 renderer 页面：

```text
assets/renderer/epub/index.html
assets/renderer/epub/epub.min.js
assets/renderer/epub/bridge.js
assets/renderer/epub/theme.css
```

Dart 与 JS 通信：

- Dart -> JS：
  - openBook
  - goToLocation
  - setTheme
  - setFontSize
  - searchInBook
  - applyAnnotations

- JS -> Dart：
  - onReady
  - onLocationChanged
  - onTextSelected
  - onBookmarkRequested
  - onSearchResultClicked
  - onRenderError

### 13.2 PDF 渲染

WebView 加载 PDF.js viewer：

```text
assets/renderer/pdf/viewer.html
assets/renderer/pdf/pdf.min.js
assets/renderer/pdf/pdf.worker.min.js
assets/renderer/pdf/bridge.js
```

首版目标：

- 打开本地 PDF
- 页码跳转
- 缩放
- 文本选择
- 搜索
- 位置回传

后续增强：

- 区域高亮
- 手写批注
- OCR
- 双页模式

### 13.3 注入样式

EPUB 主题通过 CSS 变量控制：

```css
:root {
  --reader-bg: #f7f7f4;
  --reader-fg: #252525;
  --reader-link: #246b61;
  --reader-font-size: 18px;
  --reader-line-height: 1.7;
  --reader-margin: 32px;
}
```

PDF 主题首版只控制外层背景和工具栏。PDF 页面本身不强行反色，夜间模式可作为后续增强。

## 14. AI 设计

### 14.1 Provider 接口

```dart
abstract class AiProvider {
  Stream<AiChunk> streamChat(AiRequest request);
  Future<List<AiModel>> listModels();
}
```

AiRequest：

- provider
- model
- systemPrompt
- userPrompt
- context
- temperature
- maxTokens

### 14.2 上下文包

```json
{
  "book": {
    "title": "Example Book",
    "author": "Author"
  },
  "location": {
    "type": "epub",
    "chapterTitle": "Chapter 3",
    "progress": 0.34
  },
  "selectedText": "...",
  "nearbyText": "...",
  "userQuestion": "解释这段话"
}
```

### 14.3 默认提示词

系统提示词原则：

- 回答必须基于用户提供的文本。
- 不确定时说明不确定。
- 引用原文关键词，不编造书外事实。
- 默认使用用户界面语言回答。
- 对技术内容给出结构化解释。

### 14.4 AI 面板

面板结构：

- 顶部：当前选中文本摘要
- 快捷动作：解释、总结、翻译、要点、提问
- 输入框：自定义问题
- 上下文范围：仅选中文本、前后段落、当前章节
- 回答区：流式输出
- 操作区：复制、保存为笔记、重新生成

## 15. 文件与存储

### 15.1 应用目录

```text
PageSageData/
  library/
    books/
    converted/
    covers/
  database/
    pagesage.sqlite
  cache/
    render/
    thumbnails/
  logs/
  exports/
```

### 15.2 文件命名

书籍文件按 hash 分目录：

```text
library/books/ab/cd/<book_id>.epub
library/books/ef/01/<book_id>.pdf
library/converted/<book_id>.epub
```

优点：

- 避免标题中的特殊字符导致路径问题。
- 避免同名文件冲突。
- 便于去重和校验。

### 15.3 删除策略

删除书籍时提供两个选项：

- 从书库移除：删除数据库记录和应用内副本，保留源文件。
- 删除应用副本和相关数据：删除书籍、封面、索引、书签、笔记和 AI 记录。

如果是用户导入时复制进应用目录，默认删除应用副本，不删除原始源文件。

## 16. 性能要求

### 16.1 书库

- 1000 本书以内列表滚动保持流畅。
- 封面缩略图异步加载并缓存。
- 搜索输入 debounce 200 到 300ms。

### 16.2 阅读器

- EPUB 打开常规书籍小于 2 秒。
- PDF 首屏渲染优先，不等待全文索引。
- 翻页和滚动不因保存进度而卡顿。

### 16.3 索引

- 导入后后台索引。
- 大书索引可暂停和恢复。
- 索引失败不影响打开阅读。

### 16.4 AI

- 流式输出，首 token 之后立即显示。
- 长上下文需要提示用户成本和延迟。
- 请求可取消。

## 17. 安全与隐私

原则：

- 默认不上传任何书籍内容。
- AI 请求必须明确上下文范围，不自动上传整本书；触发方式由具体功能设计决定。
- API Key 使用系统安全存储。
- 本地数据库后续支持加密。
- 导出文件由用户明确选择位置。

风险控制：

- AI 面板展示上下文范围。
- 设置中提供“每次 AI 请求前确认”。
- 对外部 provider 标注“数据将发送到第三方服务”。
- 日志不记录完整 API Key。
- 错误日志中避免保存大段书籍正文。

## 18. 可访问性

要求：

- 支持系统字号或应用内字号。
- 支持高对比主题。
- 所有图标按钮提供 tooltip 或语义标签。
- 键盘可操作，桌面端尤其重要。
- 搜索结果、书签、目录支持方向键导航。
- 阅读器支持快捷键。

桌面快捷键建议：

| 快捷键 | 功能 |
| --- | --- |
| Ctrl+O | 导入书籍 |
| Ctrl+F | 当前书内搜索 |
| Ctrl+Shift+F | 全局搜索 |
| Ctrl+B | 添加书签 |
| Ctrl+Plus | 放大字号或缩放 |
| Ctrl+Minus | 缩小字号或缩放 |
| Esc | 关闭面板或退出选择 |
| Left/Right | 上一页/下一页 |

## 19. 图片资源规划

不建议用 imagegen 生成工具栏图标。工具栏图标应使用 Flutter Material Icons、Lucide 或其他矢量图标库，保证清晰、可主题化、可访问。

适合用 imagegen 生成的位图资源：

1. App 图标  
   用途：启动器、任务栏、应用列表。  
   风格：书页、页边批注、轻微智能感，不要复杂文字。  

2. 空书库插画  
   用途：首次启动和空书库状态。  
   风格：安静书桌、少量书页、导入入口，不出现具体品牌。  

3. 空搜索插画  
   用途：无搜索结果。  
   风格：放大镜、页面片段、轻量信息感。  

4. 空笔记插画  
   用途：没有笔记时。  
   风格：页边便签、荧光笔、简洁构图。  

5. 默认封面模板  
   用途：书籍无封面时。  
   类型：
   - 通用
   - 小说
   - 技术
   - 论文
   - 历史
   - 语言学习

6. AI 面板插画  
   用途：AI 未开始对话时。  
   风格：页面上的批注光标或问答气泡，克制，不科幻。

7. 应用商店宣传图  
   用途：后续发布。  
   类型：
   - 手机阅读场景
   - 桌面书库场景
   - 划词 AI 问答场景
   - 全局搜索场景

示例 imagegen 提示词：

```text
Use case: logo-brand
Asset type: app icon
Primary request: PageSage app icon for a local-first intelligent ebook reader
Subject: an open book page with a subtle page-margin annotation mark and a small intelligent sparkle
Style/medium: polished modern app icon, vector-friendly 3D illustration
Composition/framing: centered symbol, simple silhouette, readable at small sizes
Color palette: warm off-white paper, deep graphite, restrained teal accent
Constraints: no text, no watermark, no brand logos, no complex background
```

```text
Use case: illustration-story
Asset type: empty library state illustration
Primary request: a quiet reading desk with a few books and loose pages ready to be imported
Style/medium: clean editorial illustration
Composition/framing: centered subject with generous whitespace for UI around it
Color palette: soft neutral background, graphite text tones, restrained teal accents
Constraints: no text, no watermark, not childish, not busy
```

## 20. 开发环境要求

### 20.1 必需

- Git
- Flutter stable
- Dart，随 Flutter 安装
- Android Studio 或 VS Code
- Android SDK
- Java JDK
- Visual Studio 2022，包含 Desktop development with C++ workload
- SQLite 开发与调试工具，可选

### 20.2 可选但推荐

- Calibre，用于 MOBI 转 EPUB
- Node.js，用于维护 epub.js、PDF.js 静态资源构建脚本
- Python，用于辅助脚本
- uv，用于 Python 脚本依赖管理

### 20.3 当前机器检查结论

当前 Windows 环境已经具备：

- Git
- Node.js
- npm 和 pnpm
- Java 21
- Android SDK 和 ADB
- Python
- Rust
- Visual Studio 2022 Native Desktop workload

需要处理：

- Flutter 已安装，但命令行运行超时，需要修复或重装 Flutter stable。
- 未检测到 Calibre 的 ebook-convert，需要手动安装 Calibre。
- iOS 和 macOS 构建需要额外准备 Mac 和 Xcode。

## 21. 里程碑

### 21.1 MVP

目标：可导入、可阅读、可记进度。

范围：

- Flutter 项目初始化
- Android 和 Windows 运行
- 书库列表
- 导入 EPUB 和 PDF
- EPUB 阅读
- PDF 阅读
- 阅读进度保存
- 基础主题和字号
- SQLite 数据库

验收：

- 导入一本 EPUB 后可阅读并恢复进度。
- 导入一本 PDF 后可阅读并恢复页码。
- 关闭应用再打开，书库和进度仍存在。

### 21.2 Alpha

目标：形成完整阅读管理闭环。

范围：

- 分类目录
- 书签
- EPUB 目录跳转
- PDF 页码跳转
- 书内搜索
- 笔记
- 划线
- 全文索引
- 全局搜索

验收：

- 可搜索书籍正文和笔记。
- 搜索结果可跳转原文。
- 书签和笔记可在阅读器内管理。

### 21.3 Beta

目标：加入 AI 和 MOBI 导入。

范围：

- Calibre 检测
- MOBI 转 EPUB
- AI Provider 设置
- 划词 AI 问答
- AI 回答保存为笔记
- 笔记导出 Markdown

验收：

- MOBI 可转换并进入书库。
- 选中文本可调用 AI。
- AI 回答可保存并被全局搜索命中。

### 21.4 v1.0

目标：稳定发布。

范围：

- 性能优化
- 错误恢复
- 备份与导出
- 完整设置页
- 快捷键
- 辅助功能
- 发布打包

验收：

- Android 和 Windows 可打包发布。
- 常见 EPUB/PDF 样本稳定可读。
- 大书库搜索和滚动性能可接受。

## 22. 风险与决策

### 22.1 MOBI 兼容性

风险：MOBI 规格复杂，部分文件可能有 DRM 或转换失败。  
决策：首版使用 Calibre 转换，不自研 MOBI 渲染。

### 22.2 PDF 文本提取

风险：扫描版 PDF 没有文本层，无法全文搜索和划词。  
决策：首版提示“该 PDF 无可提取文本”。OCR 放到后续版本。

### 22.3 WebView 跨平台差异

风险：Android 和 Windows WebView 行为、文件访问、JS bridge 存在差异。  
决策：尽早做 EPUB/PDF renderer spike，先验证打开、选词、位置回传。

### 22.4 AI 隐私

风险：用户不希望书籍内容被上传。  
决策：默认本地优先，展示 AI 上下文范围，允许关闭 AI。

### 22.5 Flutter SDK 状态

风险：当前机器 Flutter 命令超时，影响项目创建和构建。  
决策：先修复或重装 Flutter stable，再初始化工程。

## 23. 近期任务拆分

第一批任务：

1. 修复 Flutter 环境。
2. 创建 Flutter app。
3. 建立基础目录结构。
4. 接入 Drift 和 SQLite。
5. 实现 books、reading_progress 表。
6. 实现书库页面。
7. 实现 EPUB renderer spike。
8. 实现 PDF renderer spike。
9. 实现导入文件流程。
10. 实现阅读进度保存。

第二批任务：

1. 分类目录。
2. 书签。
3. 书内搜索。
4. 文本提取。
5. FTS5 全局搜索。
6. 笔记和划线。

第三批任务：

1. MOBI 转换。
2. AI Provider 设置。
3. 划词 AI 面板。
4. AI 回答保存为笔记。
5. Markdown 导出。

## 24. 待确认问题

1. 首版是否必须支持 iOS，还是先 Android 和 Windows？
2. MOBI 是否接受“安装 Calibre 后转换”的方案？
3. AI 首版是否只支持 OpenAI-compatible API？
4. 是否需要云同步，还是 v1.0 坚持纯本地？
5. 笔记导出是否需要兼容 Obsidian 或 Logseq？
6. 是否需要内置 OCR 支持扫描版 PDF？
7. 书库是否需要多用户或多工作区？
