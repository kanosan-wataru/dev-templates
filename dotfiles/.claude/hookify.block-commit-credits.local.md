---
name: block-commit-credits
enabled: true
event: bash
action: block
conditions:
  - field: command
    operator: regex_match
    pattern: git\s+commit\s+.*(?:Co-Authored-By|Generated with|via \[Happy\])
---

**Credit lines in commit message have been blocked.**

Per CLAUDE.md Git Rules, commit messages must NOT contain any of the following:

- `Co-Authored-By:` lines
- `Generated with [Claude Code]` lines
- `via [Happy]` lines

Remove all credit/attribution lines and retry the commit.
