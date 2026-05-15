---
name: commit
description: >
  Skill to analyze git changes and generate an appropriate commit message.
  Invoke with /commit (optionally specify a hint as argument).
  Generates messages in Conventional Commits format (feat:/fix:/refactor: etc.) with a Japanese body.
  Never include Co-Authored-By or Generated with credit lines.
  Use in scenarios such as: committing changes, creating commit messages,
  "commit this", "make a commit", "create a commit message".
---

# commit: Commit Message Generation & Execution Skill

Analyzes changes and generates a Conventional Commits format commit message.

## Critical Rules

- **Never include Co-Authored-By lines**
- **Never include Generated with / via credit lines**
- Never include author names, tool names, or AI names in commit messages

## Arguments

- `<hint>` (optional): Hint or supplementary information for the commit message.
  - Example: `/commit` → Auto-generate from changes
  - Example: `/commit fix login feature` → Generate considering the hint

## Format

Refer to `references/format-guide.md`. Format: `<type>: <Japanese description>` (70 characters max).

## Execution Flow

1. Check changes with `git status` / `git diff --cached` / `git diff`.
2. Review commit targets and stage with `git add` as needed.
3. **Pre-commit quality check (only when explicitly requested)** — Execute only when the user includes "review" in the arguments:
   - Run **code-reviewer** agent for quality/bug checks (report only issues with confidence ≥ 80)
   - If critical issues are found, report to the user and ask whether to fix or commit as-is
   - If fixes are made, re-fetch the diff before proceeding to step 4
   - Skip this step if no review is specified in arguments
4. Analyze the type and scope of changes, then generate a commit message.
5. Present the message to the user and execute the commit using HEREDOC format.
6. Report the result with `git log --oneline -1`.

## Safety Guards

- **Sensitive file detection**: Warn if `.env`, `credentials`, `secret`, `*.pem`, `*.key`, etc. are included
- **Large changeset confirmation**: Confirm with the user if 10+ files are changed
- **Empty commit prevention**: Do not commit if no changes are staged
