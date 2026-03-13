# Codex CLI and Gemini CLI Configuration Architecture

## 1. Overview

This project uses a multi-agent orchestration system with three AI CLI tools:

| Agent | Role | Model |
|-------|------|-------|
| **Claude Code** | Orchestrator, user interaction, task routing | claude-opus-4-6 |
| **Codex CLI** | Planning, design decisions, complex code implementation | gpt-5.3-codex (project) / gpt-5.4 (global) |
| **Gemini CLI** | Codebase analysis, external research, multimodal file reading | gemini-3.1-pro |

Each CLI has a **two-layer configuration** architecture:

- **Global templates** (`dotfiles/`): Minimal, portable defaults deployed to `~/` via setup modules
- **Project-level configs** (`.codex/`, `.gemini/`): Full, project-specific settings checked into the repository

---

## 2. Codex CLI Configuration

### 2.1 Project-Level (`.codex/`)

| File | Purpose | Key Settings |
|------|---------|-------------|
| `config.toml` | Model and feature settings | `model = "gpt-5.3-codex"`, `model_reasoning_effort = "xhigh"`, `web_search = "enabled"`, `skills = true` |
| `AGENTS.md` | Agent identity document | Defines Codex's role, strengths, boundaries, output format; references shared context from `.claude/` |
| `skills/context-loader/SKILL.md` | Context loading skill | Loads `.claude/rules/` and `.claude/docs/` at every task start; includes project-specific tool names (uv, ruff, ty) |
| `skills/design-tracker` | Design tracking skill | **Symlink** to `../../.claude/skills/design-tracker` -- shared between Claude Code and Codex |

**`config.toml` details:**

```toml
model = "gpt-5.3-codex"
model_reasoning_effort = "xhigh"
model_reasoning_summary = "detailed"
web_search = "enabled"
approval_policy = "on-request"

[features]
skills = true

[[skills.config]]
enabled = true
path = ".codex/skills/context-loader"
```

**`AGENTS.md` notable sections:**

- Position diagram showing Claude Code as orchestrator calling Codex
- Strengths: planning, design expertise, complex code, deep reasoning, trade-offs
- Boundary table: delegates research to Gemini, simple edits to Claude Code
- Shared context access instructions (`.claude/docs/`, `.claude/rules/`)
- Structured output format (Analysis, Recommendation, Implementation Plan, Rationale, Risks, Next Steps)
- CLI logs reference (`.claude/logs/cli-tools.jsonl`)

**`skills/context-loader/SKILL.md` workflow:**

1. Load coding rules from `.claude/rules/` (lists specific files)
2. Load design documentation from `.claude/docs/DESIGN.md`
3. Check library documentation from `.claude/docs/libraries/`
4. Execute the requested task with loaded context

Key rule #4 explicitly states: "Use uv -- Never use pip directly"

### 2.2 Global Templates (`dotfiles/.codex/`)

| File | Purpose | Differences from Project-Level |
|------|---------|-------------------------------|
| `config.toml` | Minimal model config | `model = "gpt-5.4"`, no `web_search`/`skills`/`approval_policy` settings |
| `rules/default.rules` | Sandbox allow rules | Allows `gh issue view` and `uv run pytest` commands |
| `AGENTS.md` | Generalized agent identity | Uses ASCII characters (`->`, `|--`, `+--` instead of Unicode arrows); adds cwd NOTE for path resolution; no CLI logs section |
| `skills/context-loader/SKILL.md` | Generalized context loader | Generic tool descriptions ("Package manager, linter, formatter" instead of "uv, ruff, ty"); `(if present)` qualifiers on file reads; no "Use uv" rule; cwd resolution NOTE |

**`rules/default.rules`:**

```
prefix_rule(pattern=["gh", "issue", "view"], decision="allow")
prefix_rule(pattern=["uv", "run", "pytest"], decision="allow")
```

### 2.3 Setup Module (`dotfiles/modules/codex-cli.sh`)

| Property | Value |
|----------|-------|
| MODULE_ORDER | 31 |
| MODULE_DEFAULT | 0 (disabled by default) |
| MODULE_DEPS | `node` (Node.js v18+) |
| Install command | `npm install -g @openai/codex` |
| Files deployed | 4 files to `~/.codex/` (config.toml, rules/default.rules, AGENTS.md, skills/context-loader/SKILL.md) |
| Uninstall | Restores backups, runs `npm uninstall -g @openai/codex`; preserves `~/.codex/` directory |

---

## 3. Gemini CLI Configuration

### 3.1 Project-Level (`.gemini/`)

| File | Purpose | Key Settings |
|------|---------|-------------|
| `settings.json` | Model and feature settings | `model = "gemini-3.1-pro"`, skills/agents enabled, context discovery (200 max dirs), file filtering (respects .gitignore/.geminiignore) |
| `GEMINI.md` | Agent identity document | Defines three roles (codebase analysis, external research, multimodal); output format; language protocol |
| `skills/context-loader/SKILL.md` | Context loading skill | Similar to Codex version but with Gemini-specific output guidelines (cite sources, save to `.claude/docs/research/`) |

**`settings.json` details:**

```json
{
  "model": { "name": "gemini-3.1-pro" },
  "context": {
    "fileName": ["GEMINI.md", "AGENTS.md"],
    "discoveryMaxDirs": 200,
    "fileFiltering": { "respectGitIgnore": true, "respectGeminiIgnore": true }
  },
  "tools": { "sandbox": false, "autoAccept": false },
  "experimental": { "skills": true, "enableAgents": true },
  "skills": { "disabled": [] }
}
```

**`GEMINI.md` notable sections:**

- Position diagram showing Claude Code (200K context) delegating to Gemini (1M context)
- Three roles: codebase understanding, external research (Google Search grounding), multimodal reading
- Multimodal file type table (PDF, video, audio, image with specific extensions)
- Boundary table: delegates design/planning to Codex, implementation to Claude Code
- Structured output format (Summary, Details, Recommendations, Notable Details)
- CLI logs reference (`.claude/logs/cli-tools.jsonl`)

**`skills/context-loader/SKILL.md` differences from Codex version:**

- Activation trigger: "research or analysis tasks" (vs "every task" for Codex)
- Key rule #3 includes "Use uv" (same as Codex project-level)
- Output guidelines include: cite sources from web search, save findings to `.claude/docs/research/`
- No "skip codex-delegation.md" instruction (Gemini skips gemini-delegation.md implicitly by not listing it)

### 3.2 Global Templates (`dotfiles/.gemini/`)

| File | Purpose | Differences from Project-Level |
|------|---------|-------------------------------|
| `settings.json` | Session retention only | Only `sessionRetention` settings (enabled, 30d max age); no model/context/tools/skills config |
| `GEMINI.md` | Generalized agent identity | Uses ASCII characters (`--`, `|--`, `+--`, `->` instead of Unicode); adds cwd NOTE for path resolution; adds shared context access section with `(if present)` qualifiers; no CLI logs section; same three roles, output format, and key principles as project-level |
| `skills/context-loader/SKILL.md` | Generalized context loader | `(if present)` qualifiers; cwd resolution NOTE; generic tool descriptions; no "Use uv" rule; ASCII tree characters |

### 3.3 Setup Module (`dotfiles/modules/gemini-cli.sh`)

| Property | Value |
|----------|-------|
| MODULE_ORDER | 30 |
| MODULE_DEFAULT | 0 (disabled by default) |
| MODULE_DEPS | `node` (Node.js v20+) |
| Install command | `npm install -g @google/gemini-cli` |
| Files deployed | 3 files to `~/.gemini/` (settings.json, GEMINI.md, skills/context-loader/SKILL.md) |
| Uninstall | Restores backups, runs `npm uninstall -g @google/gemini-cli`; preserves `~/.gemini/` directory |

---

## 4. Shared Context Architecture

All three CLIs share `.claude/` as their common knowledge base:

```
.claude/
├── docs/
│   ├── DESIGN.md              # Architecture decisions (read by all)
│   ├── research/              # Research results (written by Gemini, read by all)
│   └── libraries/             # Library constraints (read by all)
├── rules/
│   ├── coding-principles.md   # Loaded by context-loader skills
│   ├── dev-environment.md     # Loaded by context-loader skills
│   ├── language.md            # Loaded by context-loader skills
│   ├── security.md            # Loaded by context-loader skills
│   ├── testing.md             # Loaded by context-loader skills
│   ├── codex-delegation.md    # Read by Claude Code (routing logic)
│   └── gemini-delegation.md   # Read by Claude Code (routing logic)
├── skills/
│   └── design-tracker/        # Shared via symlink to .codex/skills/
└── logs/
    └── cli-tools.jsonl        # Codex/Gemini I/O logs
```

**Context flow:**

1. **Claude Code** reads delegation rules (`codex-delegation.md`, `gemini-delegation.md`) to decide task routing
2. **Codex CLI** context-loader skill loads `rules/` + `docs/` before every task
3. **Gemini CLI** context-loader skill loads `rules/` + `docs/` before research/analysis tasks
4. **Gemini CLI** writes research results to `.claude/docs/research/` for consumption by others
5. **design-tracker** skill is shared between Claude Code and Codex via symlink (`.codex/skills/design-tracker -> ../../.claude/skills/design-tracker`)

---

## 5. Design Patterns

### Two-Layer Configuration

| Aspect | Global (`dotfiles/`) | Project-Level (`.codex/`, `.gemini/`) |
|--------|---------------------|--------------------------------------|
| Scope | All projects via `~/` | This repository only |
| Model | Latest general-purpose (gpt-5.4) | Pinned version (gpt-5.3-codex) |
| Features | Minimal (no skills/web_search) | Full (skills, web_search, agents) |
| Context paths | `(if present)` qualifiers, cwd NOTE | Direct references, specific file lists |
| Tool names | Generic ("Package manager, linter") | Specific ("uv, ruff, ty") |
| Characters | ASCII only (`|--`, `+--`, `->`) | Unicode allowed (tree chars, arrows) |
| Agent identity | Generalized or placeholder | Full role definition with boundaries |

### Shared Knowledge Base

- `.claude/` serves as the single source of truth for project context
- context-loader skills are the mechanism for distributing this knowledge to each CLI
- Delegation rules in `.claude/rules/` define clear task routing boundaries

### Role Separation

| Role | Primary Agent | Fallback |
|------|--------------|----------|
| Orchestration, user interaction | Claude Code | -- |
| Planning, design, architecture | Codex CLI | -- |
| Complex code implementation | Codex CLI | Claude Code subagent |
| Codebase analysis (large) | Gemini CLI | -- |
| External research | Gemini CLI | -- |
| Multimodal file reading | Gemini CLI | -- |
| Simple edits (< 10 LOC) | Claude Code | -- |

### Portability Patterns in Global Templates

- ASCII characters only (no Unicode tree/arrow characters) for terminal compatibility
- `(if present)` qualifiers on file reads to avoid errors in projects without `.claude/`
- cwd resolution NOTE to clarify that `.claude/` paths are relative to the project, not the config file location
- No project-specific tool names (allows use across Python, TypeScript, Rust projects)

---

## 6. Known Issues & Design Notes

### Model Version Divergence (By Design)

- **Project** `.codex/config.toml`: `model = "gpt-5.3-codex"`
- **Global** `dotfiles/.codex/config.toml`: `model = "gpt-5.4"`
- This divergence is **intentional**. Global templates use the latest general-purpose model (`gpt-5.4`) as a sensible default for all projects. Project-level configs pin a specific stable version (`gpt-5.3-codex`) for reproducibility and consistency within the project. The project-level config takes precedence when both exist, so the global default is only used in projects without their own `.codex/config.toml`.

### Language Protocol Inconsistency -- RESOLVED

- **Fixed**: Both `codex-delegation.md` and `gemini-delegation.md` Language Protocol sections now correctly state "Report to user in **Japanese**", consistent with `CLAUDE.md` Core Principles.
- The workflow remains: Codex/Gemini output in English -> Claude Code translates to Japanese for the user. The delegation rule now documents this final step accurately.

### Global GEMINI.md is a Placeholder -- RESOLVED

- **Fixed**: `dotfiles/.gemini/GEMINI.md` now contains a full generalized agent identity, following the same pattern as the Codex global `AGENTS.md`.
- Includes: position diagram (ASCII), three roles, multimodal file type table, boundary table, shared context access with `(if present)` qualifiers, output format, language protocol, and key principles.
- Omits project-specific content: CLI logs section, Unicode characters.
