# PageSage — Claude Code

@AGENTS.md

## Claude Code 配置

- 项目 MCP 声明：`.mcp.json`（与 `.codex/config.toml` 对齐）
  - `openaiDeveloperDocs`：OpenAI / API 文档查询
  - `dart`：Dart / Flutter 分析、包查找、格式化、测试、设备与运行中 App 检查
- 项目权限与 MCP 批准：`.claude/settings.json`
- Codex 命令 allowlist 对照：`.codex/rules/default.rules`

首次在本仓库使用项目 MCP 时，若提示 Pending approval，在 `/mcp` 中批准，或确认 workspace trust 后依赖 `enableAllProjectMcpServers`。

## Claude 侧补充约定

- 工作流正文与参考统一使用 `.agents/skills/`；按 `AGENTS.md` 的任务表读取对应入口。
  `.claude/skills/` 保留四个轻量发现入口，执行时必须读取其链接的共享正文，不复制维护另一套规范。
- 优先用 `dart` MCP 做 Flutter/Dart 分析、测试与设备相关操作；没有 MCP 时再回退到 Bash。
- 修改 AI 提供方行为或 Codex 配置前，先查 `openaiDeveloperDocs`（若已连接）。
- 文档默认中文；代码标识符保持英文。
- 变更范围优先 M0 / M1，除非用户明确要求其他里程碑。
