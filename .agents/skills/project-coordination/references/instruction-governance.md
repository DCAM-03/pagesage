# Instruction Governance

Use this mode when the user explicitly asks to consolidate or revise the current project's `AGENTS.md`, Skills, or Codex configuration/execution policy. This mode governs agent instructions; it does not authorize product code, API, schema, migration, runtime, or deployment changes.

## Direct Coordination Exception

The coordination session may inspect, edit, and validate instruction surfaces across several Git roots in one session when all of these are true:

1. The user explicitly authorized instruction governance across those roots.
2. The writable scope is limited to active-platform instructions, Skills and their references/metadata, Codex config/rules, read-only structural checks, and current documentation links that would otherwise be broken.
3. No product behavior, generated product artifact, public contract, dependency version, CI workflow, or deployment state changes.
4. The session does not commit or push unless the user separately requests it.

This exception prevents process documentation from requiring a product-style task, execution session, and acceptance session merely to improve the process documentation itself. It does not weaken the normal lifecycle for product work.

## Repository And Dirty-Tree Handling

- Confirm every real Git root before editing and inventory existing changes.
- A dirty product branch is not automatic permission to mix changes. Continue only when the user explicitly authorizes same-round instruction cleanup and the instruction paths are disjoint from product implementation.
- Never revert, stage, commit, or merge unrelated product changes while performing instruction governance.
- At completion, report the exact instruction-only diff boundary and any repositories where product changes remain pending.
- Keep workspace-local discovery symlinks out of tracked repository state unless the project deliberately owns those links. `.codex/workspace-links.tsv` is the only target allowlist. The checker is read-only; the restore script requires an explicit `--apply` after global preflight and separate user authorization.

## Content Ownership

- `AGENTS.md` owns durable product boundaries, architecture, repository ownership, and hard local constraints.
- Skills own reusable workflows and detailed engineering practice.
- `.codex/rules/*.rules` owns command-prefix execution policy only and must contain valid Starlark `prefix_rule()` declarations.
- `.codex/config.toml` owns project-scoped Codex configuration and MCP declarations.
- Read-only check scripts validate structural invariants. The restore script may recreate only manifest-declared links and Git exclude entries; creating or repairing any other workspace path requires a separately authorized change.

Keep one authoritative location for each rule. Root instructions summarize shared constraints; child instructions contain subtree-specific deltas; Skill references carry depth. Do not mirror inactive agent-platform files.

## Validation Gate

Before declaring instruction governance complete:

1. Validate every changed Skill with the platform's Skill validator.
2. Validate each `.rules` file with the active Codex execution-policy checker.
3. Run the read-only workspace checker and verify all intended child Git roots resolve the expected Skills and config.
4. Verify no retired platform files, Markdown files under `.codex/rules/`, broken links, or accidentally tracked workspace-local links remain.
5. Run `git diff --check` in every affected Git repository.

When the manifest or restore implementation changes, also run its focused regression tests. A dry run must produce no writes; a preflight conflict must produce no writes; an apply-time failure must roll back links, created directories, and Git exclude changes.

Historical records may retain truthful references to former tools. Update current instructions and live links; do not rewrite historical evidence merely to make a text search empty.
