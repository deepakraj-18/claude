# REST API Design Conventions

These conventions apply to all REST API endpoints. `developer` must follow them during implementation; `tester` must write tests against these contracts; `reviewer` must verify compliance.

## URL Structure

```
/{version}/{resource}
```

- **Version prefix**: `/v1/`, `/v2/` etc. Always version from day one — retrofitting is painful.
- **Resources are plural nouns**: `/v1/users`, `/v1/orders`, `/v1/products`
- **Kebab-case** for multi-word resources: `/v1/order-items`, `/v1/user-profiles`
- **Nesting for ownership**: `/v1/users/{userId}/orders` — but max 2 levels deep. Beyond that, promote to a top-level resource with a filter.
- **No verbs in URLs**: Use HTTP methods, not `/getUser` or `/createOrder`.
- **No trailing slashes**: `/v1/users` not `/v1/users/`

## HTTP Methods

| Method | Purpose | Idempotent | Request body | Success status |
|---|---|---|---|---|
| GET | Retrieve resource(s) | Yes | No | 200 |
| POST | Create new resource | No | Yes | 201 |
| PUT | Full replace of resource | Yes | Yes | 200 |
| PATCH | Partial update | No | Yes | 200 |
| DELETE | Remove resource | Yes | No | 204 |

## Request/Response Envelope

### Single resource response
```json
{
  "data": {
    "id": "abc-123",
    "name": "Example",
    "createdAt": "2025-01-15T10:30:00Z"
  }
}
```

### Collection response (always paginated)
```json
{
  "data": [
    { "id": "abc-123", "name": "Example 1" },
    { "id": "def-456", "name": "Example 2" }
  ],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalItems": 142,
    "totalPages": 8
  }
}
```

### Error response
See `~/.claude/rules/error-handling.md` — all error responses use the standard error envelope.

## Pagination

- **Default page size**: 20 items
- **Max page size**: 100 items (reject requests above this with 400)
- **Query params**: `?page=1&pageSize=20`
- **Always return pagination metadata** in collection responses, even if total fits in one page.
- **Never return unpaginated collections** in production endpoints — even if "there will only be a few" today.

## Filtering & Sorting

- **Filtering**: Use query params matching field names: `?status=active&role=admin`
- **Date ranges**: `?createdAfter=2025-01-01&createdBefore=2025-02-01` (ISO 8601)
- **Sorting**: `?sort=createdAt:desc` or `?sort=name:asc,createdAt:desc` for multi-field
- **Search**: `?search=keyword` for full-text search across relevant fields

## Naming Conventions

- **Fields**: camelCase in JSON (`firstName`, `createdAt`, `orderItems`)
- **Timestamps**: ISO 8601 with timezone: `2025-01-15T10:30:00Z`
- **IDs**: String type (UUIDs or prefixed IDs like `usr_abc123`), never expose auto-increment integers
- **Booleans**: Prefix with `is`, `has`, `can`: `isActive`, `hasPermission`, `canEdit`
- **Enums**: UPPER_SNAKE_CASE in responses: `"status": "IN_PROGRESS"`

## Authentication & Authorization

- **Auth header**: `Authorization: Bearer <token>` — no API keys in query strings
- **401 Unauthorized**: Missing or invalid token
- **403 Forbidden**: Valid token but insufficient permissions
- **Never leak existence** through auth errors: if a user doesn't have permission to access a resource, return 403, not 404. But if the resource is tenant-scoped and the user is in a different tenant, return 404 (don't confirm the resource exists in another tenant).

## Idempotency

- **POST requests** should accept an optional `Idempotency-Key` header for safe retries
- **PUT and DELETE** are naturally idempotent — ensure implementations honor this (deleting a non-existent resource returns 204, not 404)

## Rate Limiting

- Return `429 Too Many Requests` with `Retry-After` header (seconds)
- Include rate limit info in response headers:
  ```
  X-RateLimit-Limit: 100
  X-RateLimit-Remaining: 42
  X-RateLimit-Reset: 1620000000
  ```

## Versioning Strategy

- **URL prefix versioning**: `/v1/`, `/v2/`
- **Breaking changes require a new version** — field removals, type changes, behavior changes
- **Non-breaking changes** can be added to the current version: new optional fields, new endpoints
- **Deprecation**: When retiring a version, return `Sunset` header with deprecation date for 90 days before removal
