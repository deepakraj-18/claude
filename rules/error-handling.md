# Error Handling Conventions

These conventions apply to all application code. `developer` must follow them during implementation; `reviewer` must check against them; `tester` must verify error behavior matches these patterns.

## Philosophy

- **Fail fast, fail loudly.** Swallowing errors silently is worse than crashing — it hides bugs and makes debugging impossible.
- **Users see friendly messages; logs see stack traces.** Never expose internal error details (stack traces, SQL errors, internal paths) to end users.
- **Errors are part of the contract.** Every endpoint/function that can fail must document how it fails — error responses are API surface, not afterthoughts.

## Error Response Shape (REST APIs)

All error responses must use this envelope:

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "The requested item could not be found.",
    "details": []
  }
}
```

- `code`: Machine-readable UPPER_SNAKE_CASE constant. Use standard codes:
  - `VALIDATION_ERROR` — input didn't pass validation
  - `RESOURCE_NOT_FOUND` — requested entity doesn't exist
  - `UNAUTHORIZED` — no valid auth credentials
  - `FORBIDDEN` — valid credentials but insufficient permissions
  - `CONFLICT` — action conflicts with current state (e.g. duplicate)
  - `RATE_LIMITED` — too many requests
  - `INTERNAL_ERROR` — unexpected server error (never expose details)
- `message`: Human-readable, user-safe description. No stack traces, no internal identifiers.
- `details`: Array of field-level errors (for validation), otherwise empty array.

## Validation Errors

Return all validation failures at once, not one at a time:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "One or more fields failed validation.",
    "details": [
      { "field": "email", "message": "Must be a valid email address." },
      { "field": "age", "message": "Must be at least 18." }
    ]
  }
}
```

## HTTP Status Code Mapping

| Code | Status | When |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Bad input |
| `UNAUTHORIZED` | 401 | Missing/invalid auth |
| `FORBIDDEN` | 403 | Valid auth, no permission |
| `RESOURCE_NOT_FOUND` | 404 | Entity doesn't exist |
| `CONFLICT` | 409 | Duplicate, state conflict |
| `RATE_LIMITED` | 429 | Throttled |
| `INTERNAL_ERROR` | 500 | Unexpected failure |

## Logging Levels

| Level | Use for | Example |
|---|---|---|
| **Debug** | Developer-only detail, disabled in production | Variable values, SQL queries, cache hits/misses |
| **Info** | Normal business events worth recording | User logged in, order placed, payment processed |
| **Warn** | Recoverable problems that deserve attention | Retry succeeded after failure, deprecated API called, rate limit approaching |
| **Error** | Failures that need investigation | Unhandled exception, external service down, data integrity violation |

**Rules:**
- Never log at Error for expected business conditions (e.g. "user not found" is Info or Warn, not Error).
- Never log sensitive data (passwords, tokens, PII) at any level.
- Always include correlation/request IDs in log entries for tracing.

## Exception Handling Patterns

### Do: Catch specific, handle specific
```
try {
    result = await externalService.call(data);
} catch (TimeoutException) {
    // Retry with backoff, or return a clear error
} catch (AuthException) {
    // Re-authenticate and retry once
}
```

### Don't: Catch-all-and-swallow
```
// ❌ NEVER DO THIS
try {
    doSomething();
} catch (Exception) {
    // silently ignored
}
```

### Don't: Catch-and-rethrow without adding context
```
// ❌ Pointless — adds a stack frame but no information
try {
    doSomething();
} catch (Exception ex) {
    throw ex;
}
```

## External Service Calls

For any call to an external service (API, database, message queue):
- **Set timeouts.** Never make unbounded calls. Default: 10s for APIs, 30s for database queries.
- **Retry with exponential backoff** for transient failures (503, 429, network errors). Max 3 retries.
- **Circuit breaker** for persistent failures — after 5 consecutive failures in 60 seconds, stop calling and return a degraded response for 30 seconds before retrying.
- **Log the failure** at Warn on retry, Error on circuit break.

## Global Error Handling

- Every application must have a **global error handler / middleware** that catches unhandled exceptions, logs them at Error with full stack trace, and returns a generic `INTERNAL_ERROR` response to the user.
- Never let raw stack traces reach the HTTP response.
- In development mode, the response MAY include the stack trace for debugging convenience — but this must be disabled in production via environment variable, not code comments.
