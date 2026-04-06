---
name: block-sensitive-files
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env(?!\.example$)(\..+)?$|credentials\.json$|\.pem$|\.key$|\.secret$|id_(rsa|ed25519)$|\.(p12|pfx)$|(^|/)\.aws/credentials$|(^|/)\.npmrc$|(^|/)\.docker/config\.json$|(^|/)\.netrc$|(^|/)\.pgpass$
---

**Access to credential files has been blocked.**

Per CLAUDE.md core principles, the following files must not be read, edited, or committed:

- `.env` / `.env.local` / `.env.production`, etc. (environment variables) — `.env.example` is excluded
- `credentials.json` (credentials)
- `*.pem` / `*.key` / `*.secret` (private keys / secrets)
- `id_rsa` / `id_ed25519` (SSH private keys)
- `*.p12` / `*.pfx` (certificates)
- `.aws/credentials` (AWS credentials)
- `.npmrc` (npm auth tokens)
- `.docker/config.json` (Docker registry auth)
- `.netrc` (network credentials)
- `.pgpass` (PostgreSQL passwords)

If you need to operate on these files, confirm with the user first.
