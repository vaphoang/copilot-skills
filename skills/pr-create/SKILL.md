---
name: pr-create
description: |
  Create a new pull request in a GitHub repository.
version: 1.10.0
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
- **Required prompts**: show the auto-generated or detected value and ask the user to confirm, edit, or replace it (except PR title, which is auto-generated and used directly).
- **Low-interaction flow (mandatory)**: do not ask for a final pre-create confirmation; create the PR immediately after required inputs are resolved.
- **Generated text style (mandatory)**: keep all AI-generated text concise and easy to scan.
  - Prefer short bullets over paragraphs.
  - Use markdown tables when they make structured content easier to scan.
  - Best-fit for tables: metadata, before/after, status, decisions, and checklist-like fields.
  - Keep tables compact (short cells, <=6 rows when possible); if content is narrative, use bullets instead.
  - Keep each bullet to one idea and one line when possible.
  - Avoid filler, repetition, and generic phrasing.
  - Use plain language with concrete facts (what changed, why, impact).
  - For section content, target 2-5 bullets unless the template requires otherwise.
  - For long templates, include only high-signal details and use `TODO` for missing confirmed info.

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
- Title: auto-generate a succinct title (<=72 chars, imperative mood, no trailing period) from the branch name, commit messages, and changed files; do not prompt for confirmation before creating the PR. The user can edit the title later.
- Body/description:
  - In every session, check whether a PR template exists (for example: `.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/*.md`, or `docs/PULL_REQUEST_TEMPLATE.md`).
  - If a template exists, follow the **copy-then-edit** workflow below. **Never write the body from scratch or memory.**
  - If no template exists, ask the user for the body (optional).

  **Copy-then-edit workflow (MANDATORY when a template exists):**

  You **must** use `skills/pr-create/pr-body-fill.sh` to produce the body. Hand-writing the body is not permitted because it cannot guarantee checkbox preservation.

  0. **Read the template and extract its instructions** before writing anything.
     ```bash
     cat <PATH_TO_TEMPLATE>
     ```
     For every section, identify:
     - **HTML comments** (`<!-- ... -->`): these are authoring instructions — follow them literally when deciding what to write. Examples:
       - `<!-- Describe what changed and why -->` → write a why-focused description.
       - `<!-- Link to the Jira/GitHub issue -->` → include a link if one is known.
       - `<!-- Add screenshots for UI changes -->` → include screenshots or note "N/A — no UI changes".
       - `<!-- Delete this section if not applicable -->` → set `"omit": true` for that section if it genuinely does not apply.
     - **Placeholder text** (e.g., `[Your description here]`, `_Describe…_`) → replace with real content.
     - **Conditional instructions** (e.g., "Fill in only one of the following") → honour them when picking checkbox ticks.
     HTML comments are instructions for the author; pass `--strip-comments` so they are removed from the reviewer-facing output.

  1. **Build a config JSON** at `/tmp/pr-body-config.json` with the sections you want filled and the checkbox labels you want ticked:
     ```json
     {
       "sections": [
         { "heading": "## Summary", "content": "Free-form markdown body." },
         { "heading": "## Screenshots", "omit": true }
       ],
       "checks": ["Feature", "Tests added"]
     }
     ```
     - `heading` must match the template heading line exactly (including `##` level).
        - `content` is the replacement body for the section (honours the instructions found in step 0) and must follow the concise style rules above.
     - `"omit": true` removes the entire section and its heading when the template says "delete if not applicable".
     - `checks` are case-insensitive substrings matched against checkbox labels; only tick items clearly appropriate from confirmed context.
     - For sections that cannot be inferred confidently, set `content` to `"TODO"` and ask focused follow-up questions.

  2. **Run the script** — it copies the template, follows section instructions, ticks checkboxes, strips HTML comments, and aborts if any checkbox would be lost:
     ```bash
     skills/pr-create/pr-body-fill.sh \
       --template <PATH_TO_TEMPLATE> \
       --config   /tmp/pr-body-config.json \
       --output   /tmp/pr-body.md \
       --strip-comments
     ```
     If the script exits non-zero, **stop and fix the config** — do not fall back to hand-writing the body.

  3. **Show the verification proof** to the user before proceeding. Paste the script's stdout (which reports preserved/ticked counts) into the summary in step 2.

  4. **Run an external diff check** as a second guard. The output must be empty:
     ```bash
     diff \
       <(grep -c '^[[:space:]]*[-*][[:space:]]*\[' <TEMPLATE>) \
       <(grep -c '^[[:space:]]*[-*][[:space:]]*\[' /tmp/pr-body.md)
     ```
     If the diff is non-empty, halt — do not run `gh pr create`.

  **Checkbox rules (enforced by the script, repeated here for clarity):**
  - All checkbox lines from the template are preserved verbatim.
  - Only checkboxes whose label matches a `checks` substring are ticked.
  - For mutually exclusive checkbox groups, list exactly one matching substring in `checks`.

  Example (mutually exclusive PR type):
  - Template: `- [ ] Bug fix` `- [ ] Feature` `- [ ] Chore`
  - Config:   `"checks": ["Feature"]`
  - Output:   `- [ ] Bug fix` `- [x] Feature` `- [ ] Chore`
- Assignee: always set to the PR creator (`@me`).
- Draft status: always create the PR as draft; do not prompt the user.
- Assign reviewers: do not prompt the user and do not pass `--reviewer`; reviewers are assigned automatically.
- Assign labels (optional): use a select box populated with available repo labels if detectable; always include **"None — no labels"** as an option; if selected or no input, omit `--label`.

2) **Show user a summary and create**.
- Display repo, base, head, title, body, draft status, assignee (`@me`), and labels in a compact, skimmable format.
- Prefer a small markdown table for PR metadata (repo/base/head/title/draft/assignee/labels) when it improves readability.
- Keep the pre-create summary short: prefer bullets/checklist and avoid repeating full body text when not needed.
- If a template was used, show what was auto-filled and what still needs user input.
- Do not ask `Create PR with the above details? [y/N]`; proceed directly to creation.

3) **Create the PR using `gh`**.

```bash
gh pr create \
  --base BASE_BRANCH \
  --head HEAD_BRANCH \
  --title "PR Title" \
  --body-file PR_BODY_FILE \
  --assignee "@me" \
  --draft
# Optional flags (include only if user selected them):
# --label label1,label2
```

- Use `--body-file` when the body comes from a template or contains multiline markdown.

4) **Show the result**.
- Display PR number, URL, and status.
- Provide the link for the user to view/edit the PR.

## Safety Rules

- If base and head are the same, ask for clarification before proceeding.
- Do not create a PR if the user has not authenticated with `gh auth login`.

## Pitfalls

- **`gh pr edit --body` uses GraphQL and fails silently**: Do not use `gh pr edit --body` to update PR body after creation. It may fail silently without reporting errors. Instead, use the GitHub REST API:

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER -X PATCH -f body="new body text"
```

Or use `gh pr edit` without `--body` and rely on interactive prompts, or edit the PR directly via GitHub's web UI.

