---
name: git-cleanup
description: >
  Skill to automate Git branch cleanup after PR merge. Deletes merged branches,
  prunes remote tracking branches, and switches to the merge target branch in one go.
  Invoke with /git-cleanup (optionally specify the target branch, defaults to main).
  Use in scenarios such as: post-merge branch cleanup, deleting unnecessary branches,
  cleanup after merge, branch cleanup after merge,
  "delete the merged branch", "clean up branches".
  Proactively suggest this when branches accumulate while working in a git repository.
---

# git-cleanup: Post-merge Branch Cleanup Skill

Safely and efficiently executes the series of branch cleanup tasks needed after merging a PR.

## Arguments

- `<target-branch>` (optional): Merge target branch name. Defaults to `main`.
  - Example: `/git-cleanup` → Switch to main
  - Example: `/git-cleanup develop` → Switch to develop

## Execution Flow

Execute the following steps in order. If a problem occurs at any step, report immediately and ask the user for guidance.

### Step 1: Pre-check

Confirm we are in a git repository and assess the current state.

```bash
# Confirm inside a git repository
git rev-parse --is-inside-work-tree

# Get current branch name
git branch --show-current

# Check for uncommitted changes
git status --porcelain
```

**If uncommitted changes exist**: Display the following warning and confirm with the user whether to continue.

> There are uncommitted changes. Switching branches may cause changes to be lost.
> Continue? (You can also stash before continuing.)

If the user opts to stash, run `git stash` before continuing.

### Step 2: Switch to Merge Target Branch

```bash
# Switch to target branch
git checkout <target-branch>

# Pull latest from remote
git pull origin <target-branch>
```

If the target branch does not exist, report an error and stop.

### Step 3: Delete the Original Feature Branch

Delete the branch that was checked out before switching (the feature branch) from local.

```bash
# Confirm it is merged, then delete (-d is safe delete)
git branch -d <feature-branch>
```

**Important**: Never use `-D` (force delete). If `-d` fails, the branch may not be merged yet — confirm with the user.

If the original branch was a main branch (main/develop, etc.), skip this step.

### Step 4: Prune Remote Tracking Branches

Clean up local references to branches that have been deleted on the remote.

```bash
git remote prune origin
```

### Step 5: Check for Other Merged Branches

```bash
# List local branches merged into the target branch
git branch --merged <target-branch>
```

After excluding protected branches (main, develop, master, etc.), display the list if merged branches remain.

Display example:
> The following branches are merged. Delete them?
> - feature/old-feature
> - fix/typo-correction
>
> (Tell me which branches to delete. Say "all" to delete all.)

Delete the specified branches with `git branch -d` according to the user's instructions.

### Step 6: Completion Report

Display the final branch state and report completion.

```bash
git branch -a
```

Report example:
> Branch cleanup complete.
> - Current branch: main
> - Deleted branches: feature/my-feature, fix/old-bug
> - Remote pruning: Done

## Safety Guards

Strictly follow these rules:

- **Never delete protected branches**: Exclude main, master, develop, dev, release/* from deletion targets
- **Never force delete (-D)**: Always use `-d` (safe delete) and never delete unmerged branches
- **Protect uncommitted changes**: Always confirm with the user when changes exist
- **No bulk deletion without confirmation**: Get explicit user consent before bulk-deleting merged branches
- **Dry-run mindset**: Show the user what will be done at each step and get approval before executing
