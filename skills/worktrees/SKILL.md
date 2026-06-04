---
name: worktrees
description: |
  Create a ready-to-code git worktree for feature development or code review, bootstrapped and ready in <60s. Supports Node (npm) and Java (Maven) repos.
version: 1.5.0
triggers:
  - create worktree
  - new worktree
  - worktree feature
  - worktree review
  - wt
---

# Git Worktrees

Quick-create isolated worktrees for feature development or code review with automatic repo bootstrap.

## Overview

Creates a git worktree at `.worktrees/<name>`, auto-detects project type (Node/Java), runs minimal bootstrap (`npm ci` / `mvn compile`), and leaves you ready to code in one command.

- **Feature mode:** creates fresh branch from base, names it `<user>/<ticket>-<slug>`.
- **Review mode:** checks out an existing branch or PR ref.
- **Cleanup:** auto-prune stale worktrees with `--force`.

Targets: **Node (npm)** + **Java (Maven)** repos. No global dependencies beyond `git` and `bash`.

## Procedure

### 0) **Check prerequisites**

```bash
command -v git >/dev/null || { echo "❌ git required"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ must run inside a git repo/worktree"; exit 1; }
# Required when input is PR URL/number:
command -v gh >/dev/null || { echo "❌ gh required for PR URL/number resolution"; exit 1; }
```

### 1) **Feature mode: create a feature branch worktree**

**Input (required):**
- User ID / initials (inferred from `git config user.name` first letter + last initial, e.g., "phoang" -> "ph"; user can override).
- Ticket ID or short slug (e.g., "GH-1234" or "auth-fix").
- Optional: base branch (default: detect primary branch via `git rev-parse --abbrev-ref origin/HEAD` or assume `main`).

**Steps:**

0. **Generate branch name:**
   ```
   <user>/<ticket>-<slug>
   ```
   Example: `ph/GH-1234-jwt-refresh`. Show and ask user to confirm or edit (required prompt).

1. **Create and check out worktree:**
   ```bash
   worktree_path=".worktrees/<branch-name>"
   git worktree add "$worktree_path" --no-checkout
   cd "$worktree_path"
   git checkout -b "<branch-name>" "origin/<base-branch>"
   git branch --set-upstream-to "origin/<base-branch>" "<branch-name>"
   ```
   This sets upstream immediately so `git pull` works right away.

2. **Auto-detect and bootstrap (fail-fast):**
   - **Node**: If `package.json` exists:
     ```bash
     npm ci --legacy-peer-deps || npm ci
     ```
   - **Java**: If `pom.xml` exists:
     ```bash
     mvn -q -DskipTests compile
     ```
   - **Neither**: Skip (manual user action OK).
   - If bootstrap fails, stop and surface the error; do not continue to IDE setup.

3. **Auto-generate IDE project metadata:**
   Both IntelliJ and VSCode ready automatically:
   ```bash
   bash ../../../skills/worktrees/setup-intellij.sh "$worktree_path"
   bash ../../../skills/worktrees/setup-vscode.sh "$worktree_path"
   ```
   - IntelliJ: Generates `.idea/` with run configurations
   - VSCode: Generates `.vscode/` with tasks and recommended extensions

4. **Show summary (table format):**
   | Field | Value |
   |-------|-------|
   | **Path** | `.worktrees/ph/GH-1234-jwt-refresh` |
   | **Branch** | `ph/GH-1234-jwt-refresh` (new from `main`) |
   | **Bootstrap** | `npm ci` ✓ |
   | **IDEs** | IntelliJ ✓ + VSCode ✓ |
   | **Next (IntelliJ)** | `File → Open → .worktrees/ph/GH-1234-jwt-refresh` |
   | **Next (VSCode)** | `code .worktrees/ph/GH-1234-jwt-refresh` |

### 2) **Review mode: check out an existing branch or PR**

**Input (required):**
- PR link/number (e.g., `https://github.com/org/repo/pull/1234`, `#1234`) or branch ref (e.g., `origin/feature/auth`).
- User can optionally provide a shorthand worktree name; if not, infer from PR/branch (required prompt).

Prefer `origin/<branch>` for writable review worktrees (pushes go to the correct upstream branch).

**Steps:**

0. **Fetch and validate ref:**
   ```bash
   git fetch origin
   # Resolve PR URL/number to the PR head branch (writable), not pull/*/head (detached)
   if [[ "$ref" =~ /pull/([0-9]+) ]]; then
     pr_num="${BASH_REMATCH[1]}"
   elif [[ "$ref" =~ ^#([0-9]+)$ ]]; then
     pr_num="${BASH_REMATCH[1]}"
   fi

   if [[ -n "${pr_num:-}" ]]; then
     head_branch="$(gh pr view "$pr_num" --json headRefName --jq '.headRefName')"
     head_owner="$(gh pr view "$pr_num" --json headRepositoryOwner --jq '.headRepositoryOwner.login')"
     repo_owner="$(gh repo view --json owner --jq '.owner.login')"
     repo_name="$(gh repo view --json name --jq '.name')"

     if [[ "$head_owner" == "$repo_owner" ]]; then
       git fetch origin "$head_branch"
       ref="origin/$head_branch"
     else
       # Fork PR: create/use remote for the head repo and track that branch.
       fork_remote="pr-$head_owner"
       git remote get-url "$fork_remote" >/dev/null 2>&1 || \
         git remote add "$fork_remote" "https://github.com/$head_owner/$repo_name.git"
       git fetch "$fork_remote" "$head_branch"
       ref="$fork_remote/$head_branch"
     fi
   fi
   ```

1. **Create worktree from ref:**
   ```bash
   worktree_path=".worktrees/<name>"
   remote_branch="${ref#*/}"

   if [[ "$ref" == */* ]]; then
     # Writable flow: check out local branch with upstream tracking to <remote>/<branch>
     git worktree add --track -b "$remote_branch" "$worktree_path" "$ref"
   else
     # Local branch refs stay on that branch
     git worktree add "$worktree_path" "$ref"
   fi

   cd "$worktree_path"
   ```
   - For PR links/numbers and remote refs, pushes go to the tracked upstream branch immediately.

2. **Auto-detect and bootstrap (fail-fast):**
   - Same as feature mode (Node: `npm ci`, Java: `mvn -q -DskipTests compile`).
   - If bootstrap fails, stop and surface the error; do not continue to IDE setup.

3. **Auto-generate IDE project metadata:**
   Same as feature mode — auto-generate both IntelliJ and VSCode:
   ```bash
   bash ../../../skills/worktrees/setup-intellij.sh "$worktree_path"
   bash ../../../skills/worktrees/setup-vscode.sh "$worktree_path"
   ```

4. **Show summary:**
   | Field | Value |
   |-------|-------|
   | **Path** | `.worktrees/review-pr-1234` |
   | **Ref** | `origin/feature/auth` |
   | **Upstream** | `origin/feature/auth` (or `pr-<owner>/<branch>` for fork PRs) |
   | **Bootstrap** | `npm ci` ✓ |
   | **IDEs** | IntelliJ ✓ + VSCode ✓ |
   | **Next (IntelliJ)** | `File → Open → .worktrees/review-pr-1234` |
   | **Next (VSCode)** | `code .worktrees/review-pr-1234` |

### 3) **Cleanup: remove stale worktrees**

**Command (minimal interaction):**
```bash
worktrees cleanup --force
```

**Steps:**

0. **List all worktrees:**
   ```bash
   git worktree list --porcelain
   ```

1. **Identify stale (broken ref or locked):**
   ```bash
   # Mark worktrees with broken refs or no commits in 7+ days
   ```

2. **Prune with --force:**
   ```bash
   git worktree prune --force
   ```

3. **Show what was removed:**
   ```bash
   ✓ Removed 3 stale worktrees:
     - .worktrees/ph/old-feature
     - .worktrees/review-pr-1099
     - .worktrees/experiment-xyz
   ```

## Interaction Rules

- **Feature mode:** ask user to confirm/edit the generated branch name (required prompt); everything else auto.
- **Review mode:** ask user for PR number or branch ref (required); ask for optional worktree shorthand name if unclear.
- **Cleanup mode:** auto-prune stale; show summary of removed paths.
- **Generated text:** use concise tables for paths/status; avoid verbose prose.
- **Low interaction by default:** show summary, proceed without asking "create this?"

## Generated Text Style

- Show paths and commands in a compact markdown table.
- Keep next-action concise: "cd to path" or "run tests".
- No prose filler.

## Safety Rules

- Refuse if not in a git repo (check `.git/`).
- Refuse if worktree path already exists (ask user to clean up first).
- Show full branch name before checkout; user must confirm (required prompt for feature mode).
- In review mode, resolve PR URL/number to the PR head branch and track that remote branch (do not use detached `pull/*/head`).
- For cleanup: only prune worktrees with broken refs or stale lock files, never force-remove active worktrees.

## Pitfalls

- **Node monorepos:** `npm ci` at repo root may not be enough; consider `--workspaces` or ask user for workspace path.
- **Maven multi-module:** `mvn compile` compiles all modules; if repo has many, this may be slow. No optimization in v1.
- **Worktree name collisions:** if `.worktrees/name` exists, ask user to pick a different name or clean up first.
- **Branch naming drift:** if repo has different conventions (e.g., `feature/ticket-slug` instead of `user/ticket-slug`), document this in repo `.worktree.yml` for v1.1+.

## Examples

### Feature: Create a branch for GH issue #1234

```bash
worktree feature \
  --user "phoang" \
  --ticket "GH-1234" \
  --slug "auth-refresh"
```

Output:
```
✓ Branch: phoang/GH-1234-auth-refresh
✓ Worktree: .worktrees/phoang/GH-1234-auth-refresh
✓ Bootstrap: npm ci ✓
Next: cd .worktrees/phoang/GH-1234-auth-refresh && npm test
```

### Review: Check out PR #999

```bash
worktree review \
  --pr "#999"
```

Output:
```
✓ Ref: pull/999/head
✓ Worktree: .worktrees/review-pr-999
✓ Bootstrap: mvn -q -DskipTests compile ✓
Next: cd .worktrees/review-pr-999 && mvn test
```

### Cleanup stale worktrees

```bash
worktree cleanup --force
```

Output:
```
✓ Pruned 2 stale worktrees:
  .worktrees/ph/old-experiment
  .worktrees/review-pr-888
```

## Future (v1.1+)

- `.worktree.yml` per repo for custom bootstrap, monorepo awareness, branch naming conventions.
- Gradle support for Java.
- `pnpm` / `yarn` / `bun` detection for Node.
- Windows PowerShell support.
- Integration with `gh` CLI for PR auto-checkout.

