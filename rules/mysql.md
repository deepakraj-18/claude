# MySQL Conventions

These conventions apply to all MySQL database work. `developer` must follow them for queries and migrations; `tester` must verify data integrity; `reviewer` must enforce query patterns.

## Migration Rules (Laravel)

### Creating Tables
```php
Schema::create('rides', function (Blueprint $table) {
    $table->id();                          // bigint unsigned auto-increment
    $table->foreignId('user_id')
          ->constrained()
          ->onDelete('cascade');           // Always explicit FK constraints
    $table->string('status', 50);          // Specify length, don't use default 255
    $table->decimal('fare', 10, 2);        // Precise money — never float
    $table->point('pickup_location')
          ->spatialIndex();                // Spatial index for geometry
    $table->timestamps();                  // created_at, updated_at
    $table->softDeletes();                 // deleted_at

    $table->index(['status', 'created_at']); // Composite index for common queries
});
```

### Zero-Downtime Migration Rules
- **New columns must be NULLable or have a DEFAULT**. Never add `NOT NULL` without a default to a populated table.
- **Never rename or drop columns in one step.** Use multi-phase deprecation (see `~/.claude/rules/db-migration.md`).
- **Never change column types on large tables** without a phased migration — `ALTER TABLE MODIFY` locks the table in MySQL < 8.0.
- **Batch large data updates** in chunks of 1000 rows to avoid long locks:
  ```php
  User::where('status', 'old')->chunkById(1000, function ($users) {
      foreach ($users as $user) {
          $user->update(['status' => 'new']);
      }
  });
  ```

## Indexing Guidelines

### Always Index
- **Foreign key columns** (`user_id`, `driver_id`, `zone_id`) — unindexed FKs cause full table scans on JOINs.
- **Status/flag columns** used in WHERE clauses (`status`, `is_active`, `is_online`).
- **Timestamp columns** used for sorting or filtering (`created_at`, `completed_at`).

### Spatial Indexes
- Use `SPATIAL INDEX` on `POINT`, `POLYGON`, `GEOMETRY` columns.
- Query with `ST_Within()`, `ST_Distance_Sphere()`, `ST_Contains()` — never raw lat/lng math in PHP.
- Use `matanyadaev/laravel-eloquent-spatial` package for Eloquent integration.

### Composite Indexes
- Order columns by **selectivity** (most selective first): `INDEX(user_id, status)` not `INDEX(status, user_id)`.
- Match the order of your `WHERE` clause for the index to be used.
- MySQL uses **leftmost prefix** — `INDEX(a, b, c)` covers queries on `(a)`, `(a, b)`, `(a, b, c)` but NOT `(b)` or `(c)` alone.

### Don't Over-Index
- Every index slows INSERT/UPDATE. High-write tables (ride tracking, location updates) should have minimal indexes.
- Use `EXPLAIN` to verify indexes are actually used before adding new ones.

## Query Patterns

### Use Eager Loading (Prevent N+1)
```php
// ❌ N+1: 1 query for rides + N queries for users
$rides = Ride::all();
foreach ($rides as $ride) {
    echo $ride->user->name;  // Triggers a query per ride
}

// ✅ Eager loaded: 2 queries total
$rides = Ride::with('user')->get();
```

### Use Query Builder for Complex Queries
```php
// For reports, aggregations, spatial queries — use query builder, not Eloquent
DB::table('requests')
    ->select('zone_id', DB::raw('COUNT(*) as ride_count'), DB::raw('AVG(fare) as avg_fare'))
    ->where('status', 'COMPLETED')
    ->whereBetween('created_at', [$start, $end])
    ->groupBy('zone_id')
    ->get();
```

### Money — Always DECIMAL, Never FLOAT
```php
$table->decimal('fare', 10, 2);        // ✅ Exact
$table->decimal('commission', 10, 4);  // ✅ For percentages
$table->float('fare');                 // ❌ Floating point rounding errors
```

## Charset & Collation

- **Default charset**: `utf8mb4` (supports emoji and all Unicode).
- **Default collation**: `utf8mb4_unicode_ci` (case-insensitive, accent-insensitive).
- Set in `config/database.php`, not per-table.

## Connection & Timeout

- **Query timeout**: Set `options` in `config/database.php`:
  ```php
  'options' => [
      PDO::ATTR_TIMEOUT => 30,  // 30 second query timeout
  ]
  ```
- **Connection pooling**: Use persistent connections for high-traffic apps.
- **Read replicas**: Use Laravel's `read`/`write` split for heavy-read workloads.

## Differences from SQL Server

| Topic | MySQL | SQL Server |
|---|---|---|
| Auto-increment | `$table->id()` (BIGINT UNSIGNED) | `IDENTITY(1,1)` |
| Spatial | `POINT`, `ST_Distance_Sphere()` | `geography`, `.STDistance()` |
| JSON | Native `JSON` type, `->` operator | `NVARCHAR(MAX)` + `JSON_VALUE()` |
| Stored procs | `DELIMITER //` syntax | `CREATE PROCEDURE` |
| Case sensitivity | Depends on collation | Case-insensitive by default |
| Migrations | Laravel `Schema::` | EF Core `Migration` classes |
| Boolean | TINYINT(1) | BIT |
