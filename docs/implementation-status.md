# PageSage 实现对照清单

代码清理（2026-11-09）：已移除未接入骨架、多余事件和模型转发，独立阅读器装配；
继续将 9 类仓储、阅读设置与目录组件按职责迁出聚合文件，统一更新直接消费者；
Notebook、共享批注 / 书签操作及查询 provider 已继续拆出阅读页；
书内搜索与工具侧栏也已独立，复用原有页签枚举，并处理搜索过期请求及切书 / 卸载生命周期；
选区动作组件与摘录编辑器已独立，修复菜单替换竞态、同文不同来源混淆、移动面板叠加及摘录退场 / 异步保存问题；
通用阅读器 chrome、PDF 工具条与状态栏已独立，定位文案收口到共享模块，阅读页降至约 4.1k 行；
移动端顶/底栏与“更多”面板也已独立，阅读页降至约 3.5k 行；
目录再按桌面面板、EPUB / Markdown 移动面板、PDF 移动面板和共享树逻辑拆分，旧聚合文件已删除；
批注订阅与渲染器装配收口到独立叶子宿主，批注变化只重建该子树；
OCR 可见页编排从阅读页拆到独立协调器，阅读页只保留状态、结果面板和 AI 交接；
范围、结构债与验证结果见 [代码冗余与组织清理](tasks/code-cleanup-audit-2026-11-09.md)。

版本：0.2  
日期：2026-07-16  
对照文档：`01-product-requirements.md`、`02-feature-spec.md`、`07-roadmap.md`、`plan-to-m5.md`、`AGENTS.md`  
状态说明：

| 标记 | 含义 |
| --- | --- |
| [x] | 已实现，主路径可用 |
| [~] | 部分实现 / 有缺口 / 体验未达验收 |
| [ ] | 未实现 |
| [-] | 文档明确延后或不做（非当前范围） |

---

## 2026-11-12 增量：Windows / Android GitHub 自动构建

- 补齐 `windows-android.yml`：固定 Flutter、双项目锁文件恢复、分析、Windows 默认回归、
  无窗口原生 PDF 测试和完整 ZIP；Android API 36 无窗口集成测试后构建普通 APK。
- Android 支持四项 Secrets 正式签名，PR 隔离签名；未配置时分支产物明确标记 test，
  版本标签要求正式签名并生成 APK/AAB。测试密钥实际签名构建及证书校验已通过，密钥已删除。
- 两平台上传包和 SHA-256，版本标签附加至共享草稿 Release；Linux 仅调整发布附件复用，
  避免跨工作流创建冲突，不改 Linux 构建或本地安装。
- Windows 安装排除测试遗留的绝对路径清单，保留真实 native DLL；release 重建、
  CI 同命令原生 CTest 3 项及最终 ZIP 校验通过。
- Windows 全量回归修正两处平台断言后 1101 PASS / 23 SKIP；打包/发布工具 13 PASS，
  Actions / ShellCheck、静态分析与实际归档检查通过。用户已报告配置签名 Secrets，
  随后授权提交推送到 `main`，本轮不创建标签或 Release；云端构建及正式签名结果待确认。
- 入口、签名要求、发布范围及验证证据见
  [Windows / Android 自动构建记录](tasks/windows-android-ci-2026-11-12.md)。

## 2026-11-12 增量：Android / Windows 主机对接验证

- 修复 Android OCR Kotlin 的 `isEmpty` 调用编译错误；Windows release、Android debug/release
  构建成功。按授权补齐 Android SDK / 许可证，使用已有 JDK 21，不改全局 Flutter 配置。
- 新增 Windows 无窗口原生 CTest，4 PASS；真实 WinRT PDF 栅格化、英文 OCR、
  中文空格路径、像素预算与错误分支通过。
- 独立 Android API 36 无窗口模拟器集成测试 5 PASS：原生 PDF/ML Kit、安全存储、
  SQLite FTS5 文件重开、无效导出源文件、触摸翻页保存与页面重新挂载恢复。
- 修复组件测试的 Windows 文件锁清理时序和路径断言；定向回归 561 PASS，
  离屏布局/交互 25 PASS（与前组重叠），已检查桌面和移动大字号截图；静态分析无问题。
- 用户限定静默验证，未启动 Windows 可见窗口；原生选择器人工操作、真机生命周期、
  Windows 完整运行及部分阅读闭环仍待验收。Android release 沿用 debug 签名，供本地测试。
  本次 Linux 重装受 WSL 缺原生构建环境阻断，未更新 Linux 安装。
- 产物、日志、复验入口及证据边界见
  [Android / Windows 续验记录](tasks/android-windows-alignment-2026-11-12.md)。

## 2026-11-12 增量：Linux 自动构建与私有分发仓库

- 已创建私有仓库 `DCAM-03/pagesage`，配置本地 SSH remote 并完成首次提交推送；
  首次 Actions 的 SDK 标签缺失及后续 PDF 样例子项目依赖初始化问题均已修复。
  最终 `ae16250` 对应 run `43164218384` 完整成功，云端默认全仓
  1115 PASS / 9 SKIP / 0 FAIL，分析、构建、运行库门禁、校验及上传均通过。
- 增加固定 Flutter 提交的 Ubuntu 22.04 工作流：锁文件、分析和全仓回归后构建
  Linux x86_64 分发包，上传压缩包/校验和，版本标签生成草稿 Release。
- SQLite 改用锁定依赖的随包 native asset，去除 Fedora 系统库绝对路径；
  增加完整 bundle 打包、独立启动器、用户级安装器及失败回滚。
  CMake 安装排除测试留下的主机路径清单，保留实际原生库。
  Linux 禁用未使用的可选 JNI 查找，防止随包引用构建机 Java；
  运行库门禁使用包内库路径，拒绝缺失依赖及 `libjvm.so` 链接。
- 本机随包 SQLite 配置全仓回归 1117 PASS / 7 SKIP / 0 FAIL，包含 16 项分发测试；
  静态分析、格式、ShellCheck、actionlint 和差异检查通过。
  真实包校验、临时中文/空格 HOME 安装、SQLite FTS5 和本机动态依赖检查通过。
- JNI 清理后 Linux release 已静默重建安装，16 项分发测试和运行库门禁通过，
  完整 bundle 比对一致，已有进程保持运行；本机压缩包也已更新。
  最终 Ubuntu 云端包下载后再次通过 SHA-256、临时安装、
  全部 ELF 动态依赖及 SQLite FTS5 实际读写检查。
  构建、库加载与安装证据不替代真实阅读窗口或其他平台验收；
  产物、日志与远程状态见 [Linux 自动构建与分发记录](tasks/linux-distribution-2026-11-12.md)。

## 2026-11-12 增量：Linux beta 候选全仓回归

- 对包含最新设置恢复和 AI 交互修改的当前工作树执行
  `flutter test --concurrency=4 --reporter expanded`：1101 PASS / 7 SKIP / 0 FAIL，
  退出码 0；`flutter analyze` 无问题。
- 跳过项为显式开启的搜索 benchmark、外部样本 OCR smoke/性能及缺失的两类 Android
  产物；已有 Windows/Android 旧产物资源检查不代表当前平台原生代码构建通过。
- 测试静默运行，未启动窗口。仅补验证记录，不修改应用代码、不重复安装。
  当前没有 GitHub workflow 或 remote；Linux Actions 构建与分发建议、
  SQLite 绝对库路径等接入事项见
  [全仓回归与分发路径核对](tasks/linux-beta-regression-2026-11-12.md)。

## 2026-11-12 增量：设置可靠性与 AI 操作打磨

- 阅读设置串行保存、可观察失败及重试；关闭面板 flush 最新修改，旧的保存通知不覆盖新草稿。
- 凭证操作与恢复共用数据库文件锁；写入并核实密钥后才提交 revision。
  中断后清理不确定密钥并提示重新输入，删除/清除失败保留日志可重试；
  首次保存失败复用已创建 profile，复制密钥失败不遗留可见空配置。
- AI 设置允许关闭联网时编辑和保存；从阅读面板直接打开设置再返回，保留原问题。
  输入和发送固定底部，短窗口/键盘弹出时收起快捷项，增加新对话、键盘发送、配置/历史重试。
- 修复发送前置阶段重复请求、连续事实问答丢来源快照、重新生成重复历史和保存笔记重复操作。
- 最终受影响回归 279 项通过，静态分析无问题；范围、测试故障与安装核对记录见
  [设置恢复与 AI 交互打磨](tasks/settings-recovery-ai-polish-2026-11-12.md)。
  离屏布局补测 5 项、最终键盘补测 1 项通过（与前组重叠）；Linux release 已静默
  重建安装，完整 bundle 核对一致。未调用真实模型，目标平台安全存储及窗口行为仍待设备验收。

## 2026-11-12 增量：代码审查、阅读主题与 Android/Windows 适配

- 修复 AI 仓储双实例通知、初次订阅丢更新、revision 并发覆盖、迁移重试和切组异步竞态；
  首次保存使用多配置凭证路径，删除无消费者的旧仓储，迁移配置工具。
- 定位摘要/跳转补全文本移至 domain，移除仓储/PDF 对 EPUB helper 的依赖；
  拒绝非法批注矩形，清除本地数据先处理所有配置凭证。
- PDF OCR 统一为「识别文字 + 下拉」，菜单收纳范围/整本，打开菜单时暂停自动收起。
  阅读主题覆盖目录、工具栏、底栏及弹层；保留独立书库/设置主题。
- Android 增加系统文档导出与 content URI 流式写入、图片批注 ZIP，
  修复 Kotlin 入口配置、OCR/PDF 内存预算与资源回收。
  Windows 按实际 OCR 语言包报告能力、保护空参数及限制图像预算。
- 定向回归 433 PASS / 1 SKIP、最终平台/渲染补测 187 PASS、离屏布局补测 5 PASS，
  分组重叠不相加；静态分析、格式与差异检查通过，独立 C++ 预算测试通过。
  Linux release 已静默重建安装，完整 bundle 比对无差异，未启动应用窗口。
  Android 构建受缺失 SDK 阻断，Windows 构建需 Windows 主机；
  两平台原生编译与真实设备验收未完成。
- 范围、剩余结构债及证据见
  [代码审查记录](tasks/code-review-2026-11-12.md)、
  [平台适配与换机验收](tasks/android-windows-alignment-2026-11-12.md)。

## 2026-11-12 增量：搜索、备份恢复与导出联合收口

- 搜索只回填缺失/过期 term，不再在每次查询中重写全部分词并重建 FTS；SQL 先排序 ID
  再载入正文。10k 块、1,119 万 UTF-16 合成语料的六类暖查询 P95 120–199ms。
- 修复防抖期间旧结果回流、emoji 后偏移、中英查询组高亮和块内实际命中跳转；
  归一化版本 `normalizer-v2`，通过旧派生数据按需更新。
- 备份使用包含 WAL 的 SQLite 快照；同机恢复验证笔记/批注/书签/进度、AI 配置隔离、
  OCR 完成页保留/任务暂停、FTS 与封面；修复关闭旧库后错误写任务完成状态。
- 桌面导出选择路径不再提前写空文件；取消/失败保护既有目标，支持 Linux 打开目录，
  防重复点击、选择器失败提示与跨书图片隔离。
- 定向回归 257 项通过，最终搜索补测 112 项通过（重叠不累加），规模测试单独通过。
  恢复/配置最终补测 39 项通过，静态分析无问题；Linux release 已重建安装，完整 bundle 一致。
  性能来自 debug 合成库、UI 为离屏测试；原生保存对话框及真实大库未作人工验收。
  详细证据与安装结果见 [三项联合记录](tasks/search-restore-export-2026-11-11.md)。

## 2026-11-11 增量：Linux 窗口联合验收

- 用户授权后，使用 Linux GTK 测试窗口、真实渲染器、临时 SQLite 和内存安全存储完成
  19 项场景：PDF 12 项、真实 Tesseract OCR 2 项、Markdown 4 项、设置 1 项；
  后续大纲缓存补测 1 项、手柄坐标修复后的 OCR 2 项均通过，保留历次失败日志。
- 修复 OCR 逐页选择层丢失、无效几何开启选择、扫描原图重复绘字、能力回调触发构建期异常、
  同帧结果覆盖待发送页、选区关闭后键盘焦点不回正文；手柄改为在页面坐标中裁剪后再加居中偏移。
- 修复批注按钮文字断行、Mermaid 命名节点复用与后置定义、设置切组沿用旧滚动位置、
  外部编辑后 Markdown 当前大纲仍复用旧文档。复核实际 engine 截图。
- 定向回归场景去重 181 项通过，最终静态分析无问题；没有把旧全仓结果作为本轮全量验证。
  AI 仅验证选区与面板传递，未发送真实模型请求；窗口输入由 Flutter 测试绑定合成。
- 证据及本地安装核对见 [Linux 窗口验收记录](tasks/linux-window-acceptance-2026-11-11.md)。

## 2026-11-11 增量：扫描 PDF OCR 文本划词闭环

- 已识别页的 OCR 文本现在支持点击选词和拖动跨行选择，并复用标准 `RendererTextSelected` 事件进入现有复制、高亮、下划线、批注、摘录笔记和 AI 动作，不再需要独立的 OCR 选区通道。
- OCR 块直接按显示页 0..1 坐标做命中与选区，避免旋转页二次投影；保存的 OCR 选区矩形在重绘时使用 OCR 行带裁剪，原有批注点击路径保持可用。
- OCR 覆盖页能力上报为 `textSelection=true`、`ocrTextLayer=true`；搜索仍跟随原生文本层，未识别的扫描页不会产生伪选区。
- 验证：OCR 选择模型 13 项、PDF 画布 46 项、选择/标注契约 64 项、阅读器选区动作与 OCR 覆盖层 23 项，全部通过；全仓 1001 项通过、6 项按环境跳过；`flutter analyze` 无问题，`git diff --check` 无输出。
- Linux release 已静默重建安装，完整 bundle 与安装目录一致，`libapp.so` SHA-256 为 `1f6c8e37cd8eb95538a60c543dc63ce4fd2bb086deeb01ecdc230ee41eb75f96`。安装时没有运行中的实例，未启动新窗口；真实窗口与 Windows/Android 验收仍待执行。行为边界见 [扫描 PDF OCR 任务](tasks/pdf-ocr-optional.md#2026-11-11-增量ocr-文本划词闭环)。

## 2026-11-11 增量：PDF 工具条、任务状态与设置层级

- 窄 PDF 工具条保留可见页识别，将范围与整本识别收进更多菜单；任务中心补充暂停/部分完成统计，区分「已处理 100%」与识别全部成功；窄屏设置二级页移除重复标题。
- 修正离屏测试中的默认数据库依赖，补充暂停任务、大字体详情滚动与部分完成统计验证。最终定向 38 项通过，静态分析和格式检查通过；检查 11 张真实字体离屏截图，涵盖窄工具条、任务状态及设置页关键布局。
- Linux release 已静默重建安装，完整 bundle 与安装目录一致，`libapp.so` SHA-256 为 `97d8a2bf1488a8174c0447b46956a5319f3a0b2aa9bbe45e7a16304741467d59`。未启动应用窗口；本轮不包含真实窗口或跨平台验收。详细证据见 [UI/UX 任务记录](tasks/ui-ux-modernization.md#2026-11-11窄屏-pdf-工具条与-ocr-任务状态)。

## 2026-11-11 增量：AI 多配置交互与异常状态

- AI 配置下拉在加载、读取失败、空列表和活动配置暂时缺失时都有明确状态；读取失败可重试，活动配置不会因列表暂时不全而丢失选中项。
- 保留配置切换和新建入口，将复制、复制配置和密钥、重命名、删除收进单一操作菜单；新建或复制成功后自动切换，操作互斥并在失败时就地提示。
- `test/features/settings` 48 项通过，静态分析、格式检查和差异检查通过；检查 5 张真实字体离屏截图。详细行为边界见 [AI 设置任务记录](tasks/ai-settings-and-providers.md#2026-11-11多组配置交互与异常收口)。
- AI 面板与综合界面受影响回归 45 项通过；综合用例中的空配置流已显式隔离，避免进入 AI 设置时读取默认数据库。Linux release 已静默重建安装，完整 bundle 与安装目录一致，`libapp.so` SHA-256 为 `9ffdfc9258d8e8e3533bdceb5e8a4319874574931e3248966250fed5f3d89980`。未启动应用窗口；真实窗口与跨平台验收仍待执行。

## 2026-11-10 规划：Linux 阅读体验六项功能

- 已整理 [统一规格与实施顺序](specs/linux-reader-six-features-2026-11-10/README.md)：Markdown 文件夹外部变更、AI 回答可靠性、多组 AI 配置、中文搜索、Mermaid 图形、Linux OCR 页级任务与搜索。
- 每项包含实现基线、交互、算法/状态、数据与迁移、异常和验收用例，共用来源版本与索引原子发布契约；最终按 [联合验证与验收](specs/linux-reader-six-features-2026-11-10/07-validation-and-acceptance.md) 集中交付。
- 规格初次交付仅含文档；后续 F1–F6 已连续接入。当前自动回归与安装证据见下方“2026-11-11 六项功能实施与联合自动验证”；真实模型、OCR 冻结质量/性能、真实窗口和各平台验收仍保持未完成。

## 2026-11-11 增量：整本 OCR 入队验证

- 整本 PDF OCR 按最多 2,000 页拆分并串行加入现有 worker 队列；增加协调器测试覆盖 4,001 页完整连续分批、第二批失败时报告已入队页数、并发重复请求拒绝及失败后重试。
- 静态分析无问题；OCR 与阅读器工具栏相关 45 项测试通过。Linux release 已静默重建安装，完整 bundle 与安装目录一致；未启动或重启窗口。
- 30 页 OCR 质量/性能评测未执行：仓库只有开发集 JSON、开发集报告及 PoC PDF，没有规格要求的 30 页独立 PDF 与逐页冻结人工真值。PoC/合成样例不作为质量评测替代。取得合规冻结语料后再测 CER、耗时及 app/rasterizer 集成 RSS。

## 2026-11-11 增量：用户线性代数 PDF OCR 抽样目视评测

- 按用户指定的“匿名数学扫描样本.pdf”抽取连续 30 个物理页（20–49），按应用当前 Tesseract 5.5.4 / `chi_sim+eng` / OEM 1 / PSM 3 参数识别；抽样页是无文本层扫描图像。
- 30 页均识别成功；耗时中位数 1.35 s、P95 1.86 s，Tesseract 子进程最大 RSS 130.8 MiB（不含 app/rasterizer）。缩略总览和第 20、33、42、49 页原图与输出已直接目视对照：普通段落部分可读，线性代数公式、矩阵及上下标存在明显误识，不足以保证公式文本正确。无逐页人工真值，不报告 CER，也不据此调参。
- 该用户书籍样本不等于规格要求的英语/简中/复杂/退化分层冻结集；PDF 渲染耗时及 PageSage 集成 app+rasterizer RSS 未测。详细口径和边界见 [用户 PDF 探索性实测](eval/ocr-linear-algebra-user-pdf-2026-11-11.md)。

## 2026-11-11 增量：线性代数公式页参数对照

- 对物理页 20、23、33、42、49 比较当前近似默认 200 DPI budget 下 PSM 3/6，以及 300 DPI / 3300 px 下 PSM 3。PSM 6 只改善部分标题、另有标题回退；300 DPI 档耗时和 RSS 更高，目标手工真值句 CER 从 15.6% 恶化至 46.9%。
- 样本仅一条完整人工转写句和少数标题，不能外推整页 CER；没有证据支持更改默认 Tesseract 参数。本轮只做离线评测，不改应用代码、不重建安装。详细结果见 [参数对照报告](eval/ocr-linear-algebra-tuning-2026-11-11.md)。

### OCR 外部引擎依赖实测（规格后的独立验证）

- 用户授权后，在用户目录配置 Tesseract 5.5.4、中英模型与完整输出配置，约 6.6 MiB；RPM 已验签。
- 完成 96 次基线和 20 次单文本块分割参数对照；整页子进程峰值约 134–154 MiB、中位耗时约 1.95–2.30 s。中文正文块在同开发集上 PSM 6 比 PSM 3 明显改善，但不能直接当作任意 PDF 整页的模式选择。详见 [实测报告](eval/ocr-linux-2026-11-10.md)。
- 这组记录只验证外部引擎，当时 Linux OCR provider 仍为 stub，没有因此重建或启动应用。后续应用接入见下一节；完整 30 页质量语料、任务/搜索与联合验收仍待实施。

### F6-A：Linux 当前可见页 OCR 接入

- Linux 已选择真实 Tesseract 图像引擎，支持版本/语言/实际 TSV 协议探测，当前可见页导出、识别、行框叠层及现有缓存链路；增加输出/图像限制、超时取消、私有临时目录和阅读器释放取消保护。未引入新包或 schema 变更。
- 真实自有合成中英页面、无文本层 PDF 导出及 SQLite 重开链路已验证；受影响回归、静态分析和本地安装证据见 [F6-A 接入验证](eval/ocr-linux-current-page-2026-11-10.md)。未启动真实应用窗口，未替代用户书籍手工验收。
- 本轮定向回归含真实引擎 smoke 共 220 项通过，`flutter analyze` 无问题；Linux release 已静默重建安装，完整 bundle 一致，`libapp.so` SHA-256 为 `85fca0a0d861c59a…`。安装前后均无运行实例，未启动或重启应用。
- 本切片不包含独立 Linux rasterizer、完整缓存签名/空页缓存、选页队列/恢复或 OCR 搜索；这些仍属 [F6-B 至 F6-E](specs/linux-reader-six-features-2026-11-10/06-ocr-search-and-jobs.md)。

## 2026-11-11 增量：六项功能实施与联合自动验证

- F1 Markdown 文件夹外部变更同步完成：文件树只表示目录/文件，大纲只表示当前文件；外部保存、增删和当前文件重锚接入协调器；22 项定向测试通过。
- F2 AI 回答可靠性完成本地确定性部分：证据不足/索引不可用/正常证据状态、引用序列化与核验、`answer_meta`、来源快照 v1/v2 与导出状态已接入。真实模型拒答率、引用忠实性和人工评分仍待外部调用授权与冻结评测。
- F3 多组 AI 配置完成：命名配置、独立密钥、活动配置、草稿隔离、迁移与设置交互接入；`test/features/settings test/features/ai` 共 158 项通过。
- F4 中文搜索完成：中文单字/双字/连续句和中英混合查询、双路 FTS、稳定排名、原文高亮与原子索引发布接入；60 题自动评测达到门槛。
- F5 Mermaid 完成首期原生阅读：支持子集解析为 typed AST、拓扑布局与 CustomPainter 绘制，不支持的语法保留完整源码并可切换；53 项定向测试通过。
- F6 OCR 完成应用内闭环：Linux 独立 rasterizer、完整缓存签名、空页缓存、页范围任务、暂停/取消/继续、崩溃恢复、签名 OCR 进入 FTS、原生文字优先和删书清理均已接入。新增真实 Drift 任务与搜索链路测试；OCR/搜索/任务中心/阅读器 193 项定向回归通过。
- 全仓 `flutter test --concurrency=4` 954 项通过、5 项按环境跳过；`flutter analyze` 无问题。最终日志为 `/tmp/pagesage-f6-full-final-4.log` 与 `/tmp/pagesage-f6-analyze-9.log`。
- Linux release 已静默重建安装，完整 bundle 与安装目录一致；`pagesage` SHA-256 `ad58a1c45c52…`，`libapp.so` SHA-256 `df1239ec6a12…`。安装日志为 `/tmp/pagesage-f6-install-3.log`；安装时没有运行实例，未启动或重启窗口。
- 仍未完成：F2 真实模型质量；F6 30 页冻结 CER/RSS/耗时、真实窗口手工验收和备份恢复边界实测；Windows/Android 未验收。因此不能把六项联合验收整体标为通过。

## 2026-11-11 增量：OCR 失败页重试与清除结果

- 任务中心的部分完成/失败 OCR 任务可只重试 `failed` 页，完成页、空页与原生跳过页不重复识别。
- 停止状态的任务可确认后清除其关联 OCR 页文本、page checkpoint、会话缓存和搜索命中，并重建该书索引；PDF、原生文字、笔记与批注保留。
- 验证：OCR/任务/索引器 53 项聚焦通过；全仓 961 项通过、5 项按环境跳过；`flutter analyze` 无问题。日志为 `/tmp/pagesage-f6-controls-focused-1.log`、`/tmp/pagesage-f6-controls-full-1.log` 与 `/tmp/pagesage-f6-controls-analyze-1.log`。
- Linux release 已静默安装，bundle 一致；`libapp.so` SHA-256 为 `a35146894a2830225e211e7f5bfec6461610dc592ec3cdd1f10941f85f967412`。安装时无运行实例，未启动窗口。

## 2026-11-11 增量：OCR 范围任务串行 worker

- `OcrJobController` 增加进程内 FIFO 单 worker；多个页码范围任务可分别入队，但同一时刻只执行一个 OCR 批处理任务。
- 排队项持有取消令牌，任务中心恢复不会把当前会话 queued 任务误判为上次中断。暂停/取消先移出队列并清理令牌，避免 worker 稍后重新启动已停止任务。
- 本约束只覆盖 OCR 范围批处理；当前页交互式 OCR 未并入同一调度门。
- 验证：控制器队列/暂停/取消 10 项测试、OCR/任务/数据库/索引器 56 项聚焦回归通过；全仓 964 项通过、5 项按环境跳过；`flutter analyze` 无问题。日志为 `/tmp/pagesage-f6-single-worker-controller-3.log`、`/tmp/pagesage-f6-single-worker-focused-1.log`、`/tmp/pagesage-f6-single-worker-full-1.log` 与 `/tmp/pagesage-f6-single-worker-analyze-1.log`。
- Linux release 已静默安装且 bundle 一致；`pagesage` SHA-256 为 `ad58a1c4…`，`libapp.so` 为 `fac4db6b…`。安装时无运行实例，未启动窗口。

## 2026-11-11 增量：OCR 共享执行门与可靠 checkpoint

- 当前可见页 OCR 与页范围任务接入同一 FIFO 执行门，避免 PDF 光栅化与识别在不同入口并发争抢资源；排队任务取消后立即返回，同时保留队列占位直到前序任务释放，避免并发穿透。
- 范围任务要求 OCR 结果先成功写入本地存储，再更新页 checkpoint；持久化失败会记为失败页，可安全重试，不会出现“任务已识别但结果未落库”。
- 新增排队取消/互斥回归；OCR、Markdown 刷新、AI 证据、搜索索引和 Mermaid 布局/解析定向测试 112 项通过。全仓 `flutter test --concurrency=4` 通过 967 项、5 项按环境跳过；`flutter analyze` 无问题。日志：`/tmp/pagesage-hy-review-focused.log`、`/tmp/pagesage-hy-review-full.log`、`/tmp/pagesage-hy-review-analyze.log`。
- Linux release 已静默重建安装，完整 bundle 与 `$HOME/.local/opt/pagesage` 一致；`pagesage` SHA-256 为 `ad58a1c45c52438faa74c546cb558e75bad856e7aac4c3ac2eb459f639a47210`，`lib/libapp.so` SHA-256 为 `147091512414db140f1077e5dd9da77ecee4fa0e7faa07459aa7f4dfba04d07c`。安装日志：`/tmp/pagesage-hy-review-install.log`。未启动窗口或操作已有进程。
- 代码复核没有发现另外需要扩大改动的阻塞缺陷；离屏/真实窗口手验、F2 冻结真实模型评测、F6 30 页质量与资源测量、历史 schema 恢复验证以及 Windows/Android 仍按联合验收清单待验证。

## 2026-11-11 增量：恢复备份校验与迁移预演

- 恢复前校验 ZIP 清单版本、SQLite `integrity_check`、schema 版本及 PageSage 必需表；再用 Drift 在同目录 staging 副本上实际执行迁移并查询核心表。只有预演通过才关闭正式库、创建稳定回滚副本并替换；失败/取消清 staging，替换失败回滚。
- `test/features/export/export_service_test.dart` 11 项通过：有效数据库备份恢复并重开读出原书数据；损坏 SQLite 被拒绝且原数据库连接可继续查询；v11 形态真实升级到 v12 后书籍和 legacy OCR 保留，中文搜索命中；staging 文件均清理。
- 索引恢复采用“同一 SQLite 快照原样保留”；旧版缺少新 term 文档时由现有搜索兼容路径按需生成并建立 FTS，不在恢复时强制全书重建。v11 用例验证了该惰性回填路径。
- `flutter analyze` 无问题；最终全仓 `flutter test --concurrency=4` 通过 969 项、5 项按环境跳过。日志：`/tmp/pagesage-v11-search-test.log`、`/tmp/pagesage-v11-analyze-final.log`、`/tmp/pagesage-v11-full-final.log`。
- 既有 OCR 开发集结果复核（未重跑，固定样本/引擎未改变）：2200 px 预设 10 个中文正文块 CER micro 12.02%，英文 0.27%；中文 PSM 6 同一开发集降至 2.54%，属于调参诊断不可作为留出结果。特殊样本 CER 约 54%，说明旋转/双栏/混合场景仍有明显边界；整页子进程峰值 134 MiB、中位 1.95 s，均不含 Flutter app/rasterizer。该数据是正文块/派生样本而非 30 个独立页面，因此 F6 冻结 30 页质量和集成 RSS/P95 仍未通过验收。
- `sqlite3` 从 dev dependency 调整为运行时直接依赖，用于恢复前只读校验；依赖锁已更新。Linux release 已静默重建安装，bundle 与 `$HOME/.local/opt/pagesage` 一致；`pagesage` SHA-256 为 `ad58a1c45c52438faa74c546cb558e75bad856e7aac4c3ac2eb459f639a47210`，`lib/libapp.so` 为 `437d0210c8d53dba12deaa4517ca2119154018475cea82f01a30b17bf358f407`。安装日志：`/tmp/pagesage-restore-install.log`。未启动或重启窗口。
- v11 恢复与旧索引惰性回填已有自动验证；v1–v10 各版本独立恢复 fixture 尚未覆盖。仍需 F6 冻结 30 页及应用集成资源测量、F2 真实模型评测、真实窗口人工验收和跨平台验证。

## 2026-11-11 增量：Markdown 行内公式与安全 HTML

- `\(...\)` 行内公式接入现有本地 TeX 路径；`<b>/<i>/<u>/<mark>/<sup>/<sub>/<kbd>` 等安全成对 HTML 标签生成行内样式，`<br>` 恢复软换行。危险标签、属性和远程地址仍被移除，章节文本、搜索、选区、进度与 locator 契约不变。
- 验证：Markdown 边界 / 渲染与 EPUB 分页 70 项定向测试通过，`flutter analyze` 无问题；全仓 957 项通过、5 项按环境跳过。日志为 `/tmp/pagesage-p20-focused-1.log`、`/tmp/pagesage-p20-analyze-2.log` 与 `/tmp/pagesage-p20-full-1.log`。
- Linux release 已静默重建安装，bundle 与安装目录一致；`libapp.so` SHA-256 为 `ae632e4591c9e471…`。安装日志为 `/tmp/pagesage-p20-install-1.log`；安装时无运行实例，未启动或重启窗口。真实窗口与 Windows/Android 仍未验收。

## 2026-11-10 增量：AI 设置表单与交互

- 连接字段与操作优先、高级参数折叠；补齐未保存、处理中和错误反馈，保存/测试/启用/清密钥互斥。设置页会话内切换分类或窄屏返回保留草稿，外部刷新按字段合并，过期连接结果不覆盖当前状态。
- 受影响回归 83 项通过，静态分析无问题；离屏覆盖桌面、窄屏、大字体及未配置/处理中/失败，已检查 8 张截图。真实窗口、真实 Provider 和其他平台未验收，证据与安装记录见 [AI 设置任务](tasks/ai-settings-and-providers.md#2026-11-10设置表单与交互打磨)。
- 本地 Linux release 已静默构建安装，完整 bundle 与安装目录一致，`libapp.so` SHA256 为 `6fa07efa…`；安装前后均无运行实例，未启动窗口。

## 2026-11-10 增量：阅读设置入口一致性

- 设置页与书内面板复用字体选择器，系统/内置/旧自定义字体统一显示和保存；自定义名称显式应用，空值恢复系统默认，未应用草稿不被其他阅读控件保存覆盖。
- 两个入口明确修改共用的全局设置；分类入口响应已保存的字号、模式、阅读主题和字体，区分加载与失败。未新增单书覆盖或字体导入。
- 验证：相关回归 153 项通过，分析无问题；离屏用例 13 项通过并检查 7 张最终图片，修正窄屏大字号说明截断。真实窗口、真实书籍和其他平台未在本轮验收，详见 [阅读设置任务记录](tasks/reader-settings-and-appearance.md#2026-11-10阅读设置入口一致性)。
- 本地 Linux release 已静默重建安装，完整 bundle 对比一致，`libapp.so` SHA256 为 `0b710022e4620a3f…`；未启动或重启应用。

## 2026-11-10 增量：桌面阅读器工具栏

- 主工具栏按导航、记录/助手和设置分组，保留目录、搜索、书签、Notebook、AI、设置入口；快速主题移入“更多阅读操作”，按钮反映当前面板与书签状态。
- 标签根据实际宽度与文字缩放显示，PDF 浮动条去除重复搜索/书签，窄阅读区的收起按钮不跟随操作区滚出。
- PDF 工具条在键盘操作时保持展开，焦点离开或切回鼠标并移出后自动收起；覆盖残留焦点导致无法收起的反例。
- 验证：阅读器、页面和阅读设置相关回归 133 项通过，静态分析通过；真实字体离屏用例 9 项通过并检查 6 组布局。真实窗口和真实书籍未在本轮验收，详见 [UI/UX 任务记录](tasks/ui-ux-modernization.md#2026-11-10桌面阅读器工具栏收口)。
- 本地 Linux release 已静默重建安装，全 bundle 对比一致，`libapp.so` SHA256 为 `d124251c4a07fb02…`；安装前后无运行实例，未启动窗口。

## 2026-11-10 增量：配置保存边界

- 阅读器“恢复阅读默认”只重置字体、字号、行高、段距、页边距、阅读模式、阅读主题和 PDF 缩放；应用主题、减少动画及桌面目录/上下文面板状态保持不变。
- AI 启用开关改为即时保存，只读取持久设置后更新 `enabled`，不携带页面上未保存的 Provider、流式或确认开关。
- AI 设置的 Base URL、模型、Temperature、Max Tokens 增加字段级校验，非法值不再静默回退；连接测试按钮改为“保存并测试”，明确测试前会保存当前配置。
- 桌面书库只保留命令栏搜索，页面头部不再重复；页面内的导入菜单保留三种导入方式，命令栏导入在书库页隐藏。
- 桌面书库默认“全部书籍”状态不再同时高亮“全部书架”。
- 验证：`flutter analyze` 通过；全量 `flutter test` 734 通过、2 skipped；新增设置卡片测试覆盖关闭开关持久化、未保存字段隔离和非法参数拒绝，命令栏测试覆盖导入入口隐藏。
- 本地 Linux 安装版已更新，构建与安装的 `pagesage` SHA256 均为 `ad58a1c4…`，`libapp.so` 为 `9cddf7e4…`。

## 2026-11-10 增量：书库分类栏折叠

- 桌面筛选栏提供固定的展开/收起按钮，收起时网格增宽约 249px；当前阅读状态和书架改用紧凑菜单显示，可继续修改或清除。
- 折叠保持筛选条件和书架树展开状态，隐藏的树不参与键盘焦点；本次运行内切换筛选/视图或调整窗口大小不改变用户的折叠选择。
- 验证：分析通过，书库/通用界面/页面回归 47 项通过；离屏模式生成 1024px、1440px 及大字体截图。人工图片目检、真实窗口和其他平台未验收，详见 [书库任务记录](tasks/library-management.md#2026-11-10-桌面分类栏折叠)。
- 本地 Linux release 已重新构建安装，全 bundle 对比一致，`libapp.so` SHA256 为 `2e90704f…`；检查时无运行实例。

## 2026-11-09 增量：阅读工作台与 AI 历史恢复

- 连续滚动正文去除浮动翻章条，同名原文标题不再叠加章节标题。
- 桌面工具页签持久化，重开恢复搜索/笔记/AI。
- AI 历史恢复同书同线程完整轮次，保存结构化引用快照；跨书来源、续问原定位及 AI/Notebook 导出保真。旧记录保留原文，不猜测分段来源。
- 修改引用开启新会话，清除原来源精确区间；读取历史失败明确提示，区别于空历史。
- 详细证据和未验证平台见 `tasks/reader-workbench-and-ai-resume-2026-11-09.md`。

## 2026-11-09 增量：PDF 目录选中

- PDF 目录不再把所有与当前页同页的章 / 小节标题同时高亮。当前页顶端有 outline 条目时只选中第一个；没有顶端条目时保留最后一个页码小于当前页的条目。页码目录回退使用同一规则。
- 证据：`test/features/reader/reader_panels_test.dart` 新增同页多标题与跨页保留两条用例；聚焦 7 项、全仓 695 项通过（2 skipped），发布准备 6 项通过（2 skipped），本地安装产物一致（`libapp.so` SHA256 `e227abdf…`），安装后已重启本地实例（PID `783213`）。

## 2026-11-09 增量：PDF 目录页内选中

- 连续滚动时渲染器把当前页内比例写回 locator；桌面和移动 PDF 目录据此选最后一个位置不晚于读者的 outline 项，同页多个标题不再同时点亮，也避免只按页顶误判。
- 证据：`reader_panels_test.dart` 的桌面 / 移动页内选中用例与 `pdf_canvas_view_test.dart` 的页内比例上报断言共 51 项聚焦通过；全仓 697 项通过（2 skipped）；本地安装产物一致（`libapp.so` SHA256 `58f7ec7714b27396e287e5be0ac259038a47df6cbbee8c6fe8cacc1ce56dc50a`），安装后已重启本地实例（PID `974330`）。

## 1. 用户故事 US-001～012

| 编号 | 用户故事 | 状态 | 说明 |
| --- | --- | --- | --- |
| US-001 | 导入 EPUB/PDF/Markdown，集中管理 | [x] | 文件选择、拖拽、hash 去重、复制到书库 |
| US-002 | 打开书籍并自动恢复进度 | [x] | EPUB/PDF 均有进度表；会话保存已加固 |
| US-003 | 调整字号、背景和样式 | [x] | 阅读设置持久化；多主题 |
| US-004 | 按目录跳转 | [x] | EPUB TOC + PDF 大纲/页码；软跳转已接 |
| US-005 | 添加书签 | [x] | 添加/删除/跳转/备注入口存在 |
| US-006 | 书籍和笔记全局搜索 | [x] | FTS 索引 + 搜索页 + 跳转 |
| US-007 | 划线和写笔记 | [x] | 标注渲染、笔记页、阅读器 Notebook |
| US-008 | 划词问 AI | [x] | 上下文范围可选；四种范围均已取真实页/章全文（`AiContextSource`，见 `docs/12-ai-retrieval-strategy.md` §7.1） |
| US-009 | AI 回答保存为笔记 | [x] | AI 面板可保存；可被搜索索引 |
| US-010 | 导出笔记 | [x] | 设置页：Markdown / Notebook / 标注 JSON / 书签 CSV / AI Markdown |
| US-011 | 扫描文件夹批量导入 | [x] | 书库「导入」菜单的「扫描文件夹（每个文件一本书）」+ 递归发现 EPUB/PDF/Markdown |
| US-012 | 备份数据库 | [x] | 备份 zip + 恢复 + 回滚副本 |

**用户故事合计：** 12 完成

---

## 2. 里程碑对照

### M0–M3

主路径 **[x]**。可选延后：本地模型运行时 `[-]`；完整 Markdown 引擎 `[~]`；中文 FTS 增强 `[~]`。

### M4 v1.0（稳定发布）

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 数据库备份 / 恢复 | [x] | UI + 服务 + 单测；恢复后强制提示重启 |
| 快捷键（桌面） | [x] | `docs/keyboard-shortcuts.md` |
| 隐私说明 / 开源许可 | [x] | 设置 → 关于 |
| 本地质量门禁脚本 | [x] | `tool/check.ps1` / `tool/check.sh` |
| 发布构建脚本 | [x] | `tool/build_release.ps1` |
| 性能与大库/大 PDF 验收 | [~] | 手测：`docs/m4-release-checklist.md` |
| 辅助功能完整验收 | [~] | tooltip/语义有；清单待人工勾 |
| Windows 商店签名/安装器 | [~] | release 可构建；签名人工 |
| Android 签名发布 | [~] | 同上 |

### M5 UI/UX 现代化

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 设计方案 / token 冻结 | [x] | `docs/09-design-system.md` 与 `app_tokens.dart` 对齐 |
| Flutter token + 公共组件 | [x] | PageHeader/CommandBar/EmptyState/SidePanel 等 |
| App Shell 双标题收敛 | [x] | CommandBar 品牌弱标题 + PageHeader 页面标题 |
| 书库 / 搜索 / 笔记空状态插图 | [x] | `assets/images/empty-states/*.png` |
| 阅读器 / 搜索 / 笔记主体改造 | [x] | 前期已落地 |
| 响应式 + 主题自动化 | [x] | widget/contrast 测试 |
| 双端真实样本手测闭环 | [~] | 需人工按 checklist 勾选 |

### 明确不做

MOBI/AZW、云同步、账号、DRM 绕过、在线书店、iOS/macOS/Linux 首发 → `[-]`

扫描版 PDF OCR：
- Phase 0/1 已落地（无文本层文案、`no_text` 索引态、当前页本地 OCR、复制/问 AI）。见 `docs/tasks/pdf-ocr-optional.md`（TASK-26）。
- Phase 2 部分推进：`ocr_pages` 本地落库 + 翻页自动恢复叠加已落地；选页任务队列 / OCR 进 FTS / ONNX 仍后置，不阻塞 v1.0。

性能 / 稳定性（2026-07-17）：
- PDF 全文提取改走 `Isolate.run`，避免索引时主 isolate 卡死。
- 导入任务索引失败标记为 `failed` 并保留 `bookId`；任务中心重试只重建索引，不再 `allowDuplicate` 再导入一本。
- `createImportedBook` 按 hash 兜底去重；取消导入时清理已插入的孤儿书籍记录。

v1.0 体验冻结落地（`docs/v1-experience-freeze.md`，2026-07-17）：
- **F-01** 单 chrome：PDF 阅读器只有 Flutter 工具栏/状态栏，操作走 Flutter。
- **F-03/S-B** 扫描/OCR 页标注 SnackBar 与状态条标明「近似定位」。
- **F-06** capability 区分 `nativeTextLayer` / `ocrTextLayer`；OCR 入口按 native 控制。
- F-02 文本 PDF 精确标注仍需手测勾选；扫描印刷级贴字仍延后。

PDF 渲染迁移（`docs/10-pdf-renderer-migration.md`，2026-10-21）：
- WebView/PDF.js 渲染器已删除，PDF 由 `pdf_graphics` 在 Flutter Canvas 上直接绘制。
- S0–S7 完成：几何/缩放、滚动与分页、选区、搜索/大纲/链接、导出与 F-02、主题与失败分级、平台切换与删除。
- `flutter_inappwebview` 与 `assets/renderer/pdf/` 已移出依赖与包体。
- **划词修复（2026-10-21，见 `11-pdf-canvas-implementation-plan.md` §25）**：`positionNear` 按 run 包围盒评分，在排版复杂的书上 3–27% 的点落到非指针所在行（最远 729pt）。改为 em 空间基线带判定 + 同行 run 合并 + 行内水平距离决胜；真实书网格复测错行 0.0%。顺带修掉前页/正文页尺寸不同导致的逐行偏移、连点失效、跨页拖选不滚动。
- **旋转页标注与夜间配色（2026-11-08）**：修掉 `prepareAnnotationRects` 把旋转页高窄标注误判为遗留大框的缺陷；新增 PDF 夜间标注色板，标注仍画在夜间滤镜之后。证据：`pdf_annotation_lines_test.dart` 18 项、`pdf_annotation_colors_test.dart` 3 项、旋转页标注 widget 用例、`reader_s0_test.dart` 12/12，截图 `10-rotated-night-annotation.png`。
- **待办**：S8 收口——Windows/Android 手工回归、真机帧时间与峰值内存；OCR 假引擎端到端管线仍未验。

图片批注（`docs/13-image-annotations.md` / `docs/tasks/image-annotations.md`，2026-10-22）：
- B1 完成：PDF 拖框模式、视图内吸附、`annotations` 表 v4→v5（`target` / `image_anchor`）、四角括号描边、Notebook 图片条目与琥珀色跳回闪烁、`exportPageRegion` 保存 PNG。
- B2 完成：标注时裁图进 `<cache>/images/<bookId>/`（文件名按图的同一性，不按矩形）、设置页「导出图片批注」（Markdown + 同级图片目录 + 相对路径）、「清理图片缓存」、删书/删批注清缓存、标注 JSON 补上 `target` 与 `imageAnchor`。裁图不挡读者的路：批注先写库，裁图在之后自己跑。
- B3 完成（2026-10-22）：EPUB 真正显示书中的插图。加载器改为解析 XHTML 的结构（`epub_chapter_parser.dart`），章节文本仍是「只有字」的一条字符串，图片作为并列的块插在文字之间且不占字符，因此搜索、进度、跳转、划词偏移全部不受影响。图片字节从 archive 读，`data:` URI 支持、远程图片不加载；单图字节与像素预算硬限制，尺寸在解码前从头部读。图注是正文的一部分（参与排版与搜索）。失败降级为带原因和 `alt` 的占位块，不留空白。已在真实 Linux 窗口里验证图片被画出（`integration_test/reader_epub_image_test.dart`）；同时修好样本本身：`image.epub` 原先内嵌的插图是一张 144 字节的坏图，任何解码器都读不出来，样本改由生成器现场产出可解码的真图。详见 `docs/tasks/epub-images.md`。
- **待办**：B4、B5；以及「重启后批注仍在原位」的真实应用手动确认。

Markdown 阅读（`docs/tasks/markdown-reading.md` / TASK-31，2026-11-05）：
- P1 完成：单个 `.md` / `.markdown` 文件即一本书。解析成与 EPUB 相同的文档模型（章节 → 块 → 字符偏移），因此分页、连续滚动、目录、进度、全文搜索、图片渲染直接复用，没有第二个阅读器。
- 章节按一级标题切分，二级标题进目录子项；列表、引用、围栏代码、图片都是有结构的块。（行内强调当时只保留文字，P5 已补上样式。）
- 图片只读本地（相对路径 / `data:`），远程图片不加载并给出原因；front matter 只用来取标题，不进正文与索引。
- `books.format` 写入 `md`，无 schema 变更；`ReadingLocator` 新增 `markdown` 类型，字段复用 EPUB 那组。
- 验证：解析器/格式识别/widget 测试通过；真实 Linux 窗口集成测试打开 `.codex-run/samples/markdown-note.md`，排版见 `build/integration-captures/markdown-01-prose.png`（该图早于表头横线的调整）。
- P3 完成（2026-11-05）：表格画成真正的表格。新增 `EpubTableBlock`（行列 + 表头），渲染层用 `Table` 等宽列、横线分隔、表头加粗；分页按行切分，跨页时重复表头。解析前修正分隔行/表头列数不一致的表格（`package:markdown` 原本会整张丢弃），围栏代码块不受影响。单元格文字仍在章节文本里，搜索与进度不受影响。
- P5 完成（2026-11-05）：行内样式与排版层级，阅读观感向 Typora 靠拢（仅阅读）。共享块模型新增 `EpubInlineRun`（粗体/斜体/行内代码/删除线/链接，章节偏移，文字本身不变）与 `headingLevel`、`EpubDividerBlock`；Markdown 与 EPUB 两个解析器都填，渲染层在样式、批注、搜索命中的边界切开 span 叠加合成，标题按 1–6 级缩放，`---` / `<hr>` 画成细线。列表悬挂缩进、链接点击、图片 alt 图注当时未做，已在 P6（2026-11-08）补齐，详见 `docs/tasks/markdown-reading.md`。
- P4 完成（2026-11-05）：切换章节性能。连续模式改为「一章多行（每行 8 块）」，不再在章节进入视野时一次排版整章（实测单帧 160–250 ms → 25–60 ms）；分页模式缓存已测章节并在页面停稳后预排下一章；章节定位改按「章节首行」映射，不再假设行号等于章号。
- P2 完成：**一个 Markdown 文件夹即一本书**，原地读取、不复制（`AGENTS.md` 里唯一例外），`fileHash` 为目录路径指纹；隐藏目录与 `node_modules` 跳过，超过 2000 文件 / 64 MB 明确报错；删除书不会删目录（`Book.isFolderBook`）。入口是书库「导入」菜单的「把文件夹作为一本书」。
- P7 完成（2026-11-08）：文件夹不再合并成一份大文档。`MarkdownFolderManifest` 只发现文件并保留子目录层级，阅读器一次只加载当前活动文件，侧栏分「文件」树与当前文件的「大纲」；单文件书仍只显示文件内大纲。locator 的 `href` / `chapterIndex` 改为文件相对路径与文件内坐标，`progress` 仍是全书进度；旧版合并 locator 打开时映射一次，失配则提示重选目录。搜索逐文件索引并带相对路径，AI 当前章节只读活动文件；导入入口统一为「导入文件 / 扫描文件夹 / 把文件夹作为一本书」。**性能修正**：图片只记路径（渲染时按页面宽度解码），manifest 与单文件解析按大小/修改时间缓存——实测 500 篇 + 500 张 1 MB 图片首次 2.2 s / RSS 243 MB，二次打开 55 ms。**UI 收口**：代码块占满正文列宽并使用安静底色，列表间距压缩到段间距的 0.3；文件树顶层行不再重复名称副标题，选中文件后保持「文件」页签，只有显式点「大纲」才切换。
- P8 完成（2026-11-09）：继续向 Typora 阅读细节靠齐。任务列表不再同时画圆点和 checkbox，`taskChecked` 让标记列画真正的复选框；代码围栏的 `language-*` 变成代码面板右上角的语言标签，不进入章节文本。分页器与渲染器共用 `epubCodeLanguageHeight` / `epubCodeBlockPadding`，带语言代码块多预留 18 px。证据：Markdown / 分页聚焦 48 项、阅读器与 OCR 命名回归 157 项、全仓 634 项通过，离屏 Wayland 真实窗口 3/3，截图 `build/integration-captures/markdown-01-prose.png` 已刷新；安装版手测仍待用户执行。
- P9 完成（2026-11-09）：脚注引用改为小号带色的 `footnote` 行内样式，脚注定义在分隔线后以缩小列表呈现，GFM 回链箭头不进入正文。引用数字仍是原字符，搜索、选区与偏移不变；点击跳转由 P10 补齐。证据：Markdown / 渲染聚焦 35 项、Markdown + EPUB + widget 回归 119 项、全仓 636 项通过，离屏截图 `build/workbench-captures/markdown-footnotes.png`；真实窗口与安装版手测仍待授权或用户执行。
- P10 完成（2026-11-09）：脚注引用 `#fn-*` 目标进入共享文档模型，定义块写入章节字符锚点；渲染器只把命中的内部目标发成 `RendererInternalLinkRequested`，不会弹外链确认。阅读器复用 jump 链路，分页按偏移选页，连续模式精确到目标块并二次 `ensureVisible`，支持跨章脚注。证据：解析 / 分页 / 渲染聚焦 55 项、全仓 641 项通过（2 skipped）；真实窗口与安装版手测仍待授权或用户执行。
- P11 完成（2026-11-09）：文件夹书的 manifest、活动文件、进度换算、事件归一化、文件切换与旧版 locator 兼容收口到 `MarkdownFolderSessionController`，阅读页只保留 UI 编排；`MarkdownFolderSource` 窄接口保持 renderer / application 边界并支持竞态测试。证据：控制器 7 项、受影响回归 90 项、全仓 648 项通过（2 skipped）；真实窗口与安装版手测仍待用户执行。
- P12 完成（2026-11-09）：带语言的 Markdown 围栏代码增加轻量语法高亮。`EpubCodeRun` 与 `CodeSyntax` 只提供章节字符范围上的展示颜色，穿过连续 / 分页片段后与行内样式、搜索命中共同切分 `TextSpan`；正文、选区、进度、批注和 locator 不变。覆盖常见语言、别名、未知 / 无语言降级以及 10 个阅读主题的 WCAG AA 对比度。证据：词法 / 解析 / 分页 / 渲染聚焦 74 项、全仓 667 项通过（2 skipped）、本地安装产物一致；真实窗口与安装版手测仍待用户执行。
- P13 完成（2026-11-09）：Markdown 数学公式、Mermaid 类围栏与 HTML 收口为可读、非执行边界。公式 / 图表保留带标签源码，行内公式去掉定界符并保留章节偏移，HTML 只留安全可见文字并整段移除危险标签；内部边界使用每次解析的随机 token，作者正文里的同名标记不会被误识别。代码审查后补修未知命名 HTML 实体被误删的问题，保留 `&copy;` / `&mdash;` 等原文。无公式引擎、图表 JS、HTML 执行、远程资源或新依赖。展示变换仍在唯一章节文本上，分页标签与 continuation 保留。修复后证据：边界 / 解析 / 渲染 / 分页聚焦 72 项、全仓 680 项通过（2 skipped）、发布准备 6 项通过（2 skipped）、本地安装产物一致；真实窗口与安装版手测仍待用户执行。
- P14 完成（2026-11-09）：用户截图反馈数学公式仍显示 LaTeX 源码。Markdown 公式改为 `flutter_math_fork` 本地 TeX 排版，引入 `MathSource` 归一化 `\displaystyle`、`\frac1{x^2}` 等笔记写法；独立公式与行内公式分别通过块 / run 的 `mathSource` 传到渲染层，无效公式安静回退为原表达式。公式 Widget 放在共享 `math_view.dart`，不进入章节文本、搜索、进度、选区、批注或 locator；批注高亮仍保持纯 `TextSpan`。图表与 HTML 保持 P13 可读边界。截图复核后补修：以 `\}` 结尾的行内公式不再被漏识别，跨行 `$$` 不再误吞正文，分页切段不再从行内公式中间切开，并为分数 / 极限 / 根号预留高度。随后又修短章节阅读列塌缩：连续模式与分页模式的章节列在 `ConstrainedBox` 内撑满可用宽度，短章节不再按最宽子项 shrink-wrap 后被居中。修复后证据：布局 / Markdown / 连续切片 / 分页聚焦 45 项、全仓 688 项通过（2 skipped）、发布准备 6 项通过（2 skipped）、本地安装产物一致（`libapp.so` SHA256 `635b0b5d…`）；真实窗口与安装版手测仍待用户执行。
- P15 完成（2026-11-09）：继续对齐 Typora 阅读行为。Markdown 表格保留分隔行的列对齐并沿分页 / 连续片段传到渲染层，表头与续页表头一致；一至六级标题生成 GitHub 风格锚点并支持普通 `[文字](#标题)` 内部跳转，同名标题自动加后缀，未知锚点安静忽略；连续模式移除覆盖正文的 96 px 左右翻页热区，边缘链接与选区不再被挡住，分页模式仍保留点击翻页。证据：解析 / 渲染 / 分页 / 连续切片聚焦 72 项、全仓 693 项通过（2 skipped）、发布准备 6 项通过（2 skipped）、本地安装产物一致（`libapp.so` SHA256 `97252edb…`）；安装后已重启本地实例，真实阅读体验与 Windows/Android 仍未验证。
- P16 完成（2026-11-09）：嵌套引用保留层级，Markdown 与 EPUB 共用。`quoteDepth` 覆盖文本、表格、图片和分隔线，并沿解析、分页和连续片段传递；分页宽度按每层 16 px 缩窄，引用内的标题、列表、表格、代码、图片、分隔线和独立公式都按同一预算收窄，表格列宽按收窄后的宽度分配，渲染层为每一层画独立竖线。章节文本、搜索、选区、进度和 locator 偏移不变。证据：解析 / 分页 / Markdown 渲染聚焦 82 项、全仓 704 项通过（2 skipped）、本地安装产物一致（`libapp.so` SHA256 `beccaccf…`）；安装后已重启本地实例（PID `1085852`），真实窗口与 Windows/Android 仍未验证。
- P17 完成（2026-11-09）：引用内标题不再改变书籍结构。引用中的 `h1` 保留标题样式、锚点和 `quoteDepth`，但不再触发章节切分；引用中的 `h2` 不再写入章节目录。顶层 `h1` 的分章行为不变，标题文字、搜索、选区、进度、批注和 locator 偏移保持不变。证据：Markdown 解析 / 渲染与 EPUB 分页聚焦 78 项、全仓 706 项通过（2 skipped）、本地安装产物一致（`libapp.so` SHA256 `5fb96b7a…`）；安装后已重启本地实例（PID `1232741`），真实窗口与 Windows/Android 仍未验证。
- P18 完成（2026-11-10）：Markdown 表格单元格复用正文行内样式。新增 `EpubTableCell` 保存单元格文字与局部 run，粗体、斜体、删除线、行内代码、链接、脚注引用和行内公式穿过表格、分页行切分与续页表头；渲染改用 `Text.rich`，链接复用正文外链 / 内链回调，分页测量与绘制共享样式函数。章节文本、搜索、选区、进度和 locator 偏移不变。证据：Markdown 解析 / 渲染与 EPUB 分页聚焦 81 项、全仓 724 项通过（2 skipped）、本地安装产物一致（`libapp.so` SHA256 `6dc082d6…`）；运行中的旧实例 PID `1097526` 未重启，待用户手动重启后生效；真实窗口与 Windows/Android 仍未验证。
- P19 完成（2026-11-10）：Markdown 表格单元格接入搜索命中、批注高亮与临时聚焦。`EpubTableCell.chapterOffset` 把单元格局部文字映射回章节坐标；搜索按大小写不敏感匹配切分 span，批注按 locator 范围求交或退回文字匹配，聚焦范围复用同一映射；批注点击发 `RendererAnnotationSelected`。同时修正 `epubFocusRangeFor` 拒绝 Markdown locator 的问题。证据：Markdown 解析 / 渲染、EPUB 分页与跳转聚焦 96 项、全仓 726 项通过（2 skipped）、本地安装产物一致（`libapp.so` SHA256 `d26f8c12…`）；安装时运行中的 PID `2633513` 启动于安装前，待用户手动重启后生效；真实窗口与 Windows/Android 仍未验证。

标注批注（2026-11-10）：
- 完成 Word 式文本批注：选区菜单新增独立「批注」，保存为关联 `NoteType.comment`；点击划线 / 高亮直接显示批注正文，可添加、编辑、修改样式或删除，不要求先进入笔记页。
- Notebook 把批注显示在对应标注条目下，不重复生成批注条目；删除带批注的标注会同时删除批注，普通关联笔记保留。已有批注可只删批注并保留划线，标注的 `note_id` 同步清空；从笔记页删除关联笔记也会解除关联。批注复用 `annotations.note_id` / `notes.annotation_id` 与既有 `note_type` 文本列，无 schema 迁移。
- 证据：批注 / Notebook / 标注仓储 / 阅读器 widget 聚焦 57 项通过；全仓 730 项通过（2 skipped）；本地安装产物一致（`libapp.so` SHA256 `8f33c195…`）；安装时没有运行中的 PageSage 进程。真实窗口、Windows/Android 和长批注布局仍未验证。详见 `docs/tasks/annotation-comments-2026-11-10.md`。

AI 检索层（`docs/12-ai-retrieval-strategy.md`，2026-10-21）：
- **选型已定**：全书 / 文件夹关联采用「结构感知的词法检索」（复用 FTS5 + EPUB 目录树 / PDF 大纲），**不采用 DCI，不引入向量 RAG**。
- 依据：DCI 在 Android 无 shell 不可行；实测同准确率下 token 高 338×、成本高 17.5×、延迟 4–20×；论文自述语料从 10 万增至 40 万文档时准确率跌至 37.5%。向量 RAG 需 100MB+ 嵌入模型与两个原生依赖，对 3,499 块的语料规模不划算。
- **发现断链缺陷**：AI 面板「前后段落 / 当前章节 / 当前页」三项范围从未生效——`ContextBuilder.build()` 的 `availableText` 生产代码从未传入。
- **第 1 步已完成**：`AiPanel(bookPath, isEpub)` → `AiContextSource`（磁盘读一页 PDF / 一章 EPUB）→ `availableText`；读不到或本页无文字时明确提示并退回「仅选中文本」。US-008 恢复 `[x]`。
- **第 2 步已完成**：发送内容改为引用清单（`ai_context_reference.dart`）：每段可看来源与字数、可跳回原文、可移除、可逐段编辑；多段带 `【来源】` 标题，隐私确认框逐段列出。
- **第 3 步已完成**：多轮对话。`AiRequest.history` 携带本会话此前各轮，上下文只挂在开篇一轮；`ai_conversations.thread_id` 归组，Drift v3 → v4 新增该列（旧会话置空、不猜历史）。换选区/换范围/删引用都会断开会话。
- **第 4 步已完成**：全书关联。`ContextRetriever` 直接对 `SearchChunks` 正文做 BM25（FTS5 的 `unicode61` 对中文基本失效，实测「数据」21 命中 vs 489 实含），中文按二元组切词；`_looksLikeContents` 过滤目录页；引用从命中点前 180 字截取。真实库单本检索 100–190ms。
- **第 5 步已完成**：文件夹关联。同 `categoryId` 下的书一起检索，每本最多 2 段；跨书引用行显示 `书名 · 页码`，点击走 `/book/:bookId/reader` 并在目标书定位。书没有文件夹时返回空结果，不扩大到全库。
- 实施顺序：① 修断链 → ② 引用区 UI → ③ 多轮对话 → ④ 全书关联 → ⑤ 文件夹关联（全部完成）。

---

## 3. 收尾建议（仅人工）

1. 按 `docs/v1-experience-freeze.md` 冻结 v1.0 体验范围（单 chrome、标注契约、扫描 PDF 降级策略）。  
2. 按 `docs/m4-release-checklist.md` 做 Windows 备份恢复与阅读闭环手测。  
3. 有 Android 设备时跑一遍导入→阅读。  
4. 可选：商店签名、完整 Markdown 包、中文分词。

---

## 4. 一句话结论

| 范围 | 结论 |
| --- | --- |
| 产品书功能主路径 | **已基本完成** |
| 工程侧 M4/M5 | **代码与文档就绪** |
| 发布/双端手测 | **待人工勾选** |
