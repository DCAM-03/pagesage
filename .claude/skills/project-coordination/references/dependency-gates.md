# Dependency Gates

Classify each relationship as one of these:

- `hard prerequisite`: downstream work cannot implement safely before upstream evidence exists.
- `soft dependency`: work can proceed with a documented assumption and later reconciliation.
- `independent`: work can run in parallel.

Typical hard prerequisites include an unresolved locator format, renderer bridge message shape, Drift migration contract, privacy or secure-storage rule, or an unaccepted product decision.

An external recommendation is not an accepted product decision or implementation prerequisite merely because it is stored under `docs/decisions/`. Before dispatch, require a local decision owner, explicit disposition, and implementation authorization. When the project accepts only part of an external proposal, the local decision controls and the original proposal remains reference input.

Before creating a cross-session task, verify the target owner and writable Git root, record the allowed workspace root, and confirm the target root is inside it. Read `AGENTS.md` and the controlling docs. An expected target path that does not exist is a blocker requiring explicit directory authorization; do not search for a same-name repository or checkout.

When a hard prerequisite is incomplete:

1. Dispatch only the prerequisite owner.
2. Record the required execution evidence.
3. Do not create a downstream task by default. Only when the user explicitly asks, create a future placeholder marked `DESIGN_ONLY + BLOCKED`, naming the missing evidence and stating `Do not dispatch, create a worktree, or implement.`
4. Re-evaluate after the prerequisite execution record is present.

Do not turn a missing external input into a guessed implementation. Record the input, the owner who must provide it, and the behavior permitted while it is missing.
