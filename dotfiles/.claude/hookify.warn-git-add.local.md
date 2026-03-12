---
name: warn-git-add
enabled: true
event: bash
action: warn
conditions:
  - field: command
    operator: regex_match
    pattern: git\s+add\s+(-A|\.|--all)
---

⚠️ **Pre-staging check for git add**

Verify the following before staging:

**Security**
- No `.env`, `credentials.json`, `*.pem`, `*.key`, or files containing API keys
- Sensitive files are listed in `.gitignore`

**File size**
- No large binary files (images, videos, database dumps, etc.)
- No generated directories (`node_modules/`, `dist/`, `build/`, `__pycache__/`, etc.)

**Verify**: Run `git status` to review target files. Proceed if no issues.
