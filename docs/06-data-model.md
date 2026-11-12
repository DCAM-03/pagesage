# PageSage 数据模型文档

版本：0.1  
日期：2026-06-13  
状态：详细数据模型  

## 1. 数据原则

- 所有用户数据默认保存在本机。
- 数据库使用 SQLite。
- Dart 侧使用 Drift。
- 主键使用 UUID 字符串。
- 时间使用 Unix milliseconds。
- 复杂定位信息使用 JSON 文本保存。
- 全文搜索使用 SQLite FTS5。

## 2. 实体关系

```text
books 1 - 1 reading_progress
books 1 - N bookmarks
books 1 - N annotations
books 1 - N notes
books 1 - N ai_conversations
books 1 - N search_chunks
books N - N tags through book_tags
categories 1 - N books
categories 1 - N categories
annotations 0/1 - 1 notes
```

## 3. books

用途：保存书籍元数据和文件路径。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| title | text | not null | 展示标题 |
| original_title | text | nullable | 原始元数据标题 |
| author | text | nullable | 作者 |
| format | text | not null | epub/pdf/md |
| original_format | text | nullable | 原始文件格式 |
| original_file_path | text | nullable | 用户选择的原始路径 |
| library_file_path | text | not null | 应用内文件路径 |
| cover_path | text | nullable | 封面路径 |
| file_hash | text | not null | 内容 hash |
| file_size | integer | not null | 文件大小 |
| language | text | nullable | 语言 |
| description | text | nullable | 简介 |
| category_id | text | nullable | 主分类 |
| is_favorite | integer | default 0 | 收藏 |
| read_status | text | default unread | unread/reading/finished |
| indexing_status | text | default pending | pending/running/done/failed |
| created_at | integer | not null | 导入时间 |
| updated_at | integer | not null | 更新时间 |
| last_opened_at | integer | nullable | 最近阅读 |

索引：

- `idx_books_file_hash`
- `idx_books_category_id`
- `idx_books_last_opened_at`
- `idx_books_format`

业务规则：

- `file_hash` 默认用于重复检测。
- `title` 可以被用户修改。
- `original_title` 不随用户修改。
- Markdown 目录书的 `file_hash` 以规范化目录路径为指纹，不读取目录内容；`library_file_path` 指向用户选择的目录，应用不写入该目录，也不在移除书籍时删除它。

## 4. categories

用途：分类目录树。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| parent_id | text | nullable | 父分类 |
| name | text | not null | 分类名 |
| sort_order | integer | default 0 | 排序 |
| icon | text | nullable | 图标名，P2 |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

规则：

- 删除分类不删除书籍。
- 系统分类可以不入表，也可以入表并设置 reserved flag，后续决定。

## 5. tags

用途：书籍和笔记标签。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| name | text | unique | 标签名 |
| color | text | nullable | 颜色 |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

## 6. book_tags

用途：书籍标签多对多。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| book_id | text | primary key part | 书籍 |
| tag_id | text | primary key part | 标签 |

索引：

- `idx_book_tags_tag_id`

## 7. reading_progress

用途：每本书的主阅读进度。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| book_id | text | primary key | 书籍 id |
| locator | text | not null | JSON locator |
| progress | real | default 0 | 0 到 1 |
| chapter_title | text | nullable | 当前章节 |
| page_number | integer | nullable | PDF 页码 |
| updated_at | integer | not null | 更新时间 |

EPUB locator：

```json
{
  "type": "epub",
  "cfi": "epubcfi(...)",
  "href": "chapter-03.xhtml",
  "chapterIndex": 3,
  "chapterOffset": 1280,
  "chapterEndOffset": 1368,
  "progress": 0.42,
  "excerpt": "nearby text"
}
```

PDF locator：

```json
{
  "type": "pdf",
  "page": 12,
  "scrollOffset": 320.0,
  "zoom": 1.25,
  "progress": 0.42,
  "excerpt": "nearby text"
}
```

Markdown locator：

```json
{
  "type": "markdown",
  "href": "notes/chapter-01.md",
  "chapterIndex": 3,
  "chapterOffset": 1280,
  "chapterEndOffset": 1368,
  "progress": 0.42,
  "excerpt": "nearby text",
  "folderFileLocal": true
}
```

规则：

- 每本书只有一条主记录。
- 阅读器位置变化 debounce 保存。
- 应用进入后台时立即保存。
- EPUB/Markdown 分页、搜索跳转和标注优先使用 `href + chapterIndex + chapterOffset/chapterEndOffset` 恢复位置；旧数据没有 offset 时继续回退到 chapter/progress/excerpt。Markdown 的 `cfi` 字段为空。
- 文件夹书的 `href` 是文件夹内相对路径，`chapterIndex` / `chapterOffset` 属于该文件，`progress` 是按文件大小加权的全书进度；`folderFileLocal: true` 标记这套 P7 语义。旧版「合并文档」locator 在打开时映射一次，映射失败则提示重新选择目录，不静默跳错章节。

## 8. bookmarks

用途：保存阅读位置。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| book_id | text | not null | 书籍 |
| locator | text | not null | JSON locator |
| title | text | nullable | 书签标题 |
| note | text | nullable | 备注 |
| excerpt | text | nullable | 附近原文 |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

索引：

- `idx_bookmarks_book_id`
- `idx_bookmarks_created_at`

## 9. annotations

用途：划线和图片批注。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| book_id | text | not null | 书籍 |
| locator | text | not null | JSON locator（图片批注也只用于跳页） |
| selected_text | text | not null | 选中文本；图片批注存图注或空串 |
| color | text | not null | yellow/blue/green/red/purple |
| style | text | not null | highlight/underline |
| target | text | not null, default `text` | `text` / `image` |
| image_anchor | text | nullable | 图片锚点 JSON，见 `13-image-annotations.md` §3.1 |
| note_id | text | nullable | 关联笔记 |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

索引：

- `idx_annotations_book_id`
- `idx_annotations_note_id`

规则：

- 删除 annotation 时，若关联 note 的类型为 `comment`，该批注随标注一并删除；普通关联笔记保留，并在确认框中说明。
- 只删除批注时保留 annotation，并清空其 `note_id`；从笔记页删除关联笔记也执行同样的解除关联。
- EPUB 高亮定位以 CFI 为主。
- PDF 高亮坐标后续增强。
- 图片批注的主键是锚点里的「哪张图」（页 + 序号 + 资源名），坐标只作兜底；不要用矩形当主键，同一张图在不同 `/Rotate` 下矩形不同。
- 图片批注的坐标一律是显示框（已应用 `/Rotate`）的 0..1、y 向下，与 `ReaderRect` 一致。
- 迁移：schemaVersion 4 → 5 新增 `target`（默认 `text`）与 `image_anchor`（`migrator.addColumn`），不回填、不清数据。

## 10. notes

用途：保存用户笔记。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| book_id | text | nullable | 关联书籍 |
| annotation_id | text | nullable | 关联划线 |
| title | text | nullable | 标题 |
| content | text | not null | Markdown 内容 |
| source_text | text | nullable | 原文 |
| locator | text | nullable | JSON locator |
| note_type | text | not null | text/excerpt/comment/ai/question |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

索引：

- `idx_notes_book_id`
- `idx_notes_annotation_id`
- `idx_notes_updated_at`

`comment` 表示附着在划线上的短批注，复用既有文本列，无 schema 变更。只有该类型会被当作标注批注展示和删除；其它关联笔记仍按普通笔记保留。

## 11. ai_conversations

用途：保存 AI 问答记录。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| book_id | text | nullable | 书籍 |
| locator | text | nullable | JSON locator |
| provider | text | not null | provider |
| model | text | not null | 模型 |
| prompt | text | not null | 用户问题 |
| context_text | text | nullable | 发送上下文 |
| answer | text | not null | 回答 |
| source_text | text | nullable | 选中文本 |
| note_id | text | nullable | 保存为笔记后的 id |
| thread_id | text | nullable | 同一上下文下的多轮对话归组；升级前旧行为 null，按单轮展示 |
| context_snapshot | text | nullable | v1 JSON：范围、截断状态与有序结构化来源，含引用 id、正文、书籍、locator、来源区间；null 表示旧记录未保存来源快照 |
| created_at | integer | not null | 创建时间 |

索引：

- `idx_ai_conversations_book_id`
- `idx_ai_conversations_created_at`

隐私：

- 不保存 API Key。
- 用户可清空本表。

迁移：

- schemaVersion 3 → 4 新增 `thread_id`（`migrator.addColumn`），不清数据。
- 旧会话不回填线程 id：事后按时间或文本相近度归组只是猜测，猜错比不归组更糟。
- schemaVersion 6 → 7 新增 nullable `context_snapshot`，保留原始上下文、线程及笔记关联；旧记录不伪造分段来源。
- 同一创建时间的轮次以 SQLite rowid 保持保存先后顺序。恢复同书同线程的完整历史后从最新轮继续；无 thread_id 的历史单轮使用其 id 作为后续续问的线程键。
- 每轮快照保存当时实际发送的引用正文，不以重新检索替代历史证据；编辑正文后清除精确来源区间，保留原定位用于查看来源。文件日后发生变化时，历史快照不保证仍与当前文件逐字一致。

## 12. search_chunks

用途：全文搜索内容源表。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| book_id | text | nullable | 书籍 |
| parent_id | text | nullable | 所属父块的稳定索引 id；旧行或非正文来源为空 |
| source_type | text | not null | book/note/bookmark/ai |
| source_id | text | nullable | 来源 id |
| locator | text | nullable | JSON locator |
| title | text | nullable | 章节或来源标题 |
| text | text | not null | 可搜索正文 |
| sort_order | integer | default 0 | 排序 |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

索引：

- `idx_search_chunks_book_id`
- `idx_search_chunks_parent_id`
- `idx_search_chunks_source_type`
- `idx_search_chunks_source_id`

### 12.1 search_parent_chunks

用途：保存可选的父块上下文。父块不进入 FTS；正文检索仍以 `search_chunks` 子块为入口，命中后通过 `parent_id` 读取同一父块。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | 稳定父块 id（同一书、格式和索引位置） |
| book_id | text | nullable | 书籍 |
| source_type | text | not null | 当前为 book |
| source_id | text | nullable | 父块索引键 |
| locator | text | nullable | 父块 locator JSON |
| title | text | nullable | 章节标题路径 |
| text | text | not null | 父块原文 |
| sort_order | integer | default 0 | 排序 |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

索引：`idx_search_parent_chunks_book_id`。

迁移：schemaVersion 5 → 6 新建 `search_parent_chunks`，并给 `search_chunks` 增加可空 `parent_id`。旧索引不猜测父块关联，保留原搜索能力；重建索引后才会生成父子块。删除书籍时同时删除父块与子块。

FTS5：

```sql
CREATE VIRTUAL TABLE search_chunks_fts USING fts5(
  title,
  text,
  content='search_chunks',
  content_rowid='rowid'
);
```

触发器，示例：

```sql
CREATE TRIGGER search_chunks_ai AFTER INSERT ON search_chunks BEGIN
  INSERT INTO search_chunks_fts(rowid, title, text)
  VALUES (new.rowid, new.title, new.text);
END;
```

## 13. app_settings

用途：保存非敏感设置。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| key | text | primary key | 设置键 |
| value | text | not null | JSON 或字符串 |
| updated_at | integer | not null | 更新时间 |

示例 key：

- `theme.mode`
- `reader.defaultFontSize`
- `reader.defaultLineHeight`
- `reader.defaultTheme`
- `ai.provider`
- `ai.model`
- `privacy.confirmBeforeAiRequest`

敏感信息：

- API Key 不存本表，使用 secure storage。

## 14. import_tasks

用途：导入、转换、索引任务记录。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | text | primary key | UUID |
| type | text | not null | import/index/export |
| status | text | not null | queued/running/done/failed/cancelled |
| source_path | text | nullable | 来源路径 |
| target_path | text | nullable | 目标路径 |
| book_id | text | nullable | 相关书籍 |
| progress | real | default 0 | 进度 |
| message | text | nullable | 状态说明 |
| error | text | nullable | 错误详情 |
| created_at | integer | not null | 创建时间 |
| updated_at | integer | not null | 更新时间 |

## 15. note_tags

用途：笔记标签，P2。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| note_id | text | primary key part | 笔记 |
| tag_id | text | primary key part | 标签 |

## 16. 数据删除规则

删除书籍：

- 删除 books。
- 删除 reading_progress。
- 删除 bookmarks。
- 删除 annotations。
- 删除 notes，需确认。
- 删除 ai_conversations，需确认或默认随书删除。
- 删除 search_chunks。
- 删除应用内文件。

从书库移除：

- 删除应用内副本和数据库记录。
- 不删除 original_file_path 指向的源文件。

清空 AI 历史：

- 删除 ai_conversations。
- 删除 source_type = ai 的 search_chunks。
- 不删除已保存为普通笔记的内容，除非用户选择。

## 17. Drift 建模建议

每类表放独立文件：

```text
lib/core/database/tables/books.dart
lib/core/database/tables/notes.dart
lib/core/database/daos/book_dao.dart
```

Dao：

- BookDao。
- CategoryDao。
- ProgressDao。
- BookmarkDao。
- AnnotationDao。
- NoteDao。
- SearchDao。
- TaskDao。
- SettingsDao。

Repository：

- BookRepository 组合 BookDao、FileRepository。
- SearchRepository 组合 SearchDao、Indexer。
- NoteRepository 组合 NoteDao、SearchRepository。

## 18. 迁移策略

开发期：

- schemaVersion 从 1 开始。
- 每次变更更新 migration。
- 可提供 debug reset。

发布后：

- 不允许无提示清库。
- 迁移前可备份数据库。
- 大迁移需要进度提示。

## 19. 数据备份

备份内容：

- SQLite 数据库。
- covers。
- 可选 books 文件。

备份形式，P2：

```text
pagesage-backup-YYYYMMDD.zip
```

轻量导出：

- Notebook Markdown：聚合书签、标注、笔记和 AI 历史，包含 locator JSON。
- 标注 JSON：包含标注 id、书籍 id、样式、选中文本和 locator JSON，便于迁移或重建索引。

恢复规则，P2：

- 版本兼容检查。
- 文件完整性检查。
- 冲突处理。
