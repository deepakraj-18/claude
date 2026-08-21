# Performance Conventions

These conventions apply to all application code. `developer` must follow them during implementation; `reviewer` must flag violations; `tester` should verify performance-sensitive paths.

## N+1 Query Prevention (The #1 Performance Killer)

### Laravel / Eloquent
```php
// ❌ N+1: 1 query for rides + N queries for users
$rides = Ride::all();
foreach ($rides as $ride) {
    echo $ride->user->name;     // Triggers query per ride
}

// ✅ Eager loaded: 2 queries total
$rides = Ride::with('user', 'zone')->get();

// ✅ Nested eager loading
$rides = Ride::with('user.profile', 'zone.serviceLocation')->get();

// ✅ Conditional eager loading
$rides = Ride::when($includeDriver, fn($q) => $q->with('driver'))->get();
```

**Rule**: Enable `Model::preventLazyLoading()` in `AppServiceProvider::boot()` during development — it throws an exception on lazy loading, making N+1 queries impossible to miss.

### .NET / EF Core
```csharp
// ❌ N+1
var orders = await _context.Orders.ToListAsync();
foreach (var order in orders) {
    var customer = order.Customer;  // Lazy load per order
}

// ✅ Eager loaded
var orders = await _context.Orders
    .Include(o => o.Customer)
    .Include(o => o.OrderItems)
    .ToListAsync();
```

**Rule**: Disable lazy loading proxies. Use explicit `.Include()` always.

## Caching

### When to Cache
- **Configuration/settings** from DB — changes rarely, read on every request.
- **Lookup/reference data** — countries, currencies, vehicle types, zones.
- **Computed results** — pricing calculations, route distances (if inputs haven't changed).
- **API responses** — external service responses (geocoding, exchange rates).

### When NOT to Cache
- User-specific data that changes frequently (current ride status, wallet balance).
- Data that must be real-time (driver locations, live tracking).

### Cache Patterns

**Laravel**:
```php
// Cache for 60 minutes, auto-refresh
$zones = Cache::remember('zones:active', 3600, function () {
    return Zone::where('is_active', true)->get();
});

// Cache tags for group invalidation
Cache::tags(['zones'])->flush();  // Clear all zone caches
```

**General rules**:
- **Always set TTL** — never cache indefinitely without an invalidation strategy.
- **Cache key naming**: `{entity}:{scope}:{identifier}` — e.g., `zones:active`, `user:123:profile`.
- **Invalidate on write** — when data changes, clear or update the relevant cache.

## Database Query Optimization

### Use Pagination — Never Unbounded Queries
```php
// ❌ Loads entire table into memory
$rides = Ride::all();

// ✅ Paginated
$rides = Ride::where('status', 'COMPLETED')
    ->orderBy('created_at', 'desc')
    ->paginate(20);
```

### Select Only Needed Columns
```php
// ❌ SELECT * (loads all 30 columns including BLOBs)
$users = User::all();

// ✅ Select only what's needed
$users = User::select('id', 'name', 'email', 'is_online')->get();
```

### Use Database for Aggregation, Not PHP
```php
// ❌ Load all rows, count in PHP
$count = Ride::where('status', 'COMPLETED')->get()->count();

// ✅ COUNT in database
$count = Ride::where('status', 'COMPLETED')->count();

// ❌ Load all rows, sum in PHP
$total = Ride::where('driver_id', $id)->get()->sum('fare');

// ✅ SUM in database
$total = Ride::where('driver_id', $id)->sum('fare');
```

## API Response Optimization

- **Paginate all collection endpoints** — default 20, max 100.
- **Use resource transformers** to control what fields are returned — never expose full Eloquent models.
- **Compress responses** — enable gzip/brotli in the web server.
- **Use ETags / conditional requests** for data that doesn't change often.

## Frontend Bundle Size

- **Code splitting**: Use dynamic imports for routes/pages that aren't needed immediately.
  ```js
  // Vite + Vue lazy loading
  const AdminDashboard = () => import('./Pages/Admin/Dashboard.vue')
  ```
- **Tree shaking**: Import only what's needed from libraries.
  ```js
  // ❌ Imports entire library
  import _ from 'lodash'
  
  // ✅ Import only the function
  import debounce from 'lodash/debounce'
  ```
- **Image optimization**: Use WebP format, lazy loading (`loading="lazy"`), and appropriate sizes.

## Async Operations

- **Queue heavy work** — never block HTTP responses with email, SMS, PDF generation, or image processing. Use Laravel Jobs or .NET Background Services.
- **Set timeouts** on all external API calls (Stripe, Firebase, Maps) — default 10 seconds.
- **Debounce** search inputs and autocomplete — don't fire API calls on every keystroke.

## Real-Time Data (Ride Tracking, Driver Locations)

- Use **Firebase Realtime Database** or **WebSockets** for live data — never poll REST endpoints.
- **Batch location updates** — drivers send positions every 5-10 seconds, not on every GPS tick.
- **Use geohashing** for spatial proximity queries instead of calculating distances for every driver.

## Performance Monitoring Checklist

- [ ] No N+1 queries (enable `preventLazyLoading()` in dev)
- [ ] All collection endpoints are paginated
- [ ] Heavy operations are queued, not synchronous
- [ ] External API calls have timeouts set
- [ ] Database queries use indexes (verify with EXPLAIN)
- [ ] Frontend uses code splitting for large pages
- [ ] Images are optimized and lazy-loaded
