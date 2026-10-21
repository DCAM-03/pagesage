# Worktree Policy

Use a dedicated worktree when two sessions may write the same Git root concurrently or when the existing checkout must remain on its current branch. Independent repositories with clean dedicated checkouts may use one task branch in each repository without creating redundant secondary worktrees. A multi-repository task still records one workspace decision per writable Git root.

Before creating or reusing a worktree, record:

- repository and source checkout;
- exact base ref and current HEAD;
- `git status --short`;
- intended branch and worktree path;
- whether the dependency is writable or read-only.

Before creating a session that can write a worktree, reconcile the task registry and discovered session history. Enforce
one active execution owner for each `(task, repository, branch, worktree, role)` tuple. A missing registry session ID is
not proof that the tuple is free.

Classify the existing worktree before dispatch as:

- `CLEAN`: no changes from the recorded base;
- `ACCOUNTED_TASK_SCOPED`: changes match the declared task and an existing session/record;
- `UNACCOUNTED_TASK_SCOPED`: changes match the declared task but no session/record is linked;
- `UNRELATED`: changes are outside task scope and require preservation; or
- `CONFLICT`: another session or incompatible branch/base already owns the worktree.

`UNACCOUNTED_TASK_SCOPED`, `UNRELATED` changes in the target worktree, and `CONFLICT` are hard dispatch blockers until
the changes are explained, preserved, or explicitly authorized. Reconcile the originating session and registry first;
do not create a second session, switch branches, or overwrite the worktree. Verify that the task document, handoff,
branch/worktree snapshot, and dispatch reservation contain the same base revision before delegating.

Before writing, verify the exact Git root is within the current session's allowed workspace root and read the target and parent `AGENTS.md`. A discovered matching directory outside that root is not a writable target. If the declared path is missing, stop and request explicit directory authorization rather than searching for another checkout.

When a secondary worktree is required, create it with the repository-local equivalent of:

```bash
git -C <source-checkout> worktree add -b <task-branch> <worktree-path> <base-ref>
```

If the branch already exists, verify that it belongs to the task and is not attached to another incompatible worktree before reusing it. Do not guess, switch away from another session's branch, or adopt an unexplained dirty worktree.

For formatter or generated-code commands, capture these before and after the command:

```bash
git status --short
git diff --name-only
git diff --stat
```

Record the exact command, timestamp, and affected file count. Accept mechanical changes only when every changed file is explained by the task scope and the recorded command. Escalate unexplained changes instead of labeling all post-formatter output as trusted.

## Merge And Cleanup Audit

Use a clean, disposable merge worktree or an explicitly authorized clean checkout for the merge. A merge performed in a
detached worktree is not complete merely because the worktree contains the expected tree: verify the destination branch
ref itself after the operation.

Record and verify, in order:

1. destination repository, branch, pre-merge ref, accepted commit, and post-merge ref;
2. `git merge-base --is-ancestor <accepted-commit> <destination-branch>` succeeds;
3. `git rev-parse refs/heads/<destination-branch>` equals the expected post-merge commit (or an explicitly recorded
   descendant), and `git status --short` is clean in the merge worktree;
4. the task record contains the merge commit/ref and the exact verification commands before marking the task closed.

If a detached worktree was used, do not infer that its `HEAD` moved the named branch. Update the actual branch through
the repository's normal merge path, then repeat the ref and ancestry checks. Never use a force update to repair a merge
without explicit authorization and a recorded old/new ref.

Cleanup is split into two inventories:

- product task worktrees: after `ACCEPTED` and merge verification, remove only the declared task worktree when it is
  clean; retain any uncommitted work and report it for reconciliation;
- app-managed or detached coordination worktrees: first reconcile their owning session with the app lifecycle and
  archive/lifecycle state, then remove them only through the owning app/Git lifecycle. Do not delete registered detached
  worktrees solely because they are not product branches.

Record the cleanup owner, inventory checked, removal result, and any retained detached worktree in the task or release
record. A clean source checkout is not required when it contains unrelated user changes; those changes must remain
untouched. The clean requirement applies to the task/merge worktree used for the operation.

Do not automatically remove a worktree after implementation. Cleanup belongs to the task owner after acceptance and must not discard uncommitted work.
