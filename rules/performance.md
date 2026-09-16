# Performance Conventions

Universal. `developer` follows; `reviewer` flags violations; `tester` verifies
performance-sensitive paths.

## N+1 Queries — the #1 killer

Never iterate a collection touching a relation per-item. Eager-load instead.

- **EF Core:** explicit `.Include(o => o.Customer).Include(o => o.OrderItems)`; disable lazy
  loading proxies.
- **Eloquent:** `Model::with('user', 'zone')->get()`; supports nested (`user.profile`) and
  conditional (`->when($flag, fn($q) => $q->with('driver'))`). Enable
  `Model::preventLazyLoading()` in dev so a lazy load throws.

## Caching

**Cache:** DB config/settings, lookup/reference data, expensive computed results, external
API responses (geocoding, exchange rates). **Don't cache:** frequently-changing
user-specific data (cart/wallet), anything that must be real-time (live locations).
**Rules:** always set a TTL; key as `{entity}:{scope}:{id}` (`zones:active`,
`user:123:profile`); invalidate on write.

## Database

- **Paginate everything** — never `Model::all()` / unbounded queries. Default 20, max 100.
- **Select only needed columns** — no `SELECT *` in application code.
- **Aggregate in the database** — `->count()` / `->sum('fare')`, never load rows and reduce
  in app code.
- Verify queries use indexes (`EXPLAIN` / execution plan).

## API responses

Paginate all collection endpoints; use resource transformers (never expose ORM entities
raw); enable gzip/brotli; use ETags / conditional requests for slow-changing data.

## Frontend bundle

Code-split routes/pages via dynamic import; import named functions not whole libraries
(`import debounce from 'lodash/debounce'`); WebP + `loading="lazy"` + right-sized images.

## Async & real-time

Queue heavy work (email, SMS, PDF, image processing) — never block an HTTP response. Set
timeouts on every external API call (default 10s). Debounce search/autocomplete inputs. For
live data use WebSockets / a realtime DB, not REST polling; batch location updates
(5–10s), geohash for proximity queries.

## Checklist

- [ ] No N+1 (lazy-loading guard on in dev)
- [ ] All collection endpoints paginated
- [ ] Heavy ops queued, not synchronous
- [ ] External calls have timeouts
- [ ] Queries hit indexes (EXPLAIN)
- [ ] Large pages code-split
- [ ] Images optimized + lazy-loaded
