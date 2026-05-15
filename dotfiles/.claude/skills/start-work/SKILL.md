---
name: start-work
description: >
  Skill to create a development branch from an Issue number and start work.
  Invoke with /start-work (specify Issue number as argument).
  Auto-generates a branch name from the Issue title and checks it out.
  Use in scenarios such as: starting work, creating a branch, beginning development,
  "start working", "create a branch", "work on Issue 123".
---

# start-work: Work Initiation Skill

Auto-generates a branch name from an Issue number and starts development work.

## Arguments

- `<issue_number>` (required): GitHub Issue number.
  - Example: `/start-work 123`
  - Example: `/start-work #45`

## Execution Flow

### Step 1: Fetch Issue Information

1. Identify the remote repository owner/repo with `git remote -v`.
2. Fetch the Issue title and labels using GitHub MCP `issue_read`.
3. If the Issue does not exist or is closed, confirm with the user.

### Step 2: Generate Branch Name

Auto-generate a branch name from the Issue's labels and content:

- **bug label**: `fix/<issue-number>-<title-summary>`
- **enhancement label**: `feature/<issue-number>-<title-summary>`
- **refactoring label**: `refactor/<issue-number>-<title-summary>`
- **other / no label**: `feature/<issue-number>-<title-summary>`

Title summary rules:
- Do not transliterate Japanese to romaji; extract English keywords instead
- Convert English titles directly to kebab-case
- Maximum 30 characters

### Step 3: Create Branch

1. Fetch the latest with `git fetch origin`.
2. Create the branch with `git checkout -b <branch-name> origin/main`.
3. Report the created branch name to the user.

### Step 4: Check Docker Environment

1. Check if `Dockerfile` or `docker-compose.yml` exists at the project root.
2. If not found: Ask the user "Docker environment is not set up. Would you like to create a Dockerfile first?"
3. If found: Report "Docker environment is available."

### Step 5: Create Implementation Plan (Including TDD Strategy)

Analyze the Issue content and codebase to create an implementation plan with TDD strategy:

1. Organize requirements from the Issue body and comments.
2. Use Grep / Glob to investigate related code and identify the impact scope.
3. For complex issues, cross-check with `Gemini`.
4. Assign a **test strategy** to each TODO:
   - `[TDD]`: Test-first (Red → Green → Refactor). For logic, APIs, data processing, etc.
   - `[Test-After]`: Add tests after implementation. For prototypes, UI, exploratory implementation.
   - `[No-Test]`: Not a test target. For config changes, documentation, refactoring (covered by existing tests).
5. Create a TODO list in the following format:

```markdown
## Implementation Plan

**Branch**: `<branch-name>`

### Impact Scope
- (List of related files / modules)

### TODO
- [ ] 1. (Specific task) `[TDD]`
- [ ] 2. (Specific task) `[Test-After]`
- [ ] 3. (Specific task) `[No-Test]`
- [ ] ...

### Concerns / Risks
- (List if any, otherwise "None")
```

6. Present the plan to the user and **post it as an Issue comment only after receiving approval**.

### Step 6: Work Start Report

1. Report work start to the user and suggest beginning with the first TODO.

## Safety Guards

- Warn if there are uncommitted changes and ask whether to stash
- Confirm if branching from a branch other than main / master
- Present the branch name to the user and get confirmation before creating
