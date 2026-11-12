# README 界面图片

这些图片来自 `test/ui_screenshots_test.dart` 的真实生产界面组件，使用受控演示数据，
通过 Flutter widget 测试离屏生成。不读取个人书库，不启动桌面窗口。

| 文件 | 场景 |
| --- | --- |
| `library-light.png` | 桌面书库、主导航与分类侧栏，浅色主题 |
| `library-dark.png` | 同一场景，深色主题 |
| `search.png` | 正文与笔记的搜索结果 |
| `notes.png` | 笔记分组、列表与内容详情 |

## 重新生成

先恢复项目依赖，并生成自有样本：

```bash
dart run tool/generate_manual_samples.dart
```

在仓库根目录依次执行：

```bash
flutter test test/ui_screenshots_test.dart --no-pub --concurrency=1 \
  --dart-define=UPDATE_PAGESAGE_SCREENSHOTS=true \
  --dart-define=PAGESAGE_README_SCREENSHOTS=true \
  --dart-define=PAGESAGE_SCREENSHOT_FILTER=shell-command-bar-theme

flutter test test/ui_screenshots_test.dart --no-pub --concurrency=1 \
  --dart-define=UPDATE_PAGESAGE_SCREENSHOTS=true \
  --dart-define=PAGESAGE_README_SCREENSHOTS=true \
  --dart-define=PAGESAGE_SCREENSHOT_FILTER=desktop-1024
```

将 `.codex-run/ui-screenshots/` 中的 `shell-command-bar-theme.png`、
`shell-command-bar-theme-dark.png`、`desktop-1024-search.png`、
`desktop-1024-notes.png` 按上表顺序复制到本目录。

当前截图入口使用 Linux Noto CJK 字体路径。截完需逐张检查中文、按钮、图标、
布局与脱敏内容；不要把缺字方格、测试字体或加载态放进 README。
截图主题对 Chip 标签单独指定中文字体，不能只替换正文的 `textTheme`。

这些图片只证明受控数据下的布局，不证明原生文件选择、持久化或各平台运行效果。
图片仅供仓库文档使用，不进入 Flutter 应用资源。
