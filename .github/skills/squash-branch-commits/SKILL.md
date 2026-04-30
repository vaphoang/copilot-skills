---
name: squash-branch-commits
description: >
  Squash all commits on the current branch into one commit before a pull request. Use for "squash commits", "make one commit", or "prepare branch for PR".
allowed-tools: shell
argument-hint: "[optional: commit message]"
---

# Squash Branch Commits

- Squashes all commits on the current branch (since base branch) into one.
- Never run on protected branches (`main`, `master`, `develop`, `release/*`) unless user insists.
- Show base branch, merge-base, and current branch before squashing.
- Abort if uncommitted changes exist.
- After squashing, remind user to push with `--force-with-lease` if needed.

**Usage:**  
1. Run: [scripts/squash-branch-commits.sh](./scripts/squash-branch-commits.sh) `[commit message]`  
2. Report resulting commit SHA and recommended push command.
