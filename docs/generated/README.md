# 生成文件

- `third-party-licenses.md`：依赖许可索引，由 `tool/generate_third_party_licenses.dart`
  依据锁文件生成，Linux / Windows 打包会读取。
- `app-icon-v3-light.png`、`app-icon-v3-dark.png`：当前图标生成器的预览输出。
  正式应用资源位于 `assets/images/brand/` 和各平台图标目录。

旧品牌实验已从当前源码树移出，不再次重写 Git 历史。
此目录不用于私人书籍、未脱敏评测、密钥或构建日志。
