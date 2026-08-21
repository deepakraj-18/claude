# Constants & Static Data Conventions

**Binding on all agents.** `developer` must follow this when implementing; `reviewer` must reject any PR that scatters hardcoded values; `tester` must import constants from the central file, not redeclare them.

## Core Rule

**All hardcoded values, seed data, UI static data, enums, configuration constants, and magic numbers must live in a single constants file per component.** Never scatter them across controllers, components, models, or views.

## File Locations

| Stack | Constants File | Format |
|---|---|---|
| **Laravel** (PHP) | `app/Constants/AppConstants.php` | Static class with `const` |
| **.NET** (C#) | `src/{Project}.Domain/Constants/AppConstants.cs` | Static class with `const` / `readonly` |
| **Vue / React** (JS/TS) | `src/constants/index.ts` (or `index.js`) | Named exports |
| **React Native** | `src/constants/index.ts` | Named exports |

If the constants file grows past ~300 lines, split into focused files within the same directory:
```
constants/
├── index.ts          ← re-exports everything
├── statuses.ts       ← ride statuses, order statuses
├── roles.ts          ← user roles, permissions
├── ui.ts             ← colors, labels, dropdown options
└── config.ts         ← limits, timeouts, feature flags
```

## What Goes in the Constants File

### 1. Business Enums & Statuses
```php
// Laravel
class AppConstants {
    // Ride statuses
    const RIDE_REQUESTED = 'REQUESTED';
    const RIDE_ACCEPTED = 'ACCEPTED';
    const RIDE_DRIVING_TO_PICKUP = 'DRIVING_TO_PICKUP';
    const RIDE_TRIP_STARTED = 'TRIP_STARTED';
    const RIDE_COMPLETED = 'COMPLETED';
    const RIDE_CANCELLED = 'CANCELLED';

    const RIDE_STATUSES = [
        self::RIDE_REQUESTED,
        self::RIDE_ACCEPTED,
        self::RIDE_DRIVING_TO_PICKUP,
        self::RIDE_TRIP_STARTED,
        self::RIDE_COMPLETED,
        self::RIDE_CANCELLED,
    ];
}
```

```typescript
// Vue / React
export const RIDE_STATUS = {
  REQUESTED: 'REQUESTED',
  ACCEPTED: 'ACCEPTED',
  DRIVING_TO_PICKUP: 'DRIVING_TO_PICKUP',
  TRIP_STARTED: 'TRIP_STARTED',
  COMPLETED: 'COMPLETED',
  CANCELLED: 'CANCELLED',
} as const;

export const RIDE_STATUS_LABELS: Record<string, string> = {
  [RIDE_STATUS.REQUESTED]: 'Requested',
  [RIDE_STATUS.ACCEPTED]: 'Accepted',
  [RIDE_STATUS.DRIVING_TO_PICKUP]: 'Driving to Pickup',
  [RIDE_STATUS.TRIP_STARTED]: 'Trip Started',
  [RIDE_STATUS.COMPLETED]: 'Completed',
  [RIDE_STATUS.CANCELLED]: 'Cancelled',
};
```

### 2. UI Dropdown Options & Labels
```typescript
export const VEHICLE_TYPES = [
  { value: 'sedan', label: 'Sedan' },
  { value: 'suv', label: 'SUV' },
  { value: 'bike', label: 'Bike' },
  { value: 'auto', label: 'Auto Rickshaw' },
];

export const PAYMENT_METHODS = [
  { value: 'cash', label: 'Cash' },
  { value: 'wallet', label: 'Wallet' },
  { value: 'card', label: 'Card' },
  { value: 'upi', label: 'UPI' },
];
```

### 3. Roles & Permissions
```php
const ROLE_ADMIN = 'admin';
const ROLE_DISPATCHER = 'dispatcher';
const ROLE_DRIVER = 'driver';
const ROLE_USER = 'user';

const ROLES = [self::ROLE_ADMIN, self::ROLE_DISPATCHER, self::ROLE_DRIVER, self::ROLE_USER];
```

### 4. Configuration Limits & Magic Numbers
```php
const MAX_RETRY_ATTEMPTS = 3;
const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;
const OTP_EXPIRY_MINUTES = 10;
const DRIVER_SEARCH_RADIUS_KM = 5;
const SURGE_MULTIPLIER_MAX = 3.0;
const SESSION_TIMEOUT_MINUTES = 120;
const MAX_FILE_UPLOAD_MB = 10;
```

### 5. Seed / Reference Data
```php
const DEFAULT_CURRENCY = 'INR';
const SUPPORTED_CURRENCIES = ['INR', 'USD', 'EUR', 'GBP'];
const DEFAULT_LANGUAGE = 'en';
const SUPPORTED_LANGUAGES = ['en', 'hi', 'ta', 'te'];
const DEFAULT_TIMEZONE = 'Asia/Kolkata';
```

### 6. UI Colors / Status Colors (for badges, charts)
```typescript
export const STATUS_COLORS: Record<string, string> = {
  REQUESTED: '#FFA500',
  ACCEPTED: '#3B82F6',
  DRIVING_TO_PICKUP: '#8B5CF6',
  TRIP_STARTED: '#10B981',
  COMPLETED: '#22C55E',
  CANCELLED: '#EF4444',
};
```

## What Does NOT Go in the Constants File

- **Secrets** (API keys, passwords, tokens) → `.env` file only
- **Environment-specific config** (DB host, port, URLs) → `.env` or `config/` files
- **Dynamic data** fetched from the database at runtime (e.g., zone list, pricing tiers)
- **Translations / i18n strings** → language files (`resources/lang/`, `locales/`)

## Rules for Agents

### `developer`
- Before writing any hardcoded string, number, or array in a controller/component/model, check if it exists in the constants file first.
- If it doesn't exist, **add it to the constants file and import it** — never inline the value.
- The constants file is part of `Relevant Files` for every task. Always read it before implementing.

### `reviewer`
- **FAIL any task** that contains:
  - A string literal used as a status, role, or enum in application logic (e.g., `if ($status === 'completed')` instead of `if ($status === AppConstants::RIDE_COMPLETED)`)
  - A magic number without a named constant (e.g., `->take(20)` instead of `->take(AppConstants::DEFAULT_PAGE_SIZE)`)
  - Dropdown options or labels hardcoded in a Vue/React component instead of imported from `constants/`
  - Duplicate constant definitions across multiple files

### `tester`
- Import constants from the constants file in tests — never redeclare them. If a test says `$status = 'COMPLETED'` instead of `$status = AppConstants::RIDE_COMPLETED`, the test won't break when the constant value changes.

### `task-planner`
- Always include the constants file in `Relevant Files` for every task, since any task might need to reference or add constants.
