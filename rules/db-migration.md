# Database Migration Safety Conventions

These conventions apply to all database schema changes across any stack (Laravel Migrations, EF Core, raw SQL). `developer` must follow them when modifying schemas; `reviewer` must enforce non-breaking migration rules.

## Core Principle

**All schema changes must allow the old code and new code to run concurrently against the database during deployment.** A migration that breaks the currently-deployed version is a production outage.

## Non-Breaking Changes (Safe)

### Adding Columns
- New columns **must be NULLable** or have a **DEFAULT constraint**.
- Never add a `NOT NULL` column without a default to a populated table.
- **Laravel**: `$table->string('nickname')->nullable();`
- **EF Core**: `.HasDefaultValue("unknown")` or `.IsRequired(false)`

### Adding Tables
- Always safe — no existing code references the new table.

### Adding Indexes
- Safe on small-to-medium tables. On large tables (1M+ rows), create indexes with `CONCURRENTLY` (PostgreSQL) or schedule during low-traffic windows (MySQL/SQL Server lock the table during index creation).

## Breaking Changes (Require Multi-Phase Approach)

### Renaming Columns
1. **Phase 1 (Release N)**: Add new column. Code writes to BOTH old and new, reads from NEW.
2. **Phase 2 (Release N+1)**: Backfill old → new for historical data.
3. **Phase 3 (Release N+2)**: Code reads/writes exclusively from NEW.
4. **Phase 4 (Release N+3)**: Drop old column.

### Dropping Columns
- **Never drop in the same release where code stops using it.**
- Release N: Remove code references. Release N+1: Drop the column.

### Changing Column Types
- Add a new column with the target type, backfill, switch code, then drop old. Never `ALTER COLUMN` in-place on large tables.

### Renaming Tables
- Same multi-phase approach as renaming columns. Create a view with the old name as a bridge if needed.

## Indexing Guidelines

### Always Index
- **Foreign keys** — unindexed FKs cause lock escalation and slow JOINs.
- **Status/flag columns** in WHERE clauses (`status`, `is_active`).
- **Timestamp columns** used for ORDER BY or date-range filtering.

### Composite Index Rules
- Order by **selectivity** (most unique values first).
- Match the order of WHERE clause columns.
- MySQL: leftmost prefix rule — `INDEX(a,b,c)` covers `(a)`, `(a,b)`, `(a,b,c)` but NOT `(b)` alone.
- SQL Server: similar behavior with included columns.

### Don't Over-Index
- Each index slows writes. High-write tables should have minimal indexes.
- Use `EXPLAIN` (MySQL) or execution plans (SQL Server) to verify indexes are used.

## Large Data Migrations

- **Always batch** — update in chunks of 1000 rows max.
- **Never** run unbounded `UPDATE ... SET` on large tables — it locks the entire table.
- For millions of rows, run the migration as a background job, not in the deployment pipeline.

## Rollback Strategy

Every migration must have a rollback plan:
- **Laravel**: Implement `down()` method in every migration.
- **EF Core**: Test rollback with `dotnet ef database update <previous-migration>`.
- **Raw SQL**: Write a companion `rollback.sql` script.

## Pre-Deploy Checklist

- [ ] Migration runs while current app version is still serving traffic?
- [ ] New columns are NULLable or have defaults?
- [ ] No column/table renames or drops without multi-phase plan?
- [ ] Foreign keys are indexed?
- [ ] Large data updates are batched?
- [ ] Rollback script exists and has been tested?
- [ ] Migration has been tested on a copy of production data (not just empty dev DB)?
