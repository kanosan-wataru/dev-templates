---
name: safety-guard
description: >
  Skill to prevent destructive operations during autonomous agent work.
  Invoke with /safety-guard (specify mode: careful, freeze, guard, or off).
  Intercepts dangerous commands and restricts file writes to designated areas.
  Use in scenarios such as: production work, autonomous execution, safety mode,
  "enable safety", "restrict writes", "careful mode".
---

# safety-guard: Destructive Operation Prevention Skill

Safety guard for production systems and autonomous agent execution.

## Arguments

- `/safety-guard careful` -- Detect destructive commands and request confirmation
- `/safety-guard freeze <dir>` -- Block writes outside the specified directory
- `/safety-guard guard --dir <dir>` -- Combine careful + freeze modes
- `/safety-guard off` -- Disable all guards
- `/safety-guard status` -- Report current guard state

## Watched Patterns (Careful Mode)

Detect the following patterns and request confirmation before execution:

| Pattern | Risk | Safer Alternative |
|---|---|---|
| `rm -rf` | Recursive file deletion | Specify targets explicitly |
| `git push --force` | History overwrite | `--force-with-lease` |
| `git reset --hard` | Change loss | `git stash` |
| `git checkout .` | Discard all changes | Restore individual files |
| `git clean -f` | Delete untracked files | `git clean -n` (dry run first) |
| `DROP TABLE` / `DROP DATABASE` | Data loss | Backup before execution |
| `TRUNCATE TABLE` | Data loss | Backup before execution |
| `docker system prune` | Delete all containers/images | Delete individually |
| `chmod 777` | Security risk | Use appropriate permissions |
| `npm publish` | Public package change | `--dry-run` first |
| `--no-verify` | Skip hooks | Fix hooks instead |
| `curl \| sh` / `curl \| bash` | Remote code execution | Download and review first |

### Detection Logic

1. Parse the command string before Bash tool execution.
2. Match against watched patterns (case-insensitive, supports aliases).
3. If matched: report the risk, suggest the safer alternative, and ask for confirmation.
4. If the user approves: proceed with execution.
5. If the user declines: skip and report "Blocked by safety-guard."

## Freeze Mode

Restrict Write/Edit operations to the specified directory tree:

```
/safety-guard freeze src/components/
-> Only src/components/ and its subdirectories are writable
-> All other files are read-only (Read/Grep/Glob still allowed)
```

### Freeze Logic

1. Record the freeze root path (absolute).
2. Before every Write or Edit tool call, check if the target path starts with the freeze root.
3. If outside the freeze root: block and report "Write blocked by freeze mode: <path>".
4. Reads are always allowed regardless of freeze scope.

## Guard Mode

Activate Careful + Freeze simultaneously:

```
/safety-guard guard --dir src/api/
-> Reads: all files allowed
-> Writes: only src/api/ and subdirectories
-> Destructive commands: all blocked (confirmation required)
```

## Status Reporting

`/safety-guard status` reports:

```markdown
## Safety Guard Status

| Setting | Value |
|---|---|
| Careful Mode | ON / OFF |
| Freeze Mode | ON / OFF |
| Freeze Root | (path or N/A) |
| Blocked Actions | N (since activation) |
| Last Blocked | (timestamp and command) |
```

## Implementation Notes

This skill operates as a behavioral contract for the agent:
1. When activated, the agent checks every Bash, Write, and Edit call against active rules.
2. All blocked actions are logged with timestamp, command, and reason.
3. Deactivation requires explicit `/safety-guard off` -- guards persist across tool calls within a session.

## Safety Guards

- Log all blocked actions to `~/.claude/safety-guard.log` (append-only)
- `/safety-guard off` requires explicit invocation (no implicit deactivation)
- Guard state is reported at the start of each response when active
- Cannot freeze the root directory `/` or home directory `~/` (too broad)
