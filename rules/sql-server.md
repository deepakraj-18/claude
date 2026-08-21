# SQL Server — Rules for Claude

Applies whenever `plan.md` records SQL Server as the database. Read this file before implementing or reviewing any task that touches schema or queries.

## Schema conventions

- Table names: PascalCase, plural (`Customers`, `OrderLines`).
- Column names: PascalCase, singular (`CustomerId`, `EmailAddress`).
- Primary key: `Id` (`BIGINT IDENTITY` or `UNIQUEIDENTIFIER` — match whatever the existing schema uses; don't mix key strategies across tables in the same project without a stated reason).
- Foreign keys named `<ReferencedTable singular>Id` (`CustomerId` on `Orders` referencing `Customers`).
- Every table gets `CreatedAt` / `UpdatedAt` (`DATETIME2`, UTC) unless it's a pure lookup/reference table.

## Migrations

- Schema changes go through EF Core Migrations (`dotnet ef migrations add <name>`) when the backend is .NET/EF Core — never hand-edit the database directly outside a migration, including in local dev, so schema state stays reproducible.
- Migrations are additive and forward-only in shared/deployed environments — don't edit a migration that's already been applied elsewhere; write a new one.
- A migration that drops a column or table is a breaking change and requires explicit acknowledgement in the task's acceptance criteria, not something to do incidentally while implementing an unrelated feature.

## Constraints & integrity

- Foreign keys are real `FOREIGN KEY` constraints, not just application-level checks.
- `NOT NULL` by default; a column is nullable only when there's a real reason, and that reason should be documented in the migration or a schema comment.
- Uniqueness (e.g. unique email) enforced with a `UNIQUE` constraint/index at the database level, not only validated in application code — the database is the last line of defense against a race condition.

## Indexing

- Index every foreign key column.
- Index columns used in `WHERE`, `JOIN`, or `ORDER BY` on tables expected to grow past a few thousand rows.
- Don't add speculative indexes for queries that don't exist yet — every index has a write-cost; add them when a query needs them, not preemptively.

## Query rules

- Parameterized queries / EF Core LINQ only. No string-concatenated SQL, ever — this is a hard rule, not a style preference (SQL injection).
- Avoid `SELECT *` in application code — select the columns actually needed.
- Watch for N+1 query patterns from EF Core lazy loading — use `.Include()` or projection (`.Select()`) to fetch what's needed in one round trip.
- Wrap multi-statement writes that must succeed or fail together in an explicit transaction.

## Testing

- Integration tests that touch the database run against a real SQL Server instance (LocalDB, Docker container, or test container) — not an in-memory provider, since in-memory doesn't enforce constraints, indexes, or SQL Server-specific behavior the same way.
- A migration should be tested both ways where practical: applying it, and confirming the up-migration doesn't break existing data patterns used in tests.

## Do / Don't

- Do use `DATETIME2` for new datetime columns, not the legacy `DATETIME` type.
- Do keep migrations small and scoped to one logical schema change per task, matching the task-sizing rule in `task-planner.md`.
- Don't store computed values that can be derived from other columns unless there's a measured performance reason — that's a data-integrity risk (values drift out of sync).
- Don't use SQL Server-specific syntax gratuitously if the codebase has any stated goal of database portability — check `plan.md` for that constraint before assuming it doesn't apply.
