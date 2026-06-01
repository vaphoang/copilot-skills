---
name: pr-create
description: |
  Create a new pull request in a GitHub repository.
version: 1.3.0
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

## Interaction Rules

- **Optional prompts**: whenever a field is optional (user may skip it), present it as a select box using `ask_questions` with predefined options. Always include **"None — skip this"** as the first or last option. Never rely on the user leaving a field blank to signal "skip".
- **Required prompts**: show the auto-generated or detected value and ask the user to confirm, edit, or replace it.

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
- Title (required): auto-generate a succinct title (≤72 chars, imperative mood, no trailing period) from the branch name, commit messages, and changed files; present it to the user for confirmation or edit before proceeding.
- Body/description:
  - In every session, check whether a PR template exists (for example: `.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/*.md`, or `docs/PULL_REQUEST_TEMPLATE.md`).
  - If a template exists, read it and keep its structure (headings/checklists) intact.
  - If the template contains checkbox items, preserve all checkbox lines exactly (do not remove or rewrite them).
  - Tick only the checkbox(es) that are clearly appropriate from confirmed context; leave all others unchecked.
  - For mutually exclusive checkbox groups (for example, PR type), ensure exactly one appropriate option is checked and the remaining options stay unchecked.
  - Keep checkbox edits minimal and local (flip `[ ]` to `[x]` only where needed) to avoid unnecessary body rewrites.
  - Try to pre-fill each template section from available session context (user prompt, branch name, commit history, and changed files).
  - For sections that cannot be inferred confidently, leave a clear placeholder (for example: `TODO`) and ask focused follow-up questions.
  - If no template exists, ask the user for the body (optional).

  Example (mutually exclusive PR type):
  - Before: `- [ ] Bug fix` `- [ ] Feature` `- [ ] Chore`
  - After:  `- [ ] Bug fix` `- [x] Feature` `- [ ] Chore`
- Draft status (optional): use a select box — options: `Yes (draft)` | `No (ready for review)` | `None — skip (default: No)`.
- Assignee: always set to the PR creator (`@me`).
- Assign reviewers (optional): use a select box populated with suggested reviewers (from git history or CODEOWNERS if available); always include **"None — no reviewers"** as an option; if selected or no input, omit `--reviewer`.
- Assign labels (optional): use a select box populated with available repo labels if detectable; always include **"None — no labels"** as an option; if selected or no input, omit `--label`.

2) **Show user a summary before creating**.
- Display repo, base, head, title, body, draft status, assignee (`@me`), reviewers, and labels.
- If a template was used, show what was auto-filled and what still needs user input.
- Ask for confirmation: `Create PR with the above details? [y/N]`
- If the response is unclear or empty, ask one clarification; if still unclear, treat as `N` (do not create).
- If user declines, do not create anything.

3) **Create the PR using `gh`**.

```bash
gh pr create \
  --base BASE_BRANCH \
  --head HEAD_BRANCH \
  --title "PR Title" \
  --body-file PR_BODY_FILE \
  --assignee "@me"
# Optional flags (include only if user selected them):
# --draft \
# --reviewer reviewer1,reviewer2 \
# --label label1,label2
```

- Use `--body-file` when the body comes from a template or contains multiline markdown.

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

