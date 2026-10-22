# PageSage 手动验收样本

这些样本用于 UI/UX 现代化后的真实 EPUB/PDF 验收。样本由本地脚本生成，文本和图片均为原创占位内容，不进入生产资源包，不应放入 `assets/`。

## 生成方式

```powershell
dart run tool/generate_manual_samples.dart
```

默认输出目录：

```text
.codex-run/samples/
```

也可以指定输出目录：

```powershell
dart run tool/generate_manual_samples.dart D:\Temp\pagesage-samples
```

## 样本清单

| 文件 | 用途 |
| --- | --- |
| `standard.epub` | 标准 EPUB，含 2 章和 EPUB3 目录，用于导入、打开、目录跳转、书签、笔记、进度恢复。 |
| `long-text.epub` | 长标题、长段落、代码块和长单词，用于窄屏、字体放大、搜索命中和正文排版验收。 |
| `image.epub` | 带内嵌原创 PNG 的 EPUB，用于图片、说明文字和正文宽度检查。 |
| `no-toc.epub` | 无目录 EPUB，用于目录 fallback 和章节列表检查。 |
| `large.epub` | 40 章大型 EPUB，用于导入、索引、任务取消和滚动性能检查。 |
| `standard-text.pdf` | 3 页文本 PDF，用于页码、搜索、缩放、书签和保存进度。 |
| `large-text.pdf` | 80 页文本 PDF，用于滚动、页码跳转、索引和长任务取消。 |
| `image-only.pdf` | 无文本层 PDF，用于搜索、划词和 AI 禁用状态说明（内容为矢量路径，**不含任何图片 XObject**）。 |
| `image-xobject.pdf` | 单页、含一张真实图片 XObject，用于图片批注的识别、吸附与渲染验收。 |
| `image-xobject-rotated.pdf` | 同上但整页 `/Rotate 90`，用于图片批注在旋转页上的坐标验收。 |
| `broken.pdf` | 故意损坏的 PDF，用于可恢复错误 UI。 |

## 验收流程

1. 运行生成脚本。
2. 在 PageSage 中导入 `.codex-run/samples/` 下的 EPUB 和 PDF。
3. 按 `docs/testing-ui-ux-checklist.md` 的第 5 到第 13 节逐项检查。
4. 对每个未完成项记录平台、窗口宽度或设备、主题、样本文件、结果和阻塞问题。

## 边界说明

- 样本只用于本地人工验收和自动化测试，不改变产品支持范围。
- `image-only.pdf` 是无文本层近似样本，用于验证无可选文本时的 UI 状态，不代表完整 OCR 场景。
- `broken.pdf` 只用于错误状态验证，不应尝试修复或绕过损坏内容。
