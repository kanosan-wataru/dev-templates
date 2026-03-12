---
name: create-pr
description: >
  Skill to handle the full PR lifecycle from creation to review response and merge preparation.
  Invoke with /create-pr (optionally specify the base branch, defaults to main).
  Creates PR with gh command and requests GitHub Copilot review.
  Never include Co-Authored-By or Generated with credit lines in the PR body.
  After Copilot review arrives, address feedback with Claude + Gemini cross-check.
  Use in scenarios such as: PR creation, pull request creation, review request,
  "create a PR", "open a pull request", "submit for review".
---

# create-pr: Pull Request Creation & Review Response Skill

Handles PR creation, Copilot review request, review response, and merge preparation as a unified workflow.

## Critical Rules

- **Never include Co-Authored-By lines**
- **Never include Generated with / via credit lines**
- Never include author names, tool names, or AI names in the PR body

## Arguments

- `<base>` (optional): Target branch for merge. Defaults to `main`.
  - Example: `/create-pr` → PR to main
  - Example: `/create-pr develop` → PR to develop

## Execution Flow

### Step 0: CI Gate + Pre-quality Review (Before PR Creation)

#### 0-a: Local CI Pipeline (Mandatory)

1. Run the full `/ci` skill pipeline (Lint → Type Check → Test → Security → Coverage).
2. **All stages must pass**. If any stage fails, fix and re-run.
3. This step can be skipped only if the user explicitly instructs "skip CI".

#### 0-b: Quality Check with pr-review-toolkit

Run quality checks with pr-review-toolkit agents before PR creation.

1. Check changes with `git diff <base>..HEAD` and determine which reviews to apply:
   - **code-reviewer**: Always run (general quality / CLAUDE.md compliance check)
   - **silent-failure-hunter**: When error handling changes exist (try-catch, catch blocks, etc.)
   - **pr-test-analyzer**: When test files are changed, or changes require tests
   - **type-design-analyzer**: When new type definitions are added/modified (TypeScript, Python type hints, etc.)
   - **comment-analyzer**: When significant documentation/comment changes exist
2. Launch applicable agents **in parallel** (using the Task tool).
3. Consolidate results and report critical issues (Critical / Important) to the user.
4. If critical issues exist:
   - Apply fixes and re-check with the relevant agent after fixing
   - **Maximum 3 re-checks**. If unresolved after 3 fixes, ask the user to handle manually
   - Can be skipped if the user decides to "proceed as-is"
5. Proceed to Step 1 when no issues remain or all are addressed.

### Step 1: PR Creation

1. Check changes and all commits with `git status` / `git log <base>..HEAD`.
2. Analyze changes and generate PR title (max 70 chars) and body in Japanese. Always include **related Issues (`Close #xxx`, etc.)** in the body.
3. Push the branch to remote with `git push -u origin <branch>`.
4. Create the PR with `gh pr create`. Pass the body via HEREDOC.
5. Add self as assignee with `gh pr edit --add-assignee @me`.

### Step 2: Copilot Review Request

1. After PR creation, **request a code review from GitHub Copilot** (using MCP `request_copilot_review`).
2. Wait for further instructions from the user.
3. When the user instructs to handle the review, fetch review comments with `pull_request_read` (method: `get_review_comments`).
4. If no review comments (Approve only, etc.), skip Step 3 and proceed to Step 4.

### Step 3: Review Response

When Copilot returns review comments, **execute the following for each comment**:

1. **Analyze**: Organize the feedback and formulate a fix approach.
2. **Cross-check**: For complex feedback, submit to `Gemini` to validate the fix approach. Skip cross-check for simple feedback (typos, formatting, etc.).
3. **Fix**: Apply code fixes based on the analysis.
4. **Test & Lint**: Run related tests and lint after fixing to confirm pass.
5. **Reply & Resolve**: For each review comment:
   - Post a reply explaining the fix using MCP `add_reply_to_pull_request_comment` (e.g., "Fixed. Changed XX to YY.")
   - Resolve the review thread using `gh api graphql` with GitHub GraphQL `resolveReviewThread` mutation:
     ```bash
     gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<thread_node_id>"}) { thread { isResolved } } }'
     ```
     Obtain the thread `node_id` from the `pull_request_read` (method: `get_review_comments`) response.

### Step 4: Overall Cross-check

After all feedback is addressed:

1. Verify overall consistency of the fixes.
2. Submit the post-fix code diff to `Gemini` and check for side effects or oversights.
3. Integrate Gemini's feedback with own analysis and apply additional fixes if needed.
4. Re-run tests and lint to confirm everything passes.
5. **Code simplification**: Launch the **code-simplifier** agent to polish the fixed code (simplification / readability improvements). Keep changes to minor improvements only — no major refactoring.

### Step 5: Completion Report

1. If no issues from the overall cross-check, commit and push following `/commit` skill rules.
2. Report to the user that **the PR is ready** and prompt for merge.

## Safety Guards

- **Never merge**: Merge is performed by the user
- **Never force push**
- **Never commit directly to the base branch**
