---
name: block-sensitive-files
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env(?!\.example$)(\..+)?$|credentials\.json$|\.pem$|\.key$|\.secret$
---

**Access to credential files has been blocked.**

Per CLAUDE.md core principles, the following files must not be read, edited, or committed:

- `.env` / `.env.local` / `.env.production`, etc. (environment variables) — `.env.example` is excluded
- `credentials.json` (credentials)
- `*.pem` / `*.key` (private keys)
- `*.secret` (secrets)

If you need to operate on these files, confirm with the user first.
