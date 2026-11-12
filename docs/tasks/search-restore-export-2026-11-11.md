# 搜索、恢复与导出联合收口

范围：用户确认的三项工作；Linux 优先，不调用真实模型，不操作用户数据库。

## 实施与验证计划

1. 搜索：用生产 Drift 仓储建立 10k chunks / 至少 1,000 万 UTF-16 的固定合成语料；
   分组记录冷启动、5 次预热后 30 次查询的 P50/P95、索引体积与定位正确性。
   组件验证连续输入、过期结果隔离和结果跳转参数；不把合成语料等同真实书库。
2. 恢复：使用临时文件 SQLite，覆盖 WAL 中尚未 checkpoint 的笔记/批注/配置/OCR/索引；
   备份后修改原库，再恢复、关闭、重开，检查数据、来源、任务暂停与密钥隔离。
3. 导出：保存路径选择不能提前写空文件；取消、写入失败保留已有文件；Linux
   可打开结果所在目录。验证平台适配器、真实文件写入及设置页交互。
4. 定向测试、静态分析、自审通过后，静默构建安装并核对完整 bundle。

## 基线发现

- 设置页已调用保存选择器；旧文档称仅写 exports 已过时。
- file_picker 12 的保存 API 会写入 bytes，目前空 bytes 请求会提前清空目标。
- 导出提交前删除旧目标、设置页取消清理删除最终目标，均可能损失已有文件。
- 备份直接读取数据库主文件，未创建包含 WAL 的一致快照。
- 恢复当前未落实配置 UUID 隔离和任务暂停；需同时检查封面资源恢复。

## 实施结果（2026-11-12）

### 搜索

- 查询不再全量重算旧式分词、写入 term 表并重建两路 FTS；只为缺失或版本过期的
  legacy / active generation 回填。块更新使派生 term 失效，块和 term 的发布处于同一事务。
- 候选 SQL 先按 ID 和排名排序、截断，再读取正文，保留过滤先于截断的顺序。
- 输入变化立即撤销旧请求的展示资格，不等 250ms 防抖结束；清空输入也清除旧结果。
- 搜索跳转携带实际命中范围，而非整个块的起点；保留 Markdown 文件路径与文件内定位。
  不对 OCR 页级结果编造精确坐标。
- 修复 emoji 后 UTF-16 映射偏移、混合查询组顺序遗漏高亮；归一化版本升级为
  `normalizer-v2`，仅折叠 ASCII 大小写。新索引保留原始块的前后空白，不改变来源偏移。

### 备份恢复

- 从 SQLite 创建包含 WAL 的一致快照，再压缩；快照在后台 isolate 创建，临时文件自动清理。
- 恢复预演升级后重新分配配置 UUID、同步活动配置与历史关联，历史请求快照仍保留原样；
  清除旧 credential journal，阻止本机旧密钥与恢复配置重新绑定。迁移完成后的空配置
  也不回退读取遗留单配置密钥；不删除本机旧密钥。
- OCR 活跃任务暂停，未完成识别页回到 pending，已完成页及 OCR 正文保留；普通中断任务
  显示需手动重试。索引发布指针与 FTS 随数据库一起恢复。
- 封面先落入 staging，再替换；数据库和原封面均留回滚副本。拒绝封面路径穿越与符号链接。
- 设置页恢复直接调用恢复服务并刷新数据库 provider，避免关闭旧库后又向旧任务仓储写成功。
  恢复前检查当前活跃任务，选择/确认期间出现的新任务也再次检查。

### 导出

- 桌面保存路径使用 `file_selector 1.1.0`，选择路径本身不写入空字节。
  这是 Flutter 的轻量平台文件选择插件，不含模型或大型资源；Windows 同步插件注册，
  Android 的现有 file_picker 分支保持不变。本轮只验证 Linux。
- 明确保留用户选定的完整文件名，不在选择器确认后追加扩展名而覆盖另一个目标。
- 文本和 zip 使用独立临时文件，成功后 rename；取消/失败保留既有目标，清理本次临时文件。
  任务中心取消导出也不再删除最终目标。
- 图片批注每次写入独立资源目录，失败清除本次资源；图片文件名包含书籍身份，避免两本书
  的同页同序号图片互相覆盖。已成功导出的旧资源目录保留，避免破坏其他导出引用。
- 设置页防重复操作，区分取消、文件选择失败与写入失败；Linux 的“打开位置”通过
  `xdg-open` 打开所在目录，按参数数组传递，不调用 shell。

## 验证证据

- `test/core/search/search_scale_benchmark_test.dart`：显式启用的规模基准，
  10,000 个块、11,193,430 UTF-16 单位、25,809,990 UTF-8 字节；六组查询各预热 5 次、
  计时 30 次，固定 nearest-rank 分位数，检查结果稳定、过滤不越界、文件定位与命中范围。
  最新机器可读结果见 `docs/eval/search-scale-2026-11-12.json`。
- 机器：Intel Core Ultra 9 285H，16 逻辑 CPU，约 31 GiB RAM；Linux 7.2.15，
  Flutter 3.44.2 / Dart 3.12.2。测试运行期间存在其他桌面负载，不是独占机器。
- 初版基准约 14 分钟仍未完成，确认每次查询重写全量 term/重建 FTS 后主动中断，
  日志 `/tmp/pagesage-search-scale.log`；不据此计算不完整的加速倍数。
- 修正全量回填后，中英混合 P95 仍为 346ms；缩小 SQL 排序数据后降至约 152ms。
  中间结果 `/tmp/pagesage-search-scale.json`、`/tmp/pagesage-search-scale-final.json`。
- `test/core/database/chinese_search_repository_test.dart`：精确高亮、emoji/空白偏移、
  查询组顺序、暖查询零 term 写入、过期版本只回填一次；含现有 generation 回归。
- `test/features/search/search_page_test.dart`：新输入在防抖期间隔离旧响应；结果菜单跳转
  保留书籍、Markdown 文件、起止偏移和原文摘录。
- `test/features/export/export_service_test.dart`：真实 WAL 文件库的联合备份→修改→恢复→重开，
  检查笔记/批注关联、书签/进度、AI 配置/历史、OCR 完成页/暂停页、FTS、封面和回滚；
  同时覆盖无效备份、v10/v11 迁移、路径穿越、取消、失败、同名文件和跨书图片。
- `test/features/settings/settings_export_test.dart`：生产设置页接真实临时库与导出服务，
  覆盖恢复后成功反馈、导出成功/取消/选择器异常/写入失败、重复点击与打开目录。
- 受影响定向回归 `/tmp/pagesage-three-regression.log`：257 项通过，1 项规模测试默认跳过
  （规模测试另行显式执行）。不称为全仓回归。
- 最终定位与索引修正后，数据库/搜索/检索/全局搜索补测
  `/tmp/pagesage-search-final-regression.log`：112 项通过，与上述用例有重叠，不相加。
- 最终规模日志 `/tmp/pagesage-scale-release-evidence.log`：1 项通过；日志名不代表
  release 执行。六类暖查询 P95 为 120–199ms，连接重开首查 49–228ms；数据库
  197,681,152 字节（含正文及旧索引），为原 UTF-8 正文的 7.66 倍，低于 10 倍上限。
  机器负载导致不同轮次有波动，完整各组数值以最新 JSON 为准。
- 最终空配置密钥隔离修正后，恢复/配置迁移/设置操作补测
  `/tmp/pagesage-restore-final.log`：39 项通过（与前述回归重叠，不相加）。
- 最终静态分析 `/tmp/pagesage-three-analyze-installed.log`：No issues found；
  `git diff --check` 通过；新增依赖许可证清单已由项目工具更新。
- `CMAKE_BUILD_PARALLEL_LEVEL=4 bash tool/install_linux.sh` 退出码 0，日志
  `/tmp/pagesage-three-install.log`；完整 bundle 对比日志
  `/tmp/pagesage-three-install-diff.log` 为空。安装目录为
  `<HOME>/.local/opt/pagesage`，两处 `lib/libapp.so` 的 SHA-256 均为
  `fe1261c3aec4e47a50dac58c4a91fbaf1a02dae4c7d349d83aa4ddfc5e31ca99`。
  安装后检查无运行中的 PageSage 进程，未启动或重启窗口。

边界：基准为 Flutter debug 测试进程中的固定合成语料；“冷”仅指数据库连接重开，
未清空 OS 页缓存，不是 release/真实书库冷启动性能验收。UI 使用离屏合成输入，
文件选择器及文件管理器以平台替身验证调用；本轮未打开原生对话框、文件管理器或应用窗口。
备份包含数据库与封面，不包含书籍正文或 Markdown 源目录，不宣称可搬迁到没有原书的新机器。
