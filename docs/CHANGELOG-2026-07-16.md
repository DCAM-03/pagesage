# PageSage 变更摘要（工程推进）

日期：2026-07-16  

## 功能

- 书库：文件夹扫描导入、标签批量查询、手机列表/紧凑视图、封面提取增强（EPUB3 + PDF JPEG 启发式）
- 阅读器：PDF/EPUB 软跳转、无文本层提示、进度会话稳定
- 搜索：索引中/失败空态与重建入口
- 笔记：过滤缓存修正、简单标记预览
- AI：未配置/过长前置校验
- 导出/备份：备份恢复单测；恢复后强制提示重启

## 体验

- 应用色定稿为冷黑 + 电蓝（`#1E40AF` / `#05070D`）
- 桌面去掉 CommandBar 与 PageHeader 双标题；CommandBar 显示品牌弱标题
- 图标/空状态资源更新

## 工具与文档

- `tool/check.ps1` / `tool/check.sh` 质量门禁
- `tool/build_release.ps1` 发布构建
- `docs/keyboard-shortcuts.md`
- `docs/m4-release-checklist.md`
- `docs/plan-to-m5.md` / `docs/implementation-status.md` / `docs/09-design-system.md` 同步

## 已知未闭合

- 大书库/大 PDF 与 Android 实机手测（清单待勾）
- 完整 Markdown 引擎、中文 FTS 分词增强（可选）
- 商店签名与安装器包装
