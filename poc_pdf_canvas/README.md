# pdf_graphics → Flutter Canvas POC

验证 `pdf_graphics` 5.1.1 能否在 Linux 上通过 Flutter Canvas 渲染 PDF，
不依赖 WebView / WebKit / WPE。决策依据见
[`../docs/10-pdf-renderer-migration.md`](../docs/10-pdf-renderer-migration.md)。

## 运行

```bash
flutter pub get
dart run tool/make_samples.dart   # 生成测试样本（首次需要）
flutter run -d linux --debug     # 结果输出到 build/poc_out/
```

## 验证了什么

| 能力 | 结果 |
| --- | --- |
| 嵌入 CJK 字形（`/CIDFontType2`） | 通过 |
| 系统字体回退中文 | 通过 |
| 图像解码 | 通过 |
| 线性渐变、圆角矩形、贝塞尔曲线、描边 | 通过 |
| 文本选区（`textIn` / `positionNear` / `quadsFor`） | 通过，选区视觉严丝合缝 |
| 搜索（`findAll`） | 通过 |
| 缩放 1x / 2x / 3x | 通过，坐标一致 |

## 两个必须照抄的实现约束

包文档没有说明、写错也不抛异常（只是静默渲染出错误结果）：

1. **页面变换的翻转支点是 `box.height`，不是 y=0。** 写成
   `canvas.scale(zoom, -zoom)` 会把内容推到负 y 区域，整页空白。
2. **图片需要先做一次 scan-only 遍历**再 `decodeImages`，否则图片全部丢失。

参考实现：`dart_pdf_editor/lib/src/renderer.dart` 的 `_applyPageTransform`。

## 样本说明

| 文件 | 来源 | 用途 |
| --- | --- | --- |
| `chinese-embedded.pdf` | `tool/make_samples.dart` | 嵌入 Sarasa Mono SC，真字形路径 |
| `vector.pdf` | `tool/make_samples.dart` | 渐变 / 曲线 / 描边 |
| `chinese.pdf`、`image-only.pdf`、`large-text.pdf`、`standard-text.pdf`、`broken.pdf` | 仓库既有 `dist/` | 回归对照 |

**注意**：LibreOffice 无法用于生成嵌入 CJK 字体的 PDF——它的 HTML 导入会丢弃全部
字体声明，中文只能走替换；改用 `writer_pdf_Export` 和静态字体均无效。样本因此用
Dart 的 `pdf` 包生成。

PDF 内容流经 FlateDecode 压缩，检查样本内容需先解压，直接 grep 二进制查不到算子。