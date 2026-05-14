# Security Checklist

Use this checklist when implementing or reviewing any change that touches data ingestion, authentication, authorization, external dependencies, or user-facing output.

---

## 1. Input Validation at Trust Boundaries

A **trust boundary** is any point where data enters the process from outside — HTTP requests, CLI arguments, environment variables, file reads, queue messages, webhook payloads, IPC, and inter-service calls all cross a trust boundary.

- Validate type, shape, and acceptable value range at the boundary, before passing data into application logic.
- Reject or sanitize inputs that do not conform to the expected schema; do not pass raw unvalidated data deeper into the call stack.
- Treat every caller as untrusted unless a specific, auditable trust relationship has been established.

---

## 2. Secret and Credential Handling

- **Never log secrets.** Redact or omit credentials, tokens, passwords, and keys from all log output, error messages, and stack traces.
- **Never embed secrets in source code.** Hard-coded credentials must be removed immediately and the secret rotated.
- **Prefer env vars or a secret store.** Pass secrets through environment variables at runtime or retrieve them from a dedicated secret management service (e.g., Vault, AWS Secrets Manager). Do not commit `.env` files containing real secrets.

---

## 3. Parameterized Queries

- **No string interpolation into SQL.** Always use parameterized statements or prepared queries; never concatenate user-supplied values into a query string.
- **No string interpolation into shell commands.** Use argument arrays (e.g., `subprocess(['cmd', arg])` not `subprocess(f'cmd {arg}')`) to prevent command injection.
- This rule applies equally to NoSQL query filters, LDAP filters, and any other interpreted query language.

---

## 4. Output Encoding

- **Escape user-controlled data for the target surface before rendering.**
  - HTML: escape `<`, `>`, `&`, `"`, `'`; use a templating engine with auto-escaping enabled.
  - JSON: serialize through a library; never build JSON strings by hand from user input.
  - Shell: pass values as discrete arguments; never interpolate into a command string.
- Apply encoding at the final rendering layer, not at ingestion time, to avoid double-encoding errors.

---

## 5. AuthN / AuthZ Checks

- **Verify authentication and authorization on every touched endpoint.** Do not assume a request is authenticated because it arrived through a particular route or middleware chain.
- **Do not inherit assumed identity from the calling context.** Re-check permissions using the identity present in the current request, not a cached or ambient identity from an outer scope.
- When adding a new endpoint or modifying an existing one, confirm that both the authentication check (who are you?) and the authorization check (are you allowed to do this?) are in place and correct.

---

## 6. Dependency Trust

- **No unverified new packages.** Before adding a dependency, confirm it is actively maintained, has no known critical vulnerabilities, and comes from an expected registry.
- **Pin versions where practical.** Lock files (e.g., `package-lock.json`, `Cargo.lock`, `requirements.txt` with pinned versions) prevent silent upgrades that could introduce vulnerabilities.
- Audit new transitive dependencies; a direct dependency with a malicious or compromised transitive dep is still a risk.

---

## 7. External Data is Untrusted

Any data that originates outside the current process or service is untrusted, regardless of how it arrived.

This explicitly includes:

- Parsed input from HTTP requests, files, streams, or message queues.
- URL parameters and path segments.
- File contents read from paths that are user-supplied or outside the application's controlled directory.
- UI surfaces that display data fetched from external systems (apply output encoding; do not assume the source is safe).

Never promote external data to a trusted status without explicit validation against a defined schema or allowlist.
