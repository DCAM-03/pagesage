# PageSage 图片资源规划

版本：0.1  
日期：2026-06-13  
状态：资源规划（含历史设计；当前分发状态见 [测试版说明](beta.md)）

## 1. 原则

PageSage 的图片资源用于增强空状态、品牌识别和发布物料，不用于替代常规 UI 图标。

使用图片的地方：

- App 图标。
- 空状态插画。
- 默认封面。
- AI 面板插画。
- 应用商店宣传图。

不使用图片的地方：

- 工具栏图标。
- 菜单图标。
- 设置项图标。
- 状态图标。

这些应使用 Flutter Material Icons 或后续统一图标库。

## 2. 资源目录建议

```text
assets/
  images/
    brand/
      app-icon-source.png        # 1024，浅色版，带圆角底
      app-icon-source-dark.png   # 1024，深色版
      app-icon-source.svg        # 矢量源，浅色版
      app-icon-source-dark.svg
      app-logo-mark.png          # 512，带底的品牌图
      app-logo-mark-dark.png
      app-mark-light.png         # 512，透明底，供应用内标题栏使用
      app-mark-dark.png
    empty-states/
      empty-library.png
      empty-search.png
      empty-notes.png
      ai-empty.png
    covers/
      cover-default.png
      cover-fiction.png
      cover-technical.png
      cover-paper.png
      cover-history.png
      cover-language.png
    store/
      android-feature-graphic.png
      screenshot-library.png
      screenshot-reader.png
      screenshot-ai.png
```

平台图标不放在 `assets/` 下：

- `linux/icons/dev.pagesage.pagesage-*.png`：hicolor 各尺寸，由
  `tool/install_desktop_entry.sh` 安装到 `~/.local/share/icons/hicolor/`。
- `android/app/src/main/res/mipmap-*/ic_launcher.png` 与
  `mipmap-anydpi-v26/ic_launcher.xml`（adaptive icon）。
- `windows/runner/resources/app_icon.ico`。
- `web/icons/`、`web/favicon.png`。

### 2.1 Linux 桌面集成

Linux 已有 x86_64 测试分发包，安装方式见 [Linux 分发](linux-distribution.md)。
本机开发、手动验证和分发包都需要正确的任务栏图标：

- **Wayland 下没有 `_NET_WM_ICON` 可读**，二进制路径也不是图标名。runner 不显式
  设置图标名时，合成器只能退回图标主题里的通用兜底——也就是本机看到的橙色 W
  （Breeze 的 `wayland.svg`）。
- `linux/runner/my_application.cc` 调 `gtk_window_set_icon_name()` 与
  `gtk_window_set_default_icon_name()`，二者都指向 `dev.pagesage.pagesage`。
- 还要有 `.desktop` 文件与 hicolor 图标，否则名字解析不到东西：
  `linux/dev.pagesage.pagesage.desktop` + `tool/install_desktop_entry.sh`。
- 图标随 Linux 包提供，安装器创建桌面入口；其他发行版仍需单独验收。

## 3. App 图标

用途：

- Android launcher（含 adaptive icon）。
- Windows app icon。
- Linux 桌面条目与任务栏。
- Web favicon 与 PWA 图标。
- 安装包。

视觉方向（v3，2026-10-21 重做）：

- **抽象的两块页片**，在中缝相遇，像从上方看到的一本打开的书。
  不画书脊、书页纹理、装饰高光。
- **墨黑与纸白互为底与形**，浅色与深色各一套，切换主题时图标的对比关系不变。
- 一个高饱和点睛色：浅色用珊瑚红 `#E8502C`，深色用青柠绿 `#C9F24F`。
- 纯矢量，无渐变、无投影、无 3D。16 px 仍可辨。

配色：

| 位置 | 浅色版 | 深色版 |
| --- | --- | --- |
| 底 | 纸白 `#F2EFE7` | 墨黑 `#121416` |
| 左页 | 墨黑 `#14171A` | 纸白 `#F6F3EA` |
| 右页（点睛） | 珊瑚红 `#E8502C` | 青柠绿 `#C9F24F` |

生成方式：**不要手工导出位图。**

```bash
python3 tool/generate_app_icons.py
./tool/install_desktop_entry.sh   # Linux：装 .desktop 与 hicolor 图标
```

脚本 `tool/generate_app_icons.py` 是唯一几何来源，一次产出品牌源图、Linux
hicolor 全套、Android 五档 launcher + adaptive 前景、Windows `.ico`、
Web 图标。4 倍超采样后 Lanczos 缩放，斜边在 16 px 仍然干净。

验收：

- 16 x 16 下仍能看出是展开的两页。
- 不包含文字。
- 不用渐变，不用投影。
- 浅色与深色两套在同一桌面背景下都能立即分辨。

### 3.1 旧图标

v2（蓝色底 + 米黄写实翻页书）及旧品牌实验已从当前源码树移出，
不随应用或公开文档分发。正式图标以 `assets/images/brand/` 和生成脚本为准。

## 4. 空书库插画

用途：

- 首次启动。
- 没有书籍时。

尺寸：

- 1200 x 800。
- 移动端显示宽度约 240 到 320。

Prompt：

```text
Use case: illustration-story
Asset type: empty library state illustration
Primary request: a quiet reading desk with a few books and loose pages ready to be imported
Style/medium: clean editorial illustration
Composition/framing: centered subject with generous whitespace around it
Color palette: soft neutral background, graphite tones, restrained teal accents
Constraints: no text, no watermark, not childish, not busy
```

验收：

- 能和浅色/深色 UI 搭配。
- 不抢主按钮注意力。
- 无文字。

## 5. 空搜索插画

用途：

- 无搜索结果。
- 索引为空。

Prompt：

```text
Use case: illustration-story
Asset type: empty search state illustration
Primary request: a magnifying glass over a few clean page fragments, suggesting search inside books
Style/medium: clean editorial illustration
Composition/framing: centered compact object with whitespace
Color palette: neutral paper tones, graphite, restrained blue and teal accents
Constraints: no text, no watermark, no clutter
```

## 6. 空笔记插画

用途：

- 没有笔记。
- 没有划线。

Prompt：

```text
Use case: illustration-story
Asset type: empty notes state illustration
Primary request: a page margin with a small note card and a subtle highlighter mark
Style/medium: clean editorial illustration
Composition/framing: simple centered composition, light whitespace
Color palette: warm paper, graphite, soft yellow highlight, restrained teal accent
Constraints: no text, no watermark, not childish
```

## 7. AI 面板空状态

用途：

- AI 面板打开但未发起问题时。

Prompt：

```text
Use case: illustration-story
Asset type: AI panel empty state illustration
Primary request: a book page with a quiet question bubble and a page-margin annotation cursor
Style/medium: minimal editorial illustration
Composition/framing: compact centered composition for a side panel
Color palette: neutral paper, graphite, restrained teal and soft purple accent
Constraints: no text, no watermark, no sci-fi visual effects
```

## 8. 默认封面模板

用途：

- 书籍没有封面时显示。

共同要求：

- 比例 2:3。
- 尺寸 1200 x 1800。
- 不包含真实书名。
- 可以后续在 UI 上叠加标题文字。

### 8.1 通用封面

```text
Use case: product-mockup
Asset type: default ebook cover template
Primary request: a minimal abstract book cover template for a general ebook without a cover
Style/medium: clean graphic illustration
Composition/framing: 2:3 vertical cover, subtle page texture, central abstract page shape
Color palette: off-white, graphite, restrained teal accent
Constraints: no text, no watermark, no logo
```

### 8.2 小说封面

```text
Use case: product-mockup
Asset type: default fiction cover template
Primary request: a quiet abstract fiction ebook cover template
Style/medium: refined editorial illustration
Composition/framing: 2:3 vertical cover, soft horizon-like shape, ample title area
Color palette: muted blue, warm paper, graphite
Constraints: no text, no watermark, no characters
```

### 8.3 技术封面

```text
Use case: product-mockup
Asset type: default technical book cover template
Primary request: a clean technical ebook cover template with subtle grid and code-like structure
Style/medium: modern graphic design
Composition/framing: 2:3 vertical cover, structured grid, clear title area
Color palette: graphite, off-white, restrained teal and blue accents
Constraints: no readable code, no text, no watermark
```

### 8.4 论文封面

```text
Use case: product-mockup
Asset type: default academic paper cover template
Primary request: a minimal academic paper cover template with document layers and citation-like lines
Style/medium: clean editorial graphic
Composition/framing: 2:3 vertical cover, document stack motif, title space
Color palette: white, light gray, graphite, muted blue
Constraints: no readable text, no watermark
```

### 8.5 历史封面

```text
Use case: product-mockup
Asset type: default history book cover template
Primary request: a restrained history ebook cover template with archival paper and map-like texture
Style/medium: refined graphic illustration
Composition/framing: 2:3 vertical cover, subtle map texture, title area
Color palette: aged paper, charcoal, muted green
Constraints: no readable map labels, no text, no watermark
```

### 8.6 语言学习封面

```text
Use case: product-mockup
Asset type: default language learning cover template
Primary request: a clean language learning ebook cover template with page cards and speech marks
Style/medium: modern editorial graphic
Composition/framing: 2:3 vertical cover, simple layered cards, title area
Color palette: off-white, graphite, restrained teal and soft yellow
Constraints: no letters or readable text, no watermark
```

## 9. 商店宣传图

### 9.1 书库场景

用途：

- 展示统一书库和分类管理。

内容：

- Windows 桌面窗口。
- 左侧分类。
- 中间书籍网格。
- 右侧书籍详情。

### 9.2 阅读场景

用途：

- 展示 EPUB/PDF 阅读体验。

内容：

- 阅读器正文。
- 字号和主题面板。
- 安静背景。

### 9.3 AI 场景

用途：

- 展示划词 AI。

内容：

- 选中文本。
- 右侧 AI 面板。
- 回答保存为笔记按钮。

### 9.4 搜索场景

用途：

- 展示全局搜索。

内容：

- 搜索框。
- 正文、笔记、AI 结果分组。
- 高亮片段。

## 10. 生成策略

建议顺序：

1. 先生成 App 图标。
2. 生成空书库插画。
3. 生成默认封面模板。
4. 等 UI 原型稳定后，再生成商店宣传图。

规则：

- 生成后必须保存到项目 `assets/images/` 下。
- 不覆盖已有资源，使用版本号文件名。
- 资源加入 `pubspec.yaml`。
- 位图资源压缩后再发布。

## 11. 暂不生成的资源

暂时不生成：

- 工具栏图标。
- 分类图标。
- 标签图标。
- 设置图标。
- 加载动画。

原因：

- 这些资源应该使用矢量图标或 Flutter 原生组件，保证主题适配和清晰度。

