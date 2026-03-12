---
name: ci
description: >
  Skill to run the local CI pipeline in one go.
  Invoke with /ci (optionally specify stages as arguments).
  Executes 5 stages sequentially — Lint → Type Check → Test → Security Scan → Coverage —
  and reports results. Functions as a mandatory gate (prerequisite) for /create-pr.
  Use in scenarios such as: CI execution, pipeline run, quality check,
  "run CI", "run the pipeline", "check before PR".
---

# ci: Local CI Pipeline Skill

Runs 5-stage checks in a single pass to verify code quality.

## Arguments

- `<stages>` (optional): Comma-separated list of stages to run. Runs all stages when omitted.
  - Example: `/ci` → Run all stages
  - Example: `/ci lint,test` → Run Lint and Test only
  - Example: `/ci security` → Run Security Scan only

## CI Stage Definitions

| # | Stage | Check |
|---|---|---|
| 1 | lint | Code style / static analysis |
| 2 | typecheck | Type consistency check |
| 3 | test | Unit tests / integration tests |
| 4 | security | Vulnerability scan |
| 5 | coverage | Verify test coverage has not decreased |

## Execution Flow

### Step 1: Project Detection

1. Detect language/framework from config files at the project root.
2. Determine commands for each stage:

| Language | lint | typecheck | test | security | coverage |
|---|---|---|---|---|---|
| Python | `ruff check .` | `mypy .` | `pytest` | `bandit -r .` | `pytest --cov` |
| Node.js/TS | `npm run lint` | `npx tsc --noEmit` | `npm test` | `npm audit` | `npx c8 npm test` |
| Rust | `cargo clippy` | `cargo check` | `cargo test` | `cargo audit` | `cargo tarpaulin` |
| Go | `golangci-lint run` | `go vet ./...` | `go test ./...` | `govulncheck ./...` | `go test -cover ./...` |

- Prefer `scripts` in `package.json` or settings in `pyproject.toml` when available.
- Skip stages when tools are not installed and report as a warning.
- **Coverage evaluation**:
  - Retrieve previous value: Read the `.coverage-baseline` file at the project root (numeric only, e.g., `85.3`).
  - Compare: Pass if current coverage ≥ previous value. Report as failure if it has decreased.
  - Exception: If there is a legitimate reason (dead code removal, large-scale refactoring, etc.), treat as pass when the user explicitly approves.
  - Update: Overwrite `.coverage-baseline` with the current value on pass.
  - Unknown previous value (file does not exist): Report coverage rate only and treat as pass. Save the initial value to `.coverage-baseline`.

### Step 2: Determine Execution Environment

1. If `Dockerfile` or `docker-compose.yml` exists, run via Docker.
2. If no Docker environment, run locally.

### Step 3: Sequential Stage Execution

Execute the specified (or all) stages in order:

1. Report the start of each stage to the user.
2. Run the command and collect results.
3. **Proceed to the next stage even if a stage fails** (to capture the full picture).
4. Timeout per stage is 5 minutes.

### Step 4: Results Report

After all stages complete, report in the following format:

```markdown
## CI Pipeline Results

| Stage | Result | Details |
|---|---|---|
| Lint | ✅ Pass / ❌ Fail | (count / summary) |
| Type Check | ✅ Pass / ❌ Fail / ⏭️ Skipped | (error summary) |
| Test | ✅ 12 passed / ❌ 2 failed | (failed test names) |
| Security | ✅ No issues / ⚠️ 3 issues | (Critical/High count) |
| Coverage | ✅ 85% (+2% vs previous) / ❌ 72% (-3% vs previous) | (diff from previous) |

### Overall: ✅ Pass / ❌ Fail (N stages)
```

- **All pass**: Suggest "You can create a PR with `/create-pr`".
- **Failures exist**: Provide a summary of causes and suggested fixes for each failed stage.

## Safety Guards

- Fall back to local execution if Docker daemon is not running
- Timeout per stage is 5 minutes (configurable via argument: `/ci --timeout 10`)
- Mask results if security scan output contains sensitive information
