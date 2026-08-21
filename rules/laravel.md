# Laravel Conventions (PHP 8.2+ / Laravel 12)

These conventions apply to all Laravel backend code. `developer` must follow them during implementation; `tester` must test against Laravel patterns; `reviewer` must verify compliance.

## Project Structure

```
app/
├── Console/Commands/       Artisan commands
├── Events/                 Domain events
├── Exceptions/             Custom exception classes
├── Helpers/                Trait-based helper logic (shared across controllers)
├── Http/
│   ├── Controllers/        Thin controllers — delegate to services
│   ├── Middleware/          Auth, locale, rate limiting
│   ├── Requests/           Form request validation classes
│   └── Resources/          API resource transformers (JSON responses)
├── Jobs/                   Queued jobs (notifications, heavy processing)
├── Listeners/              Event listeners
├── Mail/                   Mailable classes
├── Models/                 Eloquent models (one per table)
├── Notifications/          FCM, mail, SMS notification classes
├── Policies/               Authorization policies
├── Providers/              Service providers (bindings, boot logic)
└── Services/               Business logic classes (fat services, thin controllers)
```

## Controller Rules

- **Thin controllers.** Controllers validate input (via Form Requests), call a Service, and return a response. No business logic in controllers.
- **Resource controllers** for CRUD: `index`, `store`, `show`, `update`, `destroy`. Use `Route::apiResource()` for API, `Route::resource()` for web.
- **Inertia responses**: Return `Inertia::render('PageName', $props)` for web pages, not JSON.
- **API responses**: Return `JsonResource` or `ResourceCollection` classes, never raw arrays.

## Eloquent Model Rules

- **One model per table.** Models define `$fillable` (never `$guarded = []`), `$casts`, relationships, and scopes.
- **Eager loading**: Always use `with()` to prevent N+1 queries. Never lazy-load in loops.
- **Scopes**: Use local scopes (`scopeActive`, `scopeForZone`) for reusable query filters.
- **Accessors/Mutators**: Use `Attribute::make()` (Laravel 9+) for computed properties.
- **Soft deletes**: Use `SoftDeletes` trait on any model where data should be recoverable.
- **Spatial data**: Use `matanyadaev/laravel-eloquent-spatial` for geometry columns — don't use raw SQL for spatial queries.

## Validation

- **Always use Form Request classes** (`php artisan make:request`), never inline `$request->validate()` in controllers.
- **Authorize in the Form Request** via `authorize()` method, not in the controller.
- Return all validation errors at once (Laravel does this by default).

## Authentication & Authorization

- **Sanctum** for API token auth (mobile apps) and SPA session auth (Inertia).
- **Policies** for model-level authorization (`Gate::authorize`, `$this->authorize()`).
- **Middleware** for route-level auth (`auth:sanctum`, custom role middleware).
- Never check permissions in Eloquent models — that's the Policy's job.

## Queues & Jobs

- **Queue heavy work**: email, SMS, push notifications, PDF generation, image processing.
- Jobs must be **idempotent** — safe to retry on failure.
- Use `ShouldQueue` interface. Set `$tries`, `$backoff`, and `$timeout`.
- Failed jobs go to `failed_jobs` table — monitor it.

## Artisan Commands

- Use for scheduled tasks (cron): driver status checks, subscription expiry, cleanup.
- Register in `routes/console.php` or `app/Console/Kernel.php`.
- Commands should be thin — delegate to Services.

## Testing (PHPUnit)

- **Feature tests** for HTTP endpoints: `$this->getJson()`, `$this->postJson()`, `assertStatus()`, `assertJsonStructure()`.
- **Unit tests** for Services and Helpers.
- Use **factories and seeders** for test data, never hardcoded IDs.
- Use `RefreshDatabase` trait for test isolation.
- Mock external services (Stripe, Firebase, SMS) — never call real APIs in tests.

## Error Handling

- Custom exceptions extend `App\Exceptions\Handler`.
- API errors follow the envelope in `~/.claude/rules/error-handling.md`.
- Use `abort(404)`, `abort(403)` for HTTP errors — not raw exceptions.
- Log with context: `Log::error('Payment failed', ['user_id' => $user->id, 'amount' => $amount])`.

## Configuration & Environment

- **All secrets in `.env`**, never in code or config files.
- Access via `config('services.stripe.key')`, never `env()` directly in code (it doesn't work with cached config).
- Use `config/services.php` for third-party service credentials.

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Model | Singular PascalCase | `User`, `Request`, `ServiceLocation` |
| Table | Plural snake_case | `users`, `requests`, `service_locations` |
| Controller | PascalCase + Controller | `UserController`, `RequestController` |
| Migration | snake_case with timestamp | `2025_01_15_create_users_table` |
| Form Request | PascalCase + Request | `StoreUserRequest`, `UpdateRideRequest` |
| Job | PascalCase + Job | `SendPushNotificationJob` |
| Event | Past tense PascalCase | `RideCompleted`, `PaymentReceived` |
| Policy | Model + Policy | `UserPolicy`, `RequestPolicy` |
