---
name: verification-loop
description: >
  Skill to run a comprehensive verification loop after completing features or before PR creation.
  Invoke with /verify (optionally specify --quick for abbreviated checks).
  Executes 6 phases — Build -> Types -> Lint -> Test -> Security -> Diff Review —
  and reports PR readiness.
  Use in scenarios such as: verifying changes, pre-PR check, post-refactoring validation,
  "verify my changes", "am I ready for PR", "run full check".
---

# verification-loop: Comprehensive Verification Loop Skill

Verifies change quality through 6 phases and determines PR readiness.

## Arguments

- None: Auto-detects changes on the current branch and runs all 6 phases.
- `--quick`: Runs Build + Test + Lint only (skips Types, Security, and Diff Review).

## Execution Flow

### Phase 1: Build Verification

1. Detect the project language using the same logic as `/ci` (config files at project root).
2. Run the build command.
3. On failure: **STOP** and report the error with suggested fixes. Do not proceed to subsequent phases.

### Phase 2: Type Check

1. Run the type checker (`tsc --noEmit`, `mypy .`, `go vet ./...`, `cargo check`, etc.).
2. Report type errors with file:line references.
3. Critical errors (unresolved types, missing modules) are flagged for immediate fix.

### Phase 3: Lint Check

1. Run the linter (`ruff check .`, `eslint .`, `cargo clippy`, `golangci-lint run`, etc.).
2. Report warning count and auto-fixable items separately.
3. Suggest `--fix` command if auto-fixable issues exist.

### Phase 4: Test Suite

1. Run tests with coverage (`pytest --cov`, `npx c8 npm test`, `go test -cover ./...`, etc.).
2. Report: total tests, pass/fail count, coverage percentage.
3. Compare coverage against `.coverage-baseline` at the project root:
   - If current < baseline: warn with the delta.
   - If baseline does not exist: report coverage only (treat as pass).

### Phase 5: Security Scan

1. Search for hardcoded secrets using pattern matching:
   - API keys, passwords, tokens, private keys in source files.
   - Patterns: `password\s*=`, `api_key\s*=`, `secret\s*=`, `-----BEGIN.*PRIVATE KEY-----`
2. Detect residual debug code:
   - `console.log`, `print()` (outside test files), `debugger`, `binding.pry`
3. Run dependency vulnerability scanner:
   - `npm audit` / `bandit -r .` / `govulncheck ./...` / `cargo audit`
4. Skip tools that are not installed and report as warning.

### Phase 6: Diff Review

1. Collect changes with `git diff --stat` and `git diff HEAD~1` (or `git diff main...HEAD` for multi-commit branches).
2. Review each changed file for:
   - Unintended changes (whitespace-only, unrelated files)
   - Missing error handling (bare `try/except`, unchecked errors)
   - Edge case considerations (null, empty, boundary values)
   - Unused imports / dead code
   - Residual debug code (console.log, TODO/FIXME)
   - Inconsistent naming conventions
3. Report issues with file:line references.

### Results Report

After all phases complete, report in the following format:

```markdown
## Verification Results

| Phase | Result | Details |
|---|---|---|
| Build | PASS / FAIL | (error summary) |
| Types | PASS / FAIL | (N errors) |
| Lint | PASS / FAIL | (N warnings, M auto-fixable) |
| Tests | PASS / FAIL | (N/M passed, X% coverage) |
| Security | PASS / WARN | (N issues found) |
| Diff Review | PASS / WARN | (N files, M issues found) |

### Overall: READY / NOT READY for PR
```

- **All pass**: Suggest "You can create a PR with `/create-pr`."
- **Failures exist**: Provide a prioritized list of fixes (Critical > High > Medium > Low).

## Relationship to /ci

`/verify` is a superset of `/ci` focused on PR readiness:
- `/ci` runs pipeline stages and reports pass/fail (mandatory gate for `/create-pr`).
- `/verify` adds Diff Review with contextual analysis and provides actionable fix suggestions.
- Use `/verify` for thorough pre-PR validation; use `/ci` for quick pipeline checks.

## Safety Guards

- Timeout: 5 minutes per phase
- Build failure blocks all subsequent phases
- Failed test details are capped at 20 entries
- Security scan output is masked if it contains sensitive information
