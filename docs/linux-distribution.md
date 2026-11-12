# PageSage Linux 测试版

## 下载与校验

下载同一版本的 `pagesage-版本-linux-x86_64.tar.gz` 和对应的 `.tar.gz.sha256`。
在下载目录执行，将文件名替换为实际版本：

```bash
sha256sum -c pagesage-版本-linux-x86_64.tar.gz.sha256
tar -xzf pagesage-版本-linux-x86_64.tar.gz
cd pagesage-版本-linux-x86_64
```

这是 Linux x86_64 测试包。GitHub 构建使用 Ubuntu 22.04；其他发行版需要满足
运行库要求并单独测试。`BUILD_INFO.txt` 记录版本、源码提交、是否包含未提交修改
和构建环境 glibc 版本，不能将开发机打出的包等同于 Ubuntu 构建产物。

## 运行与安装

不安装时使用包内启动器：

```bash
./run-pagesage
```

启动器设置包内共享库的加载路径，SQLite 通过 Flutter native asset 随包加载。
请保持 `pagesage`、`lib/`、
`data/` 与启动器位于同一目录，不要单独复制可执行文件。

安装到当前用户的应用目录并创建菜单入口：

```bash
bash install.sh
```

默认安装位置为 `~/.local/opt/pagesage`，可指定绝对路径：

```bash
bash install.sh --prefix "$HOME/.local/opt/pagesage-beta"
```

安装器支持含空格或中文的路径，菜单入口始终指向包内启动器。
应用数据保存在独立数据目录；升级替换程序目录，不清理书库、笔记或设置。
安装器不启动或停止应用进程，升级后请自行重开正在运行的旧版本。

## 系统运行依赖

需要桌面会话及 GTK 3、libsecret、C++ 运行库。API key 安全存储还需要可用的
Secret Service，例如桌面环境的 GNOME Keyring 或兼容服务。
包内带 Flutter 运行库、应用资源、插件和锁定依赖提供的 SQLite，不包含整个操作系统依赖。

Ubuntu 22.04 可安装：

```bash
sudo apt-get install libgtk-3-0 libsecret-1-0 libstdc++6
```

仅在需要扫描 PDF OCR 时安装 Tesseract 和所需语言数据：

```bash
sudo apt-get install tesseract-ocr tesseract-ocr-eng tesseract-ocr-chi-sim
```

没有 OCR 引擎不影响普通 EPUB/PDF/Markdown 阅读。公式、矩阵和复杂排版识别存在局限，
不能将 OCR 输出当作已校对原文。

## 许可与反馈

第三方包清单见 `THIRD_PARTY_LICENSES.md`，完整 Flutter 许可位于
`data/flutter_assets/NOTICES.Z`，应用内也可打开许可证页面。
随包 SQLite 的原生实现属于 public domain，见其官方版权说明：
https://www.sqlite.org/copyright.html 。
隐私说明见 `PRIVACY.md`。

反馈时附版本、`BUILD_INFO.txt`、系统版本、复现步骤和脱敏截图。
不要提交 API key、私人书籍正文或个人数据库。
