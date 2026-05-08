---
name: test
description: >
  Skill to run tests and lint. Supports the TDD Red/Green/Refactor cycle.
  Invoke with /test (optionally specify targets and options as arguments).
  Auto-detects the project language/framework and runs appropriate commands.
  Runs via Docker if available, otherwise runs locally.
  Use in scenarios such as: running tests, running lint, TDD cycle,
  "run tests", "run lint", "check Red phase".
---

# test: Test & Lint Execution Skill (TDD Support)

Runs tests and lint. Uses Docker if available, otherwise runs locally.

## Arguments

- `<target>` (optional): Specify test targets.
  - Example: `/test` → Run all tests + lint
  - Example: `/test lint` → Run lint only
  - Example: `/test tests/test_auth.py` → Run a specific test file only
  - Example: `/test --coverage` → Run with coverage
  - Example: `/test --red` → TDD Red phase (expect tests to **fail**)
  - Example: `/test --red tests/test_new_feature.py` → Red check for a specific test

## Execution Flow

### Step 1: Determine Execution Environment

1. Check if `Dockerfile` or `docker-compose.yml` exists at the project root.
2. If found, run via Docker.
3. If not found, run locally.

### Step 2: Detect Project Language / Framework

Detect the project language and test commands in the following priority:

| Detection File | Language | Test Command | Lint Command |
|---|---|---|---|
| `pyproject.toml` / `setup.py` | Python | `pytest` | `ruff check .` |
| `package.json` | Node.js/TS | `npm test` | `npm run lint` |
| `Cargo.toml` | Rust | `cargo test` | `cargo clippy` |
| `go.mod` | Go | `go test ./...` | `golangci-lint run` |

- If `package.json` exists, read actual commands from the `scripts` field.
- If `pyproject.toml` exists, check `[tool.pytest]` and `[tool.ruff]` settings.

### Step 3: Run Tests

1. Build the command based on arguments:
   - No arguments → Run both tests + lint sequentially
   - `lint` → Lint only
   - File path → Test specified file only
   - `--coverage` → Add coverage option
   - `--red` → TDD Red phase mode (see below)
2. If Docker environment exists, run with `docker compose run --rm app <command>`; otherwise run locally.
3. Collect execution results.

#### `--red` Mode (TDD Red Phase)

Mode that **expects tests to fail**. Used during the TDD Red phase.

- If tests fail: Report "✅ Red phase confirmed. Tests are failing as intended. Proceed to implementation."
- If tests pass: Warn "⚠️ Tests are passing. Please verify that the tests correctly check the failure condition."

### Step 4: Results Report

Report execution results in the following format:

```
## Test Results

| Item | Result |
|---|---|
| Test | ✅ Pass (12 passed) / ❌ Fail (2 failed) |
| Lint | ✅ No issues / ⚠️ 3 warnings |

### Failed Tests (if any)
- test_auth.py::test_login_invalid - AssertionError: ...
```

- **Normal mode**: If failures exist, provide a summary of causes and suggested fixes. If all pass, suggest committing with `/commit`.
- **`--red` mode**: Report failures as "as expected" and suggest moving to the implementation phase.

## Safety Guards

- Fall back to local execution if Docker daemon is not running
- Test execution timeout is 5 minutes
- Containers are auto-removed with `--rm`
