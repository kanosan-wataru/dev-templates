# Project Design Document

> This document tracks design decisions made during conversations.
> Updated automatically by the `design-tracker` skill.

## Overview

Claude Code Orchestra is a multi-agent collaboration framework. Claude Code (200K context) is the orchestrator, with Codex CLI for planning/design/complex code, Gemini CLI (1M context) for codebase analysis, research, and multimodal reading, and subagents (Opus) for code implementation and Codex delegation.

## Architecture

```
+---------------------------------------------------------------+
|  Claude Code Lead (Opus 4.6 -- 200K context)                  |
|  Role: Orchestration, user interaction, task management        |
|                                                                |
|  +------------------------+  +------------------------+       |
|  | Agent Teams (Opus)      |  | Subagents (Opus)       |       |
|  | (parallel + comms)      |  | (isolated + results)   |       |
|  |                         |  |                         |       |
|  | Researcher <-> Archit.  |  | Code implementation     |       |
|  | Implementer A/B/C       |  | Codex consultation      |       |
|  | Security/Quality Rev.   |  | Gemini consultation     |       |
|  +------------------------+  +------------------------+       |
|                                                                |
|  External CLIs:                                                |
|  +-- Codex CLI (gpt-5.3-codex) -- planning, design, code      |
|  +-- Gemini CLI (1M context) -- codebase analysis, research,  |
|       multimodal reading                                       |
+---------------------------------------------------------------+
```

### Agent Roles

| Agent | Role | Responsibilities |
|-------|------|------------------|
| Claude Code (Main) | Overall orchestration | User interaction, task management, simple code edits |
| general-purpose (Opus) | Implementation & Codex delegation | Code implementation, Codex delegation, file operations |
| gemini-explore (Opus) | Large-scale analysis & research | Codebase understanding, external research, multimodal reading |
| Codex CLI | Planning & complex implementation | Architecture design, implementation planning, complex code, debugging |
| Gemini CLI (1M context) | Analysis, research & reading | Codebase analysis, external research, multimodal reading |

---

## Issue #71: Zsh-to-Bash Migration Design

### 1. Module System Redesign (CRITICAL DECISION)

**Decision: Option A -- Direct naming convention in module files**

Each module file defines `setup_<safe_id>()` and `uninstall_<safe_id>()` directly, instead of the current `module_setup()` / `module_uninstall()` generic names that get dynamically renamed via zsh `functions[]`.

**Rationale:**

| Option | Approach | Pros | Cons | Verdict |
|--------|----------|------|------|---------|
| A. Direct naming | Modules define `setup_<safe_id>()` directly | Simplest, no renaming, shellcheck-clean, no eval/sed | Module must know its own safe_id; slight diff in each module | **CHOSEN** |
| B. eval+sed rename | `eval "$(declare -f module_setup \| sed '1s/...')"` | Module files unchanged | Fragile (function name in body), shellcheck warnings, sed edge cases | Rejected |
| C. Associative array dispatch | Store function body in assoc array | Flexible | Over-engineered, hard to debug, shellcheck issues | Rejected |
| D. Re-source on call | Source module file each time setup is called | No collision | Slow, re-executes top-level code, side effects | Rejected |
| E. eval+bash replace | `eval "${body/module_setup/setup_${safe_id}}"` | No sed dependency | Same fragility as B (replaces ALL occurrences in body) | Rejected |

**Implementation details:**

```bash
# BEFORE (zsh) -- module file defines generic names:
module_setup() { ... }
module_uninstall() { ... }

# AFTER (bash) -- module file defines specific names:
# Module file MUST define functions matching its MODULE_ID (hyphens -> underscores)
setup_docker() { ... }
uninstall_docker() { ... }

# For MODULE_ID="claude-code":
setup_claude_code() { ... }
uninstall_claude_code() { ... }

# For MODULE_ID="1password":
setup_1password() { ... }
uninstall_1password() { ... }
```

**Validation in load_modules():**

```bash
load_modules() {
    local modules_dir="$SCRIPT_DIR/modules"
    # ...
    for module_file in "$modules_dir"/*.sh; do
        local MODULE_ID="" MODULE_NAME="" MODULE_DESC="" MODULE_DEFAULT=0 MODULE_ORDER=50 MODULE_DEPS=""
        source "$module_file" || { warn "..."; continue; }

        local safe_id="${MODULE_ID//-/_}"

        # Validate that the module defined its setup function
        if ! declare -f "setup_${safe_id}" >/dev/null 2>&1; then
            warn "${module_file##*/} does not define setup_${safe_id}(). Skipping."
            continue
        fi

        # No renaming needed -- function is already correctly named
        # ...
    done
}
```

**Migration effort per module:** ~2 lines changed (function name in definition).

**BATS test update:** The `test_module_metadata.bats` test that checks for `module_setup()` must be updated to check for `setup_<id>()` pattern instead.

---

### 2. Color Output System

**Decision: Helper functions with ANSI escape codes**

Replace all `print -P "%F{N}...%f"` calls with semantic helper functions.

```bash
# --- Color helpers (defined once in setup.sh) ---
# These are available to all modules via source

_color_reset=$'\033[0m'
_color_red=$'\033[31m'
_color_bright_red=$'\033[91m'
_color_green=$'\033[32m'
_color_yellow=$'\033[33m'
_color_blue=$'\033[34m'
_color_cyan=$'\033[36m'
_color_gray=$'\033[90m'
_color_bold=$'\033[1m'

_print_error()   { printf '%s%s%s\n' "$_color_red" "$*" "$_color_reset" >&2; }
_print_success() { printf '%s%s%s\n' "$_color_green" "$*" "$_color_reset"; }
_print_warning() { printf '%s%s%s\n' "$_color_yellow" "$*" "$_color_reset"; }
_print_info()    { printf '%s%s%s\n' "$_color_blue" "$*" "$_color_reset"; }
_print_header()  { printf '%s%s%s%s\n' "$_color_bold" "$_color_cyan" "$*" "$_color_reset"; }
_print_dim()     { printf '%s%s%s\n' "$_color_gray" "$*" "$_color_reset"; }
_print_plain()   { printf '%s\n' "$*"; }

# For inline color within a line (not a full-line helper):
# printf 'Installing %s%s%s...\n' "$_color_cyan" "$name" "$_color_reset"
```

**Color mapping (zsh -> bash):**

| Zsh `%F{N}` | Semantic | ANSI Code | Helper |
|--------------|----------|-----------|--------|
| `%F{160}` | Error | `\033[31m` | `_print_error` |
| `%F{196}` | Critical | `\033[91m` | `_print_error` (same) |
| `%F{34}` | Success | `\033[32m` | `_print_success` |
| `%F{220}` | Warning | `\033[33m` | `_print_warning` |
| `%F{242}` | Dim/dry-run | `\033[90m` | `_print_dim` |
| `%F{36}` | Header/section | `\033[36m` | `_print_header` |
| `%F{33}` | Info | `\033[34m` | `_print_info` |
| `%B`/`%b` | Bold on/off | `\033[1m` | Combined in `_print_header` |

---

### 3. Field Splitting Replacement

**Decision: IFS+read pattern for pipe-delimited strings**

```bash
# BEFORE (zsh):
local src="${entry[(ws:|:)1]}"
local dst="${entry[(ws:|:)2]}"
local label="${entry[(ws:|:)3]}"
local hint="${entry[(ws:|:)4]}"

# AFTER (bash):
IFS='|' read -r src dst label hint <<< "$entry"
```

This is used in ~60 locations across all module files and setup.sh. It is a mechanical find-replace.

For cases where only specific fields are needed:

```bash
# Extract just the first field (MODULE_ID from MODULES array entry)
local mod_id="${entry%%|*}"
```

---

### 4. TUI Checkbox Menu (bash rewrite)

**Key changes from zsh to bash:**

| Feature | Zsh | Bash |
|---------|-----|------|
| Single char read | `read -k 1 key` | `read -rsn 1 key` |
| Timed read | `read -k 1 -t 0.05 key2` | `read -rsn 1 -t 0.05 key2` |
| Array indexing | 1-based | 0-based |
| Brace range | `{1..$count}` | `for ((i=0; i<count; i++))` |
| String slice | `${line[1,$max]}` | `${line:0:$max}` |
| Print color | `print -P "%F{36}..."` | `printf '\033[36m...\033[0m\n'` |
| Empty line loop | `for i in {1..$n}; do print ""; done` | `for ((i=0; i<n; i++)); do printf '\n'; done` |

**Function signature (bash):**

```bash
# checkbox_menu -- display interactive checkbox selection menu
# Arguments: menu items as "label|description|default_selected(0/1)"
# Sets: REPLY -- space-separated 0-based indices of selected items
# Returns: 0 on confirm, 1 on cancel (q key)
checkbox_menu() {
    local -a items=("$@")
    local item_count=${#items[@]}
    local cursor=0            # 0-based
    local -a selected labels descs
    local redraw=0

    # Parse items
    for ((i=0; i<item_count; i++)); do
        IFS='|' read -r lbl desc dflt <<< "${items[$i]}"
        labels+=("$lbl")
        descs+=("$desc")
        selected+=("$dflt")
    done

    # Terminal setup
    trap '_checkbox_cleanup' INT TERM QUIT
    tput civis 2>/dev/null

    # Pre-allocate scroll space
    local header_lines=2
    local total_lines=$((header_lines + item_count))
    for ((i=0; i<total_lines; i++)); do printf '\n'; done
    for ((i=0; i<total_lines; i++)); do tput cuu1; done

    while true; do
        _checkbox_draw "$item_count" "$cursor" "$header_lines" "$redraw"
        redraw=1

        local key=""
        read -rsn 1 key

        case "$key" in
            $'\e')
                local key2="" key3=""
                read -rsn 1 -t 0.05 key2 2>/dev/null || true
                if [[ "$key2" == "[" || "$key2" == "O" ]]; then
                    read -rsn 1 -t 0.05 key3 2>/dev/null || true
                    case "$key3" in
                        A) ((cursor > 0)) && ((cursor--)) ;;
                        B) ((cursor < item_count - 1)) && ((cursor++)) ;;
                    esac
                fi
                ;;
            k) ((cursor > 0)) && ((cursor--)) ;;
            j) ((cursor < item_count - 1)) && ((cursor++)) ;;
            ' ')
                if ((selected[cursor])); then
                    selected[$cursor]=0
                else
                    selected[$cursor]=1
                fi
                ;;
            a) # Toggle all
                local all_on=1
                for ((i=0; i<item_count; i++)); do
                    if ((! selected[i])); then all_on=0; break; fi
                done
                local new_val=$((! all_on))
                for ((i=0; i<item_count; i++)); do selected[$i]=$new_val; done
                ;;
            q) tput cnorm 2>/dev/null; trap - INT TERM QUIT; return 1 ;;
            '') break ;;  # Enter key (empty read)
        esac
    done

    tput cnorm 2>/dev/null
    trap - INT TERM QUIT

    # Build REPLY with 0-based indices
    REPLY=""
    for ((i=0; i<item_count; i++)); do
        if ((selected[i])); then REPLY+="$i "; fi
    done
    return 0
}
```

**NOTE on Enter key detection:** In bash, `read -n 1` returns an empty string for Enter/newline. The `''` case in the case statement handles this.

---

### 5. Other Zsh-to-Bash Conversions

| Construct | Zsh | Bash | Count |
|-----------|-----|------|-------|
| Script dir | `${0:a:h}` | `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` | 1 |
| Basename | `${file:t}` | `${file##*/}` | ~15 |
| Dirname | `${dir:h}` | `${dir%/*}` | 1 |
| Typed decl | `typeset -a/-A/-i` | `declare -a/-A/-i` | ~15 |
| Array search | `${arr[(Ie)val]}` | `_array_contains "$val" "${arr[@]}"` helper | 3 |
| Sort array | `${(o)arr}` | `printf '%s\n' "${arr[@]}" \| sort` | 1 |
| Reverse iter | `${(@Oa)arr}` | `for ((i=${#arr[@]}-1; i>=0; i--))` | 1 |
| Quote args | `${(q)@}` | `printf '%q ' "$@"` | 1 |
| Null glob | `*.sh(N)` | `shopt -s nullglob; ...; shopt -u nullglob` | 1 |
| Newest backup | `*(N^/Om[1])` | `_find_newest_backup()` helper | ~9 |
| Space split | `${(s: :)var}` | `$var` (unquoted) or `read -ra arr <<< "$var"` | 2 |
| Shell check | `$ZSH_VERSION` | `$BASH_VERSION` | 2 |
| Plain print | `print "text"` | `printf '%s\n' "text"` | ~20 |
| `unfunction` | `unfunction fn` | `unset -f fn` | 1 |
| `print -n` | `print -P -n` | `printf '%s' "..."` (no newline) | ~5 |

---

### 6. Backup File Discovery Helper

The zsh glob qualifier `*(N^/Om[1])` (nullglob, not-directory, sort-by-mtime-descending, take first) appears in 9 module files. A shared helper function replaces this.

```bash
# _find_newest_backup -- find the most recently modified backup file
# Arguments: $1 = base path (e.g., /home/user/.gitconfig)
# Output: full path to newest backup, or empty if none found
# Returns: 0 if found, 1 if not found
_find_newest_backup() {
    local base_path="$1"
    local result
    # Use ls -t to sort by modification time (newest first)
    # The pattern matches: <base_path>.backup.*
    result=$(ls -t "${base_path}.backup."* 2>/dev/null | head -1)
    if [[ -n "$result" && -f "$result" ]]; then
        printf '%s' "$result"
        return 0
    fi
    return 1
}

# Usage in modules:
local latest_backup
if latest_backup=$(_find_newest_backup "$dst"); then
    _print_plain "Restoring: ${label} from backup ($(basename "$latest_backup"))."
    run_cmd command mv "$latest_backup" "$dst" || { ... }
fi
```

---

### 7. .zsh/.bash Config File Strategy

**Decision: Dual directory structure (keep .zsh, add .bash)**

```
dotfiles/
+-- .zsh/             # UNCHANGED -- for zsh users
|   +-- plugins.zsh   # Zinit (zsh-only, no bash equivalent)
|   +-- aliases.zsh   # POSIX-compatible
|   +-- env.zsh       # POSIX-compatible
|   +-- node.zsh      # fnm --shell zsh
|   +-- python.zsh    # POSIX-compatible
|   +-- 1password.zsh # Minor zsh-isms
|   +-- .p10k.zsh     # Powerlevel10k (zsh-only)
+-- .bash/            # NEW -- for bash users
|   +-- aliases.sh    # Symlink or copy from aliases.zsh (identical)
|   +-- env.sh        # Symlink or copy from env.zsh (identical)
|   +-- node.sh       # Adapted: fnm env --shell bash
|   +-- python.sh     # Symlink or copy from python.zsh (identical)
|   +-- 1password.sh  # Adapted: printf instead of print -P
|   +-- plugins.sh    # NEW: bash completions, prompt setup
+-- .bashrc           # NEW: entry point for bash config
+-- .zshrc            # EXISTING: entry point for zsh config
```

**Note:** Files that are POSIX-compatible (aliases, env, python) can be shared via symlinks or a single source file. The `plugins.sh` is entirely new since Zinit is zsh-only.

---

### 8. Phased Migration Plan

#### Phase 1a: Common Helpers [Risk: LOW]

**Files to modify:** `setup.sh` (add helper functions section)

**Changes:**
1. Add color helper functions (`_print_error`, `_print_success`, etc.)
2. Add `_array_contains()` helper
3. Add `_find_newest_backup()` helper
4. Replace `${0:a:h}` with `BASH_SOURCE` pattern
5. Replace `$ZSH_VERSION` guard with `$BASH_VERSION`
6. Replace `typeset` with `declare`/`local`

**Testing:** Unit test each helper function in BATS. Syntax check with `bash -n`.

---

#### Phase 1b: Module System Redesign [Risk: MEDIUM]

**Files to modify:** `setup.sh` (load_modules, run_module_setup, run_module_uninstall), ALL 10 module files

**Changes:**
1. In `setup.sh`: Remove `functions[]` renaming logic from `load_modules()`
2. In `setup.sh`: Update `run_module_setup()` and `run_module_uninstall()` to use `declare -f` for function existence check
3. In each module file: Rename `module_setup()` -> `setup_<safe_id>()`
4. In each module file: Rename `module_uninstall()` -> `uninstall_<safe_id>()`
5. Update BATS tests to check for new function naming pattern

**Module rename mapping:**

| Module File | MODULE_ID | setup function | uninstall function |
|-------------|-----------|----------------|-------------------|
| `1password.sh` | 1password | `setup_1password()` | `uninstall_1password()` |
| `claude-code.sh` | claude-code | `setup_claude_code()` | `uninstall_claude_code()` |
| `codex-cli.sh` | codex-cli | `setup_codex_cli()` | `uninstall_codex_cli()` |
| `docker.sh` | docker | `setup_docker()` | `uninstall_docker()` |
| `gemini-cli.sh` | gemini-cli | `setup_gemini_cli()` | `uninstall_gemini_cli()` |
| `git.sh` | git | `setup_git()` | `uninstall_git()` |
| `modern-cli.sh` | modern-cli | `setup_modern_cli()` | `uninstall_modern_cli()` |
| `node.sh` | node | `setup_node()` | `uninstall_node()` |
| `python.sh` | python | `setup_python()` | `uninstall_python()` |
| `zsh.sh` | zsh | `setup_zsh()` | `uninstall_zsh()` |

**Testing:** BATS tests must verify:
- All modules define `setup_<safe_id>()` (updated from `module_setup()`)
- `load_modules()` correctly discovers and validates functions
- Duplicate detection still works
- MODULE_ORDER sorting still works

---

#### Phase 1c: TUI Checkbox Rewrite [Risk: MEDIUM-HIGH]

**Files to modify:** `setup.sh` (checkbox_menu, _checkbox_draw, _checkbox_cleanup)

**Changes:**
1. Rewrite `checkbox_menu()` with 0-based arrays
2. Replace `read -k 1` with `read -rsn 1`
3. Replace `print -P` with ANSI escape printf
4. Replace `{1..$var}` loops with C-style for loops
5. Replace `${line[1,N]}` with `${line:0:N}`
6. Update caller code in setup.sh to use 0-based indices from REPLY

**Testing:** Manual testing required (interactive TUI). Add BATS test for non-interactive fallback.

---

#### Phase 1d: Individual Module Conversion [Risk: LOW-MEDIUM]

**Files to modify:** All 10 module files

**Changes per module:**
1. Replace `print -P "%F{N}...%f"` with helper functions (~30 per module)
2. Replace `${entry[(ws:|:)N]}` with `IFS='|' read -r ...` pattern
3. Replace `print "text"` with `printf '%s\n' "text"`
4. Replace `*(N^/Om[1])` backup glob with `_find_newest_backup()`
5. Replace `${file:t}` with `${file##*/}`
6. Replace `print` (plain) with `printf '%s\n'`

**Order of conversion (by complexity):**

1. `git.sh` -- simplest module, good for establishing patterns
2. `python.sh` -- simple, similar to git
3. `zsh.sh` -- simple
4. `codex-cli.sh` -- medium complexity
5. `gemini-cli.sh` -- medium complexity
6. `node.sh` -- medium complexity
7. `docker.sh` -- medium complexity (no field splitting, just print -P)
8. `modern-cli.sh` -- medium (field splitting in tool definitions)
9. `claude-code.sh` -- complex (many managed files, field splitting)
10. `1password.sh` -- most complex module

**Testing:** After each module conversion:
- `bash -n modules/<file>.sh` (syntax check)
- `shellcheck modules/<file>.sh`
- BATS metadata tests
- Manual dry-run test

---

#### Phase 1e: setup.sh Main Flow Conversion [Risk: MEDIUM]

**Files to modify:** `setup.sh` (argument parsing, module selection, dispatch)

**Changes:**
1. Replace shebang: `#!/usr/bin/env zsh` -> `#!/usr/bin/env bash`
2. Replace all `print -P` calls with helpers
3. Replace `${entry[(ws:|:)N]}` field splitting
4. Replace `${(s: :)var}` with unquoted variable or read -ra
5. Replace `${arr[(Ie)val]}` with `_array_contains`
6. Replace `${(o)_unsorted}` sort with piped sort
7. Replace `${(@Oa)MODULES}` reverse with reverse for loop
8. Replace `(( $# > 0 ))` with `(( $# > 0 ))` (same in bash)
9. Replace `SELECT_MODULES+=("$1")` (works in both)
10. Replace `for entry in ${(o)_unsorted}` with sorted pipe
11. Update `resolve_module_deps()` to use bash-compatible array operations

**Testing:** Full integration test: `bash setup.sh --dry-run --all`

---

#### Phase 2: Config File bash/zsh Separation [Risk: LOW]

**Files to create:**
- `dotfiles/.bash/aliases.sh`
- `dotfiles/.bash/env.sh`
- `dotfiles/.bash/node.sh`
- `dotfiles/.bash/python.sh`
- `dotfiles/.bash/1password.sh`
- `dotfiles/.bash/plugins.sh`
- `dotfiles/.bashrc`

**Changes:**
- Copy POSIX-compatible files directly
- Adapt zsh-specific files (node.zsh -> node.sh with `--shell bash`)
- Create new bash plugins.sh (completions, prompt)
- Create .bashrc entry point

**Testing:** Source each file in bash, verify no errors.

---

#### Phase 3: CI Integration [Risk: LOW]

**Files to modify:** CI config (if exists), BATS tests

**Changes:**
1. Add `shfmt` check for all .sh files
2. Add `shellcheck` check for all .sh files (SC2034, SC2154 may need directives)
3. Update BATS tests:
   - Change `zsh -n` syntax check to `bash -n`
   - Change `zsh -c "source ..."` to `bash -c "source ..."`
   - Update function name checks
   - Add backup glob replacement test
4. Add `shfmt -d -i 4 -ci` formatting check
5. Add `shellcheck -s bash -S warning` linting

**Testing:** Run full CI pipeline.

---

### 9. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Module function naming collision | HIGH | LOW | Validation in load_modules() detects duplicates |
| 0-indexed vs 1-indexed off-by-one | HIGH | MEDIUM | Careful review; BATS tests for index boundaries |
| TUI breaks on some terminals | MEDIUM | MEDIUM | Fallback to non-interactive mode already exists |
| Backup discovery misses edge cases | MEDIUM | LOW | `ls -t` fallback is well-tested pattern |
| shellcheck strictness breaks CI | LOW | MEDIUM | Add targeted `# shellcheck disable=` directives |
| Module authors forget naming convention | LOW | LOW | BATS test enforces; clear docs in module template |

---

### 10. Estimated Effort

| Phase | Files Changed | Lines Changed (est.) | Effort |
|-------|---------------|---------------------|--------|
| 1a: Helpers | 1 (setup.sh) | +80 new | Small |
| 1b: Module system | 11 (setup.sh + 10 modules) | ~50 total | Medium |
| 1c: TUI | 1 (setup.sh) | ~160 rewrite | Medium |
| 1d: Module conversion | 10 modules | ~800 total (mostly print -P) | Large (mechanical) |
| 1e: setup.sh main | 1 (setup.sh) | ~200 | Medium |
| 2: Config files | 7 new files | ~300 new | Medium |
| 3: CI | BATS + CI config | ~100 | Small |
| **Total** | ~30 files | ~1,700 lines | **2-3 sprints** |

---

## Implementation Plan

### Patterns & Approaches

| Pattern | Purpose | Notes |
|---------|---------|-------|
| Agent Teams | Parallel work with inter-agent communication | /startproject, /team-implement, /team-review |
| Subagents | Isolated tasks returning results | External research, Codex consultation, implementation |
| Skill Pipeline | `/startproject` -> `/team-implement` -> `/team-review` | Separation of concerns across skills |

### Libraries & Roles

| Library | Role | Version | Notes |
|---------|------|---------|-------|
| Codex CLI | Planning, design, complex code | gpt-5.3-codex | Architecture, planning, debug, complex implementation |
| Gemini CLI | Multimodal file reading | gemini-3-pro | PDF/video/audio/image extraction ONLY |

### Key Decisions

| Decision | Rationale | Alternatives Considered | Date |
|----------|-----------|------------------------|------|
| Module system: direct naming (Option A) | Simplest, shellcheck-clean, no eval/sed fragility | eval+sed rename (B), assoc array dispatch (C), re-source (D) | 2026-03-18 |
| Color output: semantic helpers | DRY, consistent, easy to change colors globally | Inline ANSI codes (verbose), tput setaf (slower) | 2026-03-18 |
| Field splitting: IFS+read | Idiomatic bash, clean, one-liner per split | Helper function (verbose), cut (subshell overhead) | 2026-03-18 |
| TUI: in-place rewrite | Preserve exact UX; read -rsn 1 is direct equivalent of read -k 1 | External tool (dialog/whiptail), simplify to numbered list | 2026-03-18 |
| Config files: dual .zsh/.bash dirs | No breaking change for existing zsh users | Single shared dir (too many conditionals), replace .zsh entirely (breaking) | 2026-03-18 |
| Target: bash 4+ only | declare -A required; macOS excluded from scope | bash 3.2 (no assoc arrays, much harder) | 2026-03-18 |
| Backup discovery: ls -t helper | Simple, fast, covers all cases | find -printf (GNU-only), stat (macOS incompatible -- moot since Linux-only) | 2026-03-18 |
| Gemini role expanded to codebase analysis + research + multimodal | Gemini CLI has native 1M context; Claude Code is 200K; delegate large-context tasks to Gemini | Keep Claude for codebase analysis (requires 1M Beta) | 2026-02-19 |
| All subagents default to Opus | 200K context makes quality of reasoning more important than context size; Opus provides better output | Sonnet (cheaper but 200K same as Opus, weaker reasoning) | 2026-02-19 |
| Agent Teams default model changed to Opus | Consistent with subagent model selection; better reasoning for parallel tasks | Sonnet (cheaper) | 2026-02-19 |
| Claude Code context corrected to 200K | 1M is Beta/pay-as-you-go only; most users have 200K; design must work for common case | Assume 1M (only works for Tier 4+ users) | 2026-02-19 |
| Subagent delegation threshold lowered to ~20 lines | 200K context requires more aggressive context management | 50 lines (was based on 1M assumption) | 2026-02-19 |
| Codex role unchanged (planning + complex code) | Codex excels at deep reasoning for both design and implementation | Keep Codex advisory-only | 2026-02-17 |
| /startproject split into 3 skills | Separation of Plan/Implement/Review gives user control gates | Single monolithic skill | 2026-02-08 |
| Agent Teams for Research <-> Design | Bidirectional communication enables iterative refinement | Sequential subagents (old approach) | 2026-02-08 |
| Agent Teams for parallel implementation | Module-based ownership avoids file conflicts | Single-agent sequential implementation | 2026-02-08 |

## TODO

- [ ] Test Agent Teams workflow end-to-end with a real project
- [ ] Update hooks for Agent Teams quality gates
- [ ] Evaluate optimal team size for /team-implement
- [x] Issue #71: Execute Phase 1a-1e (zsh-to-bash migration) -- PR #72
- [x] Issue #71: Execute Phase 2 (config file separation) -- PR #73
- [x] Issue #71: Execute Phase 3 (CI integration) -- PR #74

## Open Questions

- [ ] Optimal team size for /team-implement (2-3 vs 4-5 teammates)?
- [ ] Should /team-review be mandatory or optional?
- [ ] How to handle Compaction in long Agent Teams sessions?

## Changelog

| Date | Changes |
|------|---------|
| 2026-03-18 | Issue #71: Added zsh-to-bash migration architecture (module system, TUI, color helpers, phased plan) |
| 2026-02-19 | Context-aware redesign: Claude=200K, Gemini=1M (codebase+research+multimodal), all subagents/teams->Opus |
| 2026-02-17 | Role clarification: Gemini -> multimodal only, Codex -> planning + complex code, Subagents -> external research |
| 2026-02-08 | Major redesign for Opus 4.6: 1M context, Agent Teams, skill pipeline |
| | Initial |
