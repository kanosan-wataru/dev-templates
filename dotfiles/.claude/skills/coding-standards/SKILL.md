---
name: coding-standards
description: >
  Skill to provide universal coding standards and language-specific best practices.
  Invoke with /coding-standards (optionally specify a language or topic).
  References core principles, naming conventions, function design, and code smell detection.
  Use in scenarios such as: code review, new implementation, refactoring,
  "check standards", "naming convention", "code smell check".
---

# coding-standards: Universal Coding Standards Skill

Cross-language code quality principles and language-specific best practices.

## Arguments

- None: Show all standards summary.
- `<language>`: Show language-specific standards (e.g., `/coding-standards python`).
- `<topic>`: Show topic-specific standards (e.g., `/coding-standards naming`, `/coding-standards errors`).

## Core Principles

1. **Readability**: Code is read far more often than written. Prioritize clarity over cleverness.
2. **KISS**: Choose the simplest solution that works.
3. **DRY**: Consider abstraction after 3+ duplications (avoid premature abstraction).
4. **YAGNI**: Do not build features that are not needed now.
5. **Single Responsibility**: Each function, class, and module has exactly one responsibility.

## Universal Standards

### Naming

- Variables/Functions: verb+noun or meaningful noun (`getUserById`, `totalPrice`)
- Booleans: is/has/can/should prefix (`isActive`, `hasPermission`)
- Constants: UPPER_SNAKE_CASE
- No abbreviations (except established conventions: `i`, `j`, `ctx`, `req`, `res`, `err`)
- Collections use plural names (`users`, `orderItems`)
- Callbacks/handlers use on/handle prefix (`onClick`, `handleSubmit`)

### Functions

- 50 lines or fewer (consider splitting if exceeded)
- 3 parameters or fewer (use an object/struct if exceeded)
- Minimize side effects; prefer pure functions
- Use early return to keep nesting shallow (max 3 levels)
- One level of abstraction per function

### Error Handling

- Never swallow errors silently
- Separate user-facing messages from developer logs
- Distinguish recoverable errors from critical errors
- Define error boundaries clearly
- Use typed/structured errors where possible (custom error classes, error codes)

### Files

- 800 lines or fewer
- Organize by feature/domain (not by type)
- High cohesion, low coupling
- One module = one public API surface

### Comments

- Explain "why", not "what" (the code explains "what")
- Delete commented-out code (use version control instead)
- Keep TODO/FIXME comments linked to Issue numbers
- Write doc comments for all public APIs

## Code Smell Detection

When reviewing code, detect and report the following:

| Smell | Threshold | Action |
|---|---|---|
| Long function | > 50 lines | Split into smaller functions |
| Deep nesting | > 4 levels | Use early return, extract methods |
| Magic numbers/strings | Any literal without name | Extract to named constant |
| God class/function | > 10 dependencies or methods | Split by responsibility |
| Duplicate code | 3+ occurrences | Extract shared function/module |
| Unused imports/variables | Any | Remove |
| Debug code residue | console.log, print, debugger | Remove before commit |
| Stale TODO/FIXME | No linked Issue | Create Issue or remove |
| Long parameter list | > 3 parameters | Use parameter object |
| Feature envy | Method uses another class more than its own | Move method to the other class |

## Language-Specific Quick Reference

### TypeScript / JavaScript

- Use `const` by default; `let` only when reassignment is needed; never `var`
- Prefer `interface` over `type` for object shapes (except unions/intersections)
- Use strict mode (`"strict": true` in tsconfig)
- Prefer `async/await` over `.then()` chains
- Use optional chaining (`?.`) and nullish coalescing (`??`)

### Python

- Follow PEP 8 (enforced by ruff)
- Use type hints for all function signatures
- Prefer `dataclass` or `pydantic.BaseModel` for data structures
- Use `pathlib.Path` over `os.path`
- Use context managers (`with`) for resource management

### Go

- Follow Effective Go and Go Code Review Comments
- Handle every error (no `_` for error returns unless justified)
- Use `context.Context` as the first parameter for cancellation
- Prefer composition over inheritance (embed structs)
- Keep interfaces small (1-3 methods)

### Rust

- Use `clippy` with default lints
- Prefer `Result<T, E>` over `panic!` for recoverable errors
- Use `impl` blocks to group methods by trait
- Prefer iterators over manual loops
- Use `derive` macros for common traits

## Application in Workflow

- **During `/start-work`**: Reference standards when creating the implementation plan.
- **During implementation**: Apply naming, function, and error handling standards.
- **During `/commit`**: Check for code smells before committing.
- **During `/ci` review stage**: Use the Code Smell Detection table as a checklist.
- **During `/security-review`**: Cross-reference with error handling standards.

## Safety Guards

- Standards are advisory; do not block commits or PRs
- Language-specific rules defer to project-level configuration (eslintrc, pyproject.toml, etc.)
- When project conventions conflict with these standards, project conventions win
