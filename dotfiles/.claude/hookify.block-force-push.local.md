---
name: block-force-push
enabled: true
event: bash
action: block
pattern: git\s+push\s+.*--force(?!-)|git\s+push\s+.*-f\b
---

**Force-push has been blocked.**

`--force` overwrites remote history and may destroy other people's work.

**Alternatives:**
- `git push --force-with-lease` — Overwrites only if remote is unchanged (safer)
- `git pull --rebase` then regular `git push`

If force-push is truly needed, confirm with the user and execute manually.
