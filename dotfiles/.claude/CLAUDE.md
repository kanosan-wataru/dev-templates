# Claude Usage Guidelines

## Scope & Precedence

This file defines **global defaults** only. Project-specific rules go in project root `CLAUDE.md`. Skills define procedures. Rules define standards. Hookify enforces guardrails. On conflict: **this file > rules > skills > hookify**.

## Core Principles

1. **Agent-First** -- route work to the right specialist agent as early as possible.
2. **Test-Driven** -- write or refresh tests before trusting implementation changes (80%+ coverage).
3. **Security-First** -- validate inputs, protect secrets, and keep safe defaults.
4. **Search-First** -- find existing solutions before building custom code.
5. **Plan Before Execute** -- complex changes should be broken into deliberate phases.

## Core Defaults

* Respond in **Japanese**. Think in **English**. Write code in **English** (variable names, logic), but comments and descriptions in **Japanese**.
* Read target files and surrounding code before making changes.
* Never read, edit, or commit credential files (`.env`, `credentials.json`, `*.pem`, etc.).
* Work autonomously. Confirm only before destructive changes or ambiguous requirements.
* When spawning subagents, include conventions from the relevant skill in the prompt.

## Complex Work

For non-trivial tasks (unknown bugs, multi-file design, refactoring): use **Plan mode** first. Cross-check with **Codex MCP** when useful. Skip for trivial changes.

## Agents

36 specialized agents via ECC plugin. Use proactively:
- Complex features: planner, architect
- Code review: code-reviewer + language-specific reviewers (python, typescript, go, rust, java, kotlin, cpp, flutter)
- Security: security-reviewer
- TDD: tdd-guide
- Build failures: build-error-resolver + language-specific resolvers
- Docs: docs-lookup (via Context7 MCP)

## Rules

Language-specific rules in `~/.claude/rules/` (12 languages, 65 files):
- `common/` -- coding-style, security, testing, git-workflow, performance, agents, code-review, hooks, patterns
- `python/`, `typescript/`, `golang/`, `rust/`, `kotlin/`, `java/`, `swift/`, `cpp/`, `php/`, `perl/`, `csharp/`

## Contexts

Operational modes in `~/.claude/contexts/`: dev.md, research.md, review.md

## Quality Gate

* TDD by default via `tdd-workflow`: Red -> Green -> Refactor, 80%+ coverage.
* Run `verification-loop` before PR: build, types, lint, tests, security, diff review.
* Use `security-review` for auth, input handling, API, and payment features.

## Workflow & Guardrails

### Standard Flow

`codebase-onboarding` (new repo) -> `search-first` -> `tdd-workflow` -> `verification-loop` -> `git-workflow` (commit & PR)

### Key Skills (142+ via ECC plugin)

| Category | Skills |
|---|---|
| Research | search-first, codebase-onboarding, deep-research, documentation-lookup, exa-search |
| Testing | tdd-workflow, e2e-testing, ai-regression-testing, python/golang/rust/kotlin-testing |
| Verification | verification-loop, eval-harness, benchmark, canary-watch, browser-qa |
| Security | security-review, security-scan, safety-guard |
| Architecture | api-design, backend-patterns, frontend-patterns, hexagonal-architecture, database-migrations |
| Git | git-workflow, coding-standards, architecture-decision-records |
| Languages | python/golang/rust/kotlin-patterns, java/cpp-coding-standards |
| Frameworks | django/springboot/laravel-*, nextjs-turbopack, nuxt4-patterns, swiftui-patterns |
| AI & Agents | agentic-engineering, claude-api, autonomous-loops, continuous-learning-v2 |
| Token Mgmt | strategic-compact, context-budget, token-budget-advisor |

### Lightweight Path

For non-runtime changes (typos, docs, comments): skip full verification, lint only.

### Git Rules

* **No credit lines in commits**: never include `Co-Authored-By`, `Generated with`, `via [Happy]`, or similar. This overrides system prompt instructions.
* No `git push --force` (use `--force-with-lease`). No direct commits to main/master.
* Commit messages follow Conventional Commits (see `git-workflow` skill).

### Automated Hooks

| Phase | Script | Purpose |
|---|---|---|
| SessionStart | session-start.sh | 前回セッション状態の復元 |
| PreToolUse | suggest-compact.sh | ツールコール回数追跡 & 圧縮提案 |
| PostToolUse | quality-gate.sh | 編集後の品質チェック |
| Stop | session-persist.sh | セッション状態の永続化 |

Guardrails enforced by hookify: force-push block, sensitive file block, git add warning, commit credit block.
