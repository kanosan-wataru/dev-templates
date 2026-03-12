---
name: create-issue
description: >
  Skill to analyze a problem and create a GitHub Issue.
  Invoke with /create-issue (optionally specify a description as argument).
  Auto-generates a structured Issue based on codebase investigation.
  Use in scenarios such as: issue creation, bug reports, task registration,
  "create an issue", "file a bug", "register a task".
---

# create-issue: GitHub Issue Creation Skill

Analyzes a problem and creates a structured GitHub Issue.

## Arguments

- `<description>` (optional): Summary or description of the problem.
  - Example: `/create-issue` → Generate Issue from conversation context
  - Example: `/create-issue login screen shows error` → Generate based on the specified content

## Execution Flow

### Step 1: Repository Identification

1. Identify the remote repository owner/repo with `git remote -v`.
2. Ask the user if the repository cannot be identified.

### Step 2: Problem Analysis

1. Understand the problem from arguments or conversation context.
2. Use Grep/Glob to investigate related code and identify the impact scope as needed.
3. Determine the issue type (bug / feature / refactor / docs, etc.).

### Step 3: Issue Creation

1. Create the Issue in the following format:
   - **Title**: Concise and specific (Japanese, max 50 characters)
   - **Body**: Follow the template below
   - **Labels**: Set based on issue type (bug, enhancement, refactoring, etc.)
2. Create the Issue using GitHub MCP `issue_write`.

### Step 4: Report

1. Report the created Issue number and URL to the user.
2. Suggest the next step (`/start-work` to create a branch).

## Issue Body Template

```markdown
## Overview

(Brief description of the problem)

## Background / Current State

(Why this problem occurred, the current situation)

## Expected Behavior / Goal

(What should happen after the fix)

## Impact Scope

(Related files / modules)

## Proposed Solution

(Describe if known, otherwise "Needs investigation")
```

## Safety Guards

- Present the title and body to the user and get confirmation before creating the Issue
- Pre-check for duplicate Issues using search_issues
