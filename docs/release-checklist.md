# PageSage 发布检查清单

## 功能验证

- 导入 EPUB，确认书库出现书籍。
- 导入有文本层 PDF，确认书库出现书籍。
- 打开 EPUB，阅读、翻页或滚动、关闭后重新打开，确认恢复位置。
- EPUB 桌面阅读器三栏可用：目录可折叠和调整宽度，右侧上下文栏可切换搜索、书签、标注、笔记、AI。
- 打开 PDF，滚动、翻页、缩放、关闭后重新打开，确认恢复位置。
- 新增书签、删除书签、从书签跳回原文。
- 新增标注和笔记，确认笔记页可见。
- 选中文本后可复制、高亮、添加笔记、本书搜索和发送到 AI。
- 全局搜索书名、EPUB 正文、PDF 正文、笔记、书签、AI 回答。
- 导出全部笔记 Markdown 到用户选择的位置，并能打开所在位置。
- 导出书签 CSV 到用户选择的位置，并能被表格工具打开。
- 创建包含数据库和封面的备份 zip，并恢复到测试环境。
- 删除所有本地数据，确认书库、笔记、索引、AI 记录被清空。

## 隐私与安全

- 未配置 AI 时，AI 入口不崩溃并引导到设置。
- 关闭联网 AI 后，不能发送 AI 请求。
- AI 请求前能看到上下文范围。
- API key 不出现在 SQLite、日志、导出文件或备份 manifest 中。
- 清空 AI 历史不删除已保存为普通笔记的内容。

## 平台验证

- Windows debug 或 release 包能启动。
- Windows 拖拽导入 EPUB/PDF 可用，中文路径、空格路径和长路径可用。
- Windows 包包含 PDF renderer assets 和品牌图片资源；EPUB 使用 Flutter-native renderer，不依赖 epub.js 静态资源。
- Android debug 包能安装并通过系统文件选择器导入 EPUB/PDF。
- Android 返回手势不会丢失阅读进度。

## 命令验证

```powershell
flutter pub get
dart format .
flutter analyze
flutter test -r expanded
flutter build windows --debug
flutter doctor -v
```

Android 环境可用时额外运行：

```powershell
flutter build apk --debug
```
