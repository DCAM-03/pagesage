# PageSage M4 发布就绪检查清单

版本：0.1  
日期：2026-07-16  
对照：`docs/plan-to-m5.md` P3、`docs/07-roadmap.md` M4  

## 1. 自动化

- [ ] `powershell -File tool/check.ps1` 或 `bash tool/check.sh` 通过  
- [ ] `flutter test` 全绿  
- [ ] `flutter analyze` 无 error  

记录：

```text
日期：2026-07-16
平台：Windows 开发机
命令：flutter test / flutter analyze
结果：导出备份单测与主套件见当日运行
阻塞：
```

## 2. 备份与恢复（手测）

步骤：

1. 导入至少 1 本 EPUB/PDF，加书签或笔记。  
2. 设置 → 隐私与数据 → **备份数据库**，保存 zip。  
3. 再改数据（删书签/改设置）。  
4. **恢复数据库**，确认完成对话框与回滚副本路径。  
5. **完全退出并重启应用**，验证数据回到备份时状态。  

- [ ] 备份成功并可「打开位置」  
- [ ] 恢复确认文案清晰  
- [ ] 重启后数据正确  
- [ ] 回滚副本存在于 exports  

## 3. 核心阅读闭环（Windows）

样本：`dart run tool/generate_manual_samples.dart`  

- [ ] 导入 EPUB，读一段，退出重开进度正确  
- [ ] 导入 PDF，跳页/缩放，退出重开页码正确  
- [ ] 目录跳转、书内搜索（有文本层 PDF）  
- [ ] 划线/书签/笔记跳回  
- [ ] 快捷键见 `docs/keyboard-shortcuts.md`  

## 4. Android（有设备时）

- [ ] `flutter run` 或 release APK 安装  
- [ ] 导入 → 阅读 → 返回书库 → 再进  
- [ ] 底部导航与阅读器沉浸  

无设备时记：

```text
Android 手测：跳过（无设备）
```

## 5. 构建

- [ ] `powershell -File tool/build_release.ps1 -Target windows`  
- [ ] （可选）`powershell -File tool/build_release.ps1 -Target android`  

## 6. 辅助功能抽检

- [ ] 主路径 icon-only 有 tooltip  
- [ ] 高对比主题可读  
- [ ] 窄屏 + 大字号无严重溢出（已有 widget 测试覆盖部分）  

## 7. 隐私与许可

- [ ] 设置 → 关于 → 隐私说明  
- [ ] 开源许可页可打开  
- [ ] 导出/日志无 API Key  

## 8. 结论

| 项 | 状态 |
| --- | --- |
| 可本地验证质量门禁 | 是（tool/check.*） |
| 备份/恢复代码 + 单测 | 是 |
| 快捷键文档 | 是 |
| 商店签名与上架 | 未强制（仍需人工配置） |
| Android 实机 | 视设备 |
