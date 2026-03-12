# Claude Usage Guidelines

## 1. Core Principles

* **Language**: All responses to the user must be in **Japanese**. Code comments should also be in **Japanese**.
* **Research first**: Always read the target file and related code before making changes. Understand existing conventions and context before editing.
* **Security**: Never read, edit, or commit credential files (`.env`, `credentials.json`, `*.pem`, etc.).
* **Autonomy and confirmation**: Work autonomously as much as possible. Ask the user for confirmation before destructive changes or when requirements are ambiguous.

## 2. Thinking Process (Plan Mode + Gemini Cross-Check)

For complex tasks, do not intuitively modify code. **Use Plan mode to design the approach, and cross-check with Gemini before implementation.**

**When to apply**: Investigating unknown bugs / Multi-file design / Refactoring strategy / Trade-off evaluation

### Procedure

1. **Enter Plan mode**: For non-trivial tasks, enter Plan mode to explore the codebase and design the approach before writing code.
2. **Analysis (Claude)**: Search and read related files. Articulate the system state and issues in the plan.
3. **Cross-check (Gemini)**: Send the plan and analysis to **Gemini MCP** for alternative perspectives, blind spot detection, and validation.
4. **Integrate and finalize**: Compare both analyses, resolve contradictions, and finalize the plan.
5. **Exit Plan mode**: Present the plan for user approval via ExitPlanMode.
6. **Execute and verify**: Implement based on the approved plan. If unexpected errors occur, return to step 1 for re-analysis.

> **NOTE**: This full process is unnecessary for simple fixes (typo corrections, small single-file changes). Scale the effort to task complexity — skip Plan mode for trivial tasks.

## 3. Coding Rules

### 3.1. General Rules (Language-Agnostic)

* **Naming**: Use clear, meaningful names. Follow existing codebase conventions.
* **Separation**: Follow the Single Responsibility Principle. Keep functions and classes appropriately sized.
* **Simplicity**: Avoid over-abstraction. Implement only what is necessary.

### 3.2. Annotation Comments

* `TODO`: Incomplete tasks / planned features
* `NOTE`: Supplementary info / design intent (record the "why")
* `FIXME`: Known bugs / issues requiring fixes
* `XXX`: Needs attention / debatable implementation
* `HACK`: Temporary workaround (always pair with a `TODO` for future fix)

### 3.3. Language-Specific Rules

Follow the standard style guide and conventions for each language:

* **Python**:
  - PEP 8 compliant, type hints, docstrings (Google style)
  - Import order: stdlib > third-party > local (`isort` compliant, separated by blank lines)
  - Logging: Use `logging` module for all output including debug. No `print()` except CLI stdout. Follow the Rule of Silence.
  - Exceptions: Avoid bare `except:` / `except Exception:`. Specify concrete exception classes.
  - Strings: Prefer f-strings over `format()` or `%` formatting.
  - Paths: Prefer `pathlib.Path` over `os.path`.
  - Linter/Formatter: Use `ruff` (`ruff check` + `ruff format`).
* **TypeScript/JavaScript**: Follow ESLint / Prettier config. Actively use type definitions.
* **Rust**: Follow `cargo fmt` / `cargo clippy`.
* **Go**: Follow `gofmt`. Keep `golangci-lint` warnings at zero.

### 3.4. Code Quality

* **Testing**: Run related tests after code changes and verify they pass. Always pass tests before committing.
* **Debug code**: Remove `console.log` / `debugger` / debug `print` statements before committing.
* **Security**: Follow OWASP Top 10. Never skip input validation or escaping.
* **Review mindset**: Focus on readability, edge cases, and performance.

## 4. TDD & Local CI

### 4.1. Test-Driven Development (TDD)

New logic should be implemented **test-first** by default (Red > Green > Refactor).

1. **Red**: Write a failing test (verify with `/test --red`)
2. **Green**: Write minimal code to pass the test (verify with `/test`)
3. **Refactor**: Clean up code while maintaining tests (verify with `/test`)

**Flexibility rule**: Test-after is acceptable for:
- Prototypes / spikes (exploratory implementation)
- UI / layout code
- Config files / infrastructure changes

Specify the test strategy for each TODO during `/start-work` planning (`[TDD]` / `[Test-After]` / `[No-Test]`).

### 4.2. Local CI Pipeline

Run 5 stages via the `/ci` skill. Prefer Docker; fall back to local execution.

| Stage | Check | Tool Examples |
|---|---|---|
| 1. Lint | Code style / static analysis | ruff, eslint, clippy |
| 2. Type Check | Type consistency | mypy, tsc, cargo check |
| 3. Test | Unit / integration tests | pytest, vitest, cargo test |
| 4. Security | Vulnerability scan | bandit, npm audit, cargo audit |
| 5. Coverage | No decrease in test coverage | coverage.py, c8 |

**When to run**:
- `/ci` for on-demand execution (stage selection via args: `/ci lint,test`)
- Automatically runs all stages during `/create-pr` (**mandatory gate**: blocks PR creation on failure)

## 5. Development Workflow (Scrum-Based)

A simplified Scrum framework for solo + AI (Claude + Gemini MCP) development.

### Scrum Mapping

| Scrum Concept | Implementation |
|---|---|
| Product Backlog | GitHub Issues (priority via labels) |
| Sprint Backlog | Issues linked to Sprint via milestones or labels |
| Sprint Planning | Select Issue and create plan with TDD strategy via `/start-work` |
| Sprint Review | `/create-pr` (CI gate + self-review + Copilot review + cross-check) |
| Sprint Retrospective | Record learnings in technical-notes.md at Sprint end |
| Definition of Done | DoD checklist below |

### Definition of Done (DoD)

All items must be satisfied before `/create-pr`:

- [ ] Tests pass (TDD items must have gone through Red > Green > Refactor)
- [ ] Lint and type checks pass
- [ ] Security scan: 0 Critical / High findings
- [ ] Test coverage has not decreased (if decreased for valid reasons like dead code removal, document the reason in the PR description and obtain user approval to skip)
- [ ] Commit messages follow Conventional Commits

### Skill Map

| Phase | Skill | Purpose |
|---|---|---|
| 1. Backlog | `/create-issue` | Create Issue / set priority |
| 2. Sprint Planning | `/start-work` | Create branch / implementation plan with TDD strategy |
| 3. TDD Development | `/test` | Red > Green > Refactor cycle |
| 3. Save | `/commit` | Commit |
| 4. Review | `/create-pr` | CI gate + PR creation (`/ci` pass required) |
| 4. Cleanup | `/git-cleanup` | Delete merged branches |

### Lightweight Path (Small Changes)

Phase 1-2 (Issue / branch creation) can be skipped for:
- Typo fixes, comment corrections, documentation updates
- Clear 1-2 file bug fixes
- When the user explicitly instructs to skip

Additionally, the Phase 4 CI gate can be simplified to `/ci lint` only for:
- Changes that do not affect tests (typos, comments, documentation only)
- Config-only changes

### Git Rules

* `git push --force` is prohibited. Use `--force-with-lease` when necessary.
* Direct commits/pushes to main/master are prohibited.

### Phase 1: Backlog Management

1. Understand the purpose of the request precisely. Ask questions if unclear.
2. Search the codebase to identify the scope of impact and clarify the issue.
3. Create a GitHub Issue using the `/create-issue` skill.

### Phase 2: Sprint Planning & Start Work

1. Create a development branch for the Issue using the `/start-work` skill.
2. Create an implementation plan with test strategy tags (`[TDD]` / `[Test-After]` / `[No-Test]`) for each TODO.
3. For complex issues, verify the plan with a `Gemini` cross-check.
4. Present the plan to the user and **post to Issue comment only after approval**.

### Phase 3: TDD Development Cycle

Repeat for each TODO:

1. **`[TDD]`**: Execute Red > Green > Refactor cycle.
   - `/test --red` to verify failure > implement > `/test` to verify pass > refactor > `/test` to re-verify
2. **`[Test-After]`**: Implement > add tests > `/test` to verify pass.
3. **`[No-Test]`**: Implement > `/test lint` for Lint-only check.
4. Commit using the `/commit` skill (Conventional Commits format).
5. Report progress via Issue comment after each completion.

### Phase 4: Review & Completion

1. After all TODOs are complete, run the `/create-pr` skill (CI gate + self-review run automatically).
2. Ask the user for **final approval (merge)**.
3. After merge, clean up branches using the `/git-cleanup` skill.
4. Record retrospective learnings in technical-notes.md at Sprint end.

## 6. Memory Management

Split details into sub-files. Keep `MEMORY.md` concise as an index.

* **MEMORY.md**: Index of config, skill status, hookify rule status, and known issues
* **technical-notes.md**: Design decision rationale / technical insights > record after confirming important design decisions

## 7. hookify Auto-Guardrails

The following rules are automatically enforced by the hookify plugin. Rule files are in `.claude/hookify.*.local.md`.

| Rule | Action | Trigger | Notes |
|---|---|---|---|
| `block-force-push` | **block** | `git push --force` / `-f` | `--force-with-lease` is allowed |
| `block-sensitive-files` | **block** | Editing `.env` / `credentials.json` / `*.pem` etc. | Enforces security rule from Core Principles |
| `warn-git-add` | warn | `git add .` / `-A` / `--all` | Check for accidental inclusion of secrets / large files |

* Disable: Set `enabled: false` in the relevant rule file
* Create/manage: Use `/hookify` command, `/hookify:list` to view all rules
