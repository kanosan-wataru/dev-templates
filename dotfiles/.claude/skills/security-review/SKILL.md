---
name: security-review
description: >
  Skill to perform a security review based on OWASP Top 10.
  Invoke with /security-review (optionally specify target files or directories).
  Checks authentication, input validation, secrets management, and API endpoint security.
  Use in scenarios such as: security check, auth implementation review, API review,
  "check security", "review for vulnerabilities", "OWASP check".
---

# security-review: Security Review Skill

Applies an OWASP Top 10 based security checklist to target code.

## Arguments

- `<target>` (optional): File or directory to review.
  - Example: `/security-review` -> Review files changed in git diff
  - Example: `/security-review src/api/` -> Review the specified directory
  - Example: `/security-review src/auth/login.ts` -> Review a specific file

## Execution Flow

### Step 1: Scope Detection

1. If an argument is provided, use that file or directory as the target.
2. If omitted, detect changed files with `git diff --name-only` (staged + unstaged).
3. Read target files and determine language and framework.
4. Filter to security-relevant files (skip static assets, docs, config-only files).

### Step 2: Security Checklist

Apply the following checklist to the target code:

#### 2-a: Secrets Management

- [ ] No hardcoded API keys, passwords, or tokens in source code
- [ ] Secrets are loaded via environment variables or a secrets manager
- [ ] `.env` files are listed in `.gitignore`
- [ ] No secrets in log output or error messages

#### 2-b: Input Validation

- [ ] All user input is validated with a schema (Zod, Pydantic, etc.)
- [ ] File uploads have size, type, and extension restrictions
- [ ] Whitelist validation is used (not blacklist)
- [ ] Path traversal attacks are prevented (`../` in file paths)

#### 2-c: SQL Injection

- [ ] All queries use parameterized statements
- [ ] No SQL construction via string concatenation
- [ ] ORM is used correctly (no raw queries without parameterization)

#### 2-d: XSS Prevention

- [ ] User-provided HTML is sanitized (DOMPurify, bleach, etc.)
- [ ] CSP headers are configured
- [ ] `dangerouslySetInnerHTML` is not used without DOMPurify
- [ ] Template engines auto-escape output by default

#### 2-e: Authentication & Authorization

- [ ] Tokens are stored in httpOnly cookies (not localStorage)
- [ ] Authorization checks exist before sensitive operations
- [ ] Session management is secure (expiry, rotation, invalidation)
- [ ] Password hashing uses bcrypt/argon2 (not MD5/SHA1)

#### 2-f: Rate Limiting

- [ ] API endpoints have rate limiting configured
- [ ] Expensive operations (login, search, file upload) have stricter limits
- [ ] Rate limit headers are returned to clients

#### 2-g: Error Handling

- [ ] Error messages do not expose internal details (file paths, stack traces, SQL)
- [ ] Stack traces are not shown to end users
- [ ] Detailed errors are logged server-side only
- [ ] Generic error responses are returned to clients

### Step 3: Severity Classification

Classify each finding by severity:

| Severity | Criteria | Action |
|---|---|---|
| Critical | Exploitable immediately (hardcoded secrets, SQL injection) | Must fix before merge |
| High | Exploitable with effort (missing auth, XSS) | Must fix before merge |
| Medium | Defense-in-depth gap (missing rate limit, verbose errors) | Recommended fix |
| Low | Best practice deviation (missing CSP, non-httpOnly token) | Advisory |

### Step 4: Report

Report results in the following format:

```markdown
## Security Review Results

**Scope**: N files reviewed
**Language/Framework**: (detected)

| Category | Status | Issues |
|---|---|---|
| Secrets | PASS / FAIL | (details with file:line) |
| Input Validation | PASS / FAIL | (details with file:line) |
| SQL Injection | PASS / FAIL | (details with file:line) |
| XSS | PASS / FAIL | (details with file:line) |
| Auth | PASS / FAIL | (details with file:line) |
| Rate Limiting | PASS / WARN | (details) |
| Error Handling | PASS / FAIL | (details with file:line) |

### Findings (by severity)

#### Critical
- (file:line) Description and remediation

#### High
- (file:line) Description and remediation

#### Medium / Low
- (summary)

### Verdict: PASS / FAIL (N critical, M high issues)
```

- **Critical/High issues**: Must fix before merge. Provide specific remediation code.
- **Medium/Low issues**: Recommended. Provide guidance.

## Safety Guards

- Never include discovered secrets in the output (mask with `***`)
- Report discovered secrets immediately with file location
- Do not modify files during review (read-only operation)
- Skip binary files and files larger than 1MB
