# Constants & Static Data Conventions

**Binding on all agents.** `developer` follows it; `reviewer` rejects any PR that scatters
hardcoded values; `tester` imports constants from the central file, never redeclares them.

## Core Rule

**All hardcoded values, seed data, UI static data, enums, config constants, and magic
numbers live in a single constants file per component.** Never scattered across
controllers, components, models, or views.

## File Locations

| Stack | File | Format |
|---|---|---|
| Laravel (PHP) | `app/Constants/AppConstants.php` | static class, `const` |
| .NET (C#) | `src/{Project}.Domain/Constants/AppConstants.cs` | static class, `const`/`readonly` |
| Vue / React (JS/TS) | `src/constants/index.ts` | named exports |
| React Native | `src/constants/index.ts` | named exports |

Past ~300 lines, split into focused files in the same directory (`statuses.ts`, `roles.ts`,
`ui.ts`, `config.ts`) with `index.ts` re-exporting.

## What Goes In It

Business enums & statuses (plus their label/color maps); UI dropdown options & labels;
roles & permissions (and the array of all of them); config limits & magic numbers
(`MAX_RETRY_ATTEMPTS`, `DEFAULT_PAGE_SIZE = 20`, `MAX_PAGE_SIZE = 100`, OTP expiry, search
radius, timeouts, upload caps); seed/reference data (default + supported currency, language,
timezone). For any enum, export both the values and a companion labels map and, where UI
needs it, a colors map — keyed off the same constant, never re-typed literals.

## What Does NOT Go In It

- Secrets (API keys, passwords, tokens) → `.env` only
- Environment-specific config (DB host, port, URLs) → `.env` / `config/`
- Dynamic data fetched from the DB at runtime (zone lists, pricing tiers)
- Translations / i18n strings → language files

## Rules for Agents

**`developer`** — before writing any hardcoded string/number/array in a
controller/component/model, check the constants file; if absent, add it there and import,
never inline. The constants file is in `Relevant Files` for every task — read it first.

**`reviewer`** — FAIL any task containing: a string literal used as a status/role/enum in
logic (`if ($status === 'completed')` instead of `AppConstants::RIDE_COMPLETED`); a magic
number without a named constant (`->take(20)` instead of `->take(DEFAULT_PAGE_SIZE)`);
dropdown options/labels hardcoded in a component instead of imported; duplicate constant
definitions across files.

**`tester`** — import constants in tests, never redeclare. `$status = 'COMPLETED'` instead
of `AppConstants::RIDE_COMPLETED` won't break when the value changes — which defeats the
point.

**`task-planner`** — always include the constants file in `Relevant Files`.
