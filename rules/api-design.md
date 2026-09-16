# REST API Design Conventions

All REST endpoints. `developer` follows; `tester` writes tests against these contracts;
`reviewer` verifies.

## URLs

`/{version}/{resource}` — always version from day one (`/v1/`). Resources are plural nouns,
kebab-case for multi-word (`/v1/order-items`). Nest for ownership
(`/v1/users/{userId}/orders`) max 2 levels — beyond that, promote to a top-level resource
with a filter. No verbs in URLs, no trailing slash.

## Methods

| Method | Purpose | Idempotent | Body | Success |
|---|---|---|---|---|
| GET | retrieve | yes | no | 200 |
| POST | create | no | yes | 201 |
| PUT | full replace | yes | yes | 200 |
| PATCH | partial update | no | yes | 200 |
| DELETE | remove | yes | no | 204 |

## Response Envelope

Single: `{ "data": { ... } }`. Collection (always paginated):
`{ "data": [ ... ], "pagination": { "page", "pageSize", "totalItems", "totalPages" } }`.
Errors: the standard envelope in `error-handling.md`.

## Pagination

Default page size 20, max 100 (reject above with 400). `?page=1&pageSize=20`. Always return
pagination metadata, even for a single-page result. Never return an unpaginated collection
from a production endpoint.

## Filtering & Sorting

Filter with query params matching field names (`?status=active&role=admin`). Date ranges
`?createdAfter=...&createdBefore=...` (ISO 8601). Sort `?sort=name:asc,createdAt:desc`.
Full-text `?search=keyword`.

## Naming

Fields camelCase in JSON. Timestamps ISO 8601 with timezone (`2025-01-15T10:30:00Z`). IDs
are strings (UUID or prefixed like `usr_abc123`) — never expose auto-increment integers.
Booleans prefixed `is`/`has`/`can`. Enums UPPER_SNAKE_CASE in responses.

## Auth

`Authorization: Bearer <token>` — never API keys in query strings. 401 missing/invalid
token; 403 valid token, no permission. Don't leak existence: no permission → 403 not 404;
but a resource in another tenant → 404 (don't confirm it exists).

## Idempotency

POST accepts an optional `Idempotency-Key` header. PUT/DELETE are naturally idempotent —
deleting a non-existent resource returns 204, not 404.

## Rate Limiting

429 with `Retry-After` (seconds). Include `X-RateLimit-Limit` / `-Remaining` / `-Reset`
headers.

**Partition per client — never a global bucket.** ASP.NET Core's simple
`AddFixedWindowLimiter(name, opts => ...)` overload creates **one bucket shared by every
caller**, regardless of a comment claiming "per IP." One unauthenticated client sending
requests at the limit rate exhausts it and locks out every other user — this shipped on a
`/auth/login` and `/auth/refresh` pair before being caught, and the same pattern was found
pre-existing on five other endpoints in the same project. Partition explicitly:

```csharp
// ❌ global bucket — shared by every caller no matter what the comment says
services.AddRateLimiter(o => o.AddFixedWindowLimiter("login", opts => opts.PermitLimit = 5));

// ✅ partitioned per client
services.AddRateLimiter(o => o.AddPolicy("login", httpContext =>
    RateLimitPartition.GetFixedWindowLimiter(
        httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromMinutes(1) })));
```

A test suite built on one shared `HttpClient` cannot catch this — see `guard-tests.md` §1's
rate-limit case study. Verify with at least two distinct client identities and confirm one's
consumption never reduces another's quota.

## Versioning

URL-prefix (`/v1/`, `/v2/`). Breaking changes (field removal, type change, behaviour
change) require a new version; non-breaking additions (new optional field, new endpoint) go
in the current one. On retiring a version, send a `Sunset` header 90 days ahead.
