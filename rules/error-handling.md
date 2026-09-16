# Error Handling Conventions

Universal. `developer` follows; `reviewer` checks; `tester` verifies error behaviour.

## Philosophy

Fail fast, fail loudly — a silently swallowed error is worse than a crash. Users see
friendly messages; logs see stack traces — never leak stack traces, SQL errors, or internal
paths to end users. Error responses are API surface: every fallible endpoint documents how
it fails.

## Error Response Envelope (REST)

```json
{ "error": { "code": "RESOURCE_NOT_FOUND", "message": "The requested item could not be found.", "details": [] } }
```

- `code` — UPPER_SNAKE_CASE. Standard set: `VALIDATION_ERROR`, `RESOURCE_NOT_FOUND`,
  `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`, `RATE_LIMITED`, `INTERNAL_ERROR`.
- `message` — user-safe, no internal identifiers.
- `details` — array of `{ "field": ..., "message": ... }` for validation, else `[]`.

**Validation:** return all failures at once in `details`, not one at a time.

## Status Code Mapping

| Code | Status |
|---|---|
| `VALIDATION_ERROR` | 400 |
| `UNAUTHORIZED` | 401 |
| `FORBIDDEN` | 403 |
| `RESOURCE_NOT_FOUND` | 404 |
| `CONFLICT` | 409 |
| `RATE_LIMITED` | 429 |
| `INTERNAL_ERROR` | 500 |

## Logging Levels

- **Debug** — dev-only detail (variable values, SQL, cache hits), off in production.
- **Info** — normal business events (login, order placed, payment processed).
- **Warn** — recoverable problems (retry succeeded, deprecated API called, nearing rate limit).
- **Error** — failures needing investigation (unhandled exception, external service down,
  data integrity violation).

Never log Error for an expected business condition ("user not found" is Info/Warn). Never
log secrets or PII at any level. Always include a correlation/request ID.

## Exception Patterns

- **Do** catch specific and handle specific (`TimeoutException` → retry with backoff;
  `AuthException` → re-auth and retry once).
- **Never** catch-all-and-swallow (`catch (Exception) { }`).
- **Never** catch-and-rethrow with no added context (`catch (ex) { throw ex; }`) — pure
  noise.

## External Service Calls

Set timeouts (default 10s API, 30s DB) — no unbounded calls. Retry transient failures (503,
429, network) with exponential backoff, max 3. Circuit-break on persistent failure: after 5
consecutive fails in 60s, stop and return degraded for 30s. Log Warn on retry, Error on
circuit break.

## Global Handler

Every app has global exception middleware: logs unhandled exceptions at Error with full
stack trace, returns a generic `INTERNAL_ERROR` to the client. Raw stack traces never reach
the HTTP response. Dev mode may include the trace — toggled by environment variable, not a
code comment.
