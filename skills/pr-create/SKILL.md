---
name: pr-create
description: |
  Create a new pull request in a GitHub repository.
version: 1.1.0
triggers:
  - create pr
  - create pull request
  - open pr
  - new pr
  - submit pr
---

# Create Pull Request

## Prerequisite (`gh` required)

```bash
command -v gh >/dev/null && gh --version
```

If `gh` is missing, ask before installing.
- If user confirms: install it, then run `gh auth login`.
- If user declines: do not install; only show commands.

```bash
# macOS
brew install gh
# Debian/Ubuntu
sudo apt update && sudo apt install gh
# Windows
winget install --id GitHub.cli
gh auth login
```

## Procedure

0) **Check for uncommitted changes and squash commits (optional)**.
- Check for uncommitted changes in the current branch:
  ```bash
  git status --short
  ```
- If uncommitted changes exist, warn the user: "Uncommitted changes detected. Stash or commit them before squashing to avoid including them in the squashed commit."
- Ask if the user wants to squash commits in the branch before creating the PR.
- If yes, use `git rebase -i` or rely on the `squash-branch-commits` skill to squash all commits since the branch diverged from base.
- If squashing rewrites history, ask for explicit confirmation before any `git push --force-with-lease`; if declined or unclear, do not push and only show the command.
- After squashing (and any confirmed push), verify the user is ready to proceed.

1) **Gather PR details from the user**.
- Current repository (auto-detected or provided).
- Base branch (default: repository's default branch, usually `main`, `master`, or `develop`).
- Head branch (current branch or specified branch).
- Title (required; if not provided, ask for it).
- Body/description:
  - Check if `.github/PULL_REQUEST_TEMPLATE.md` exists in the repository.
  - If it exists, use it as the default body and ask the user if they want to modify it.
  - If it does not exist, ask the user for the body (optional).
- Draft status (optional; default: false).
- Assignee: always set to the PR creator (`@me`).
- Assign reviewers (optional).
- Assign labels (optional).

2) **Show user a summary before creating**.
- Display repo, base, head, title, body, draft status, assignee (`@me`), reviewers, and labels.
- Ask for confirmation: `Create PR with the above details? [y/N]`
- If the response is unclear or empty, ask one clarification; if still unclear, treat as `N` (do not create).
- If user declines, do not create anything.

3) **Create the PR using `gh`**.

```bash
gh pr create \
  --base BASE_BRANCH \
  --head HEAD_BRANCH \
  --title "PR Title" \
  --body "PR description" \
  --assignee "@me"
# Optional flags (include only if user selected them):
# --draft \
# --reviewer reviewer1,reviewer2 \
# --label label1,label2
```

4) **Show the result**.
- Display PR number, URL, and status.
- Provide the link for the user to view/edit the PR.

## Safety Rules

- Never create a PR without user confirmation.
- If base and head are the same, ask for clarification before proceeding.
- Do not create a PR if the user has not authenticated with `gh auth login`.

## Pitfalls

- **`gh pr edit --body` uses GraphQL and fails silently**: Do not use `gh pr edit --body` to update PR body after creation. It may fail silently without reporting errors. Instead, use the GitHub REST API:

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER -X PATCH -f body="new body text"
```

Or use `gh pr edit` without `--body` and rely on interactive prompts, or edit the PR directly via GitHub's web UI.

