# 本地检索评测输入

评测器只读取本机资料，不调用模型。默认输入为
`.local-data/retrieval-eval/dataset.json`，默认输出为同目录的 `report.json`；
该目录已被 Git 忽略。原始报告包含问题、来源标题、文件路径、数据库标识与
指纹，只能在本地保管，不能直接提交。

## 准备与执行

1. 使用自己有权评测的测试文档和独立测试数据库。
2. 参考 [`example.json`](example.json) 准备本地题集；其中的书籍 ID 必须替换为
   测试数据库中的 ID。示例为自编文本，不是历史评测样本。
3. 在仓库根目录执行：

```bash
dart run tool/evaluate_chunking_effect.dart \
  --dataset .local-data/retrieval-eval/dataset.json \
  --database .local-data/retrieval-eval/pagesage.sqlite \
  --output .local-data/retrieval-eval/report.json
```

发布结果前人工移除书名、目录、文件指纹、书库 ID、问题及证据原句和来源标题。
可以保留数值指标及算法配置，但必须标明脱敏后的文件不能独立复现原始实验。
不要把新编示例产生的结果与旧样本指标混用。

## 历史记录

2026-11-08 的三份真实书库题集曾包含个人资料，现已从当前源码移出。
`docs/eval/retrieval-*2026-11-08*.json` 只保留脱敏统计和匿名逐题指标，
不包含可供重放的完整输入。其生成时间、历史指标和局限仍按原记录保留，
不代表本次重新运行过评测。历史任务中的相应命令需要另行提供本地私有样本。
