# Instruction Governance

Use this mode when the user explicitly asks to consolidate or revise PageSage's `AGENTS.md`, `CLAUDE.md`, its Skills,
or the MCP/agent configuration. This mode governs agent instructions; it does not authorize product code, schema,
migration, runtime, or release changes.

## Direct Coordination Exception

The coordination session may inspect, edit, and validate instruction surfaces in one session when all of these are
true:

1. The user explicitly authorized instruction governance.
2. The writable scope is limited to `AGENTS.md`, `CLAUDE.md`, `.claude/skills/` and their references/metadata,
   `.agents/skills/`, `.mcp.json`, `.codex/config.toml`, `.codex/rules/`, `.claude/settings.json`, read-only structural
   checks, and documentation links that would otherwise be broken.
3. No product behavior, generated product artifact, public contract, dependency version, CI workflow, or release
   state changes.
4. The session does not commit or push unless the user separately requests it.

This exception prevents process documentation from requiring a product-style task, execution session, and acceptance
session merely to improve the process documentation itself. It does not weaken the normal lifecycle for product work.

## Repository And Dirty-Tree Handling

- Confirm the real Git root before editing and inventory existing changes.
- A dirty product branch is not automatic permission to mix changes. Continue only when the user explicitly authorizes
  same-round instruction cleanup and the instruction paths are disjoint from product implementation.
- Never revert, stage, commit, or merge unrelated product changes while performing instruction governance.
- At completion, report the exact instruction-only diff boundary and any product changes that remain pending.

## Content Ownership

PageSage keeps two agent platforms; their instruction files stay aligned but are not copies.

- `AGENTS.md` owns durable product boundaries, architecture, source-of-truth documents, UI rules, verification
  commands, MCP usage, and collaboration rules. It is the cross-platform source of truth.
- `CLAUDE.md` owns Claude Code specifics: the `@AGENTS.md` import, project MCP declarations, permission notes, and the
  Claude-side conventions.
- Skills own reusable workflows and detailed engineering practice. Each skill states which project documents it reads;
  it must not restate their content.
- `.mcp.json` owns the Claude Code MCP declarations; `.codex/config.toml` owns the Codex equivalents. Keep the server
  list aligned and note deliberate differences.
- `.claude/settings.json` owns Claude permissions and MCP approval; `.codex/rules/*.rules` owns Codex command-prefix
  policy only.
- `.claude/skills/` and `.agents/skills/` are separate installed copies. A change to one is not a change to the other;
  say explicitly which platform you updated. Do not mirror an inactive platform's files.

Keep one authoritative location for each rule. Root instructions summarize shared constraints; skill references carry
depth. Do not duplicate a rule in `AGENTS.md`, `CLAUDE.md`, a skill, and a task document.

## Validation Gate

Before declaring instruction governance complete:

1. Validate every changed skill: the frontmatter has `name` and `description`, the `name` matches its directory, every
   referenced `references/`, `assets/`, and `scripts/` path exists, and internal links resolve.
2. Re-run any script tests changed by the edit (`python3 test_coordctl.py`, `python3 test_scan_code_quality.py`) and
   confirm they pass.
3. Confirm `.mcp.json` and `.codex/config.toml` still declare the same server names, or record the intended difference.
4. Verify no Markdown files under `.codex/rules/`, no broken links, and no accidentally tracked local-only files.
5. Run `git diff --check` in the repository.

Historical records may retain truthful references to former tools. Update current instructions and live links; do not
rewrite historical evidence merely to make a text search empty.
