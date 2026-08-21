# .NET — Rules for Claude

Applies whenever `plan.md` records .NET as the backend. Read this file before implementing or reviewing any .NET task.

## Project setup

- Current LTS .NET version (match the existing repo's `TargetFramework` if one exists; don't silently bump it as part of an unrelated task).
- ASP.NET Core Web API for HTTP services. Minimal APIs for small/simple services; controller-based (`ControllerBase`) for anything with more than a handful of endpoints or that needs conventional filters/attributes.

## Structure

Layered, dependency pointing inward:

```
src/
├── Api/                  controllers or minimal-API endpoints, DTOs, request/response models
├── Application/          business logic, use cases, validation
├── Domain/                entities, value objects, domain interfaces — no framework references here
├── Infrastructure/       EF Core DbContext, repositories, external service clients
tests/
├── UnitTests/
└── IntegrationTests/
```

- Domain layer must not reference Infrastructure or Api. Dependencies point inward (Api → Application → Domain, Infrastructure implements Domain interfaces).
- One class per file, file name matches class name.

## Naming conventions

- PascalCase for classes, methods, properties, public fields. camelCase for locals and parameters. `_camelCase` for private fields.
- Interfaces prefixed with `I` (`ICustomerRepository`).
- Async methods suffixed with `Async` (`GetCustomerAsync`).

## API design

- RESTful routes, plural nouns (`/api/customers`, `/api/customers/{id}`).
- Use standard HTTP status codes correctly — 200/201/204 for success, 400 for validation, 401/403 for auth, 404 for missing, 409 for conflict. Don't return 200 with an error payload.
- Request/response DTOs are separate types from domain entities — never expose EF Core entities directly on the wire.
- Validate input with FluentValidation (or the repo's existing validation approach) at the Api boundary, before it reaches Application logic.

## Data access

- Entity Framework Core, code-first with migrations (`dotnet ef migrations add <name>`). Never hand-edit a generated migration to change its intent — add a new migration instead.
- Repository/interface pattern for anything beyond trivial CRUD, so Application logic depends on `IXxxRepository`, not `DbContext` directly.
- No business logic in the DbContext or entity classes — that belongs in Application.
- Use async EF Core calls (`ToListAsync`, `FirstOrDefaultAsync`, etc.) throughout — no blocking `.Result` or `.Wait()`.

## Dependency injection

- Register services in `Program.cs` (or a dedicated `ServiceCollectionExtensions`) with the narrowest lifetime that's correct: `Scoped` for anything using `DbContext`, `Singleton` only for genuinely stateless/thread-safe services, `Transient` sparingly.

## Error handling

- Centralized exception handling middleware translating domain/application exceptions to the correct HTTP status — don't try/catch the same boilerplate in every controller action.
- Never swallow an exception silently; log it with enough context to diagnose.

## Testing

- xUnit. `Moq` or `NSubstitute` for mocking (match whichever the repo already uses).
- Unit tests for Application/Domain logic with dependencies mocked. Integration tests (using `WebApplicationFactory` + a real or test-container database) for the Api layer's actual HTTP behavior.

## Do / Don't

- Do use `async`/`await` all the way down for I/O-bound code.
- Do keep controllers/endpoints thin — they call into Application, they don't contain business logic.
- Don't add a new NuGet package for something the BCL or an already-referenced package already covers.
- Don't change `TargetFramework`, global.json, or solution-wide settings as a side effect of an unrelated task — that's an architecture-level change per the Escalation Rules.
