# Copilot Instructions — copilot-skills

## Project Purpose

A collection of reusable AI agent skills written as Markdown files.
Each skill is a standalone instruction set consumed by AI agents (GitHub Copilot, Claude, etc.).

## Structure

```
skills/
  <skill-name>/
    SKILL.md   ← the skill definition (frontmatter + instructions)
```

## Skill File Conventions

- Every `SKILL.md` begins with YAML frontmatter: `name`, `description`, `version` (semver), and `triggers`.
- Sections use `##` headings; numbered steps use `0)`, `1)`, `2)` etc.
- Keep skills **concise** — long skills degrade agent effectiveness. Prefer terse bullet points over prose.
- Optional prompts **must** use a select box and always include a **"None — skip"** option.
- Required prompts show an auto-generated value for the user to confirm or edit.
- Shell commands are shown in fenced ```bash blocks.

## Versioning Rules

- Patch bump (`x.y.Z`): wording fixes, clarifications that don't change behaviour.
- Minor bump (`x.Y.0`): new behaviour, new rules, or new steps.
- Major bump (`X.0.0`): breaking restructure or incompatible change to the skill's interface.
- **Never skip versions** — increment one step at a time.

## Boundaries

- Do not add prose explanations that duplicate what a bullet already says.
- Do not grow a skill beyond what is necessary to drive correct agent behaviour.
- Do not store secrets, tokens, or credentials anywhere in this repo.
- Always verify a version bump makes sense before committing.

