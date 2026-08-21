# React — Rules for Claude

Applies whenever `plan.md` records React as the frontend for web. Read this file before implementing or reviewing any React task.

## Project setup

- Scaffold with Vite (`npm create vite@latest -- --template react-ts`), not Create React App (unmaintained).
- TypeScript by default. Only use plain JS if the existing repo is already plain JS — don't introduce a second language convention mid-project.

## Structure

```
src/
├── components/     shared, reusable, no business logic
├── features/       one folder per feature; feature-local components/hooks/api live here
├── hooks/          shared custom hooks only
├── lib/            framework-agnostic utilities
├── api/            data-fetching layer (see Data fetching below)
└── App.tsx
```

- Co-locate a component's styles, tests, and types with the component, not in parallel top-level `styles/`, `tests/`, `types/` trees.
- One component per file. File name matches the component name (`UserCard.tsx` exports `UserCard`).

## Components

- Function components with hooks only. No class components.
- Props typed with an explicit `interface Props { ... }`, not inline object types, once a component has more than 1–2 props.
- Keep components under ~150 lines; extract a subcomponent or hook past that.
- No business logic inside JSX — pull conditionals/derivations into named variables or hooks above the return.

## State management

- Local state: `useState` / `useReducer`.
- Server state (anything from an API): React Query (`@tanstack/react-query`) — do not hand-roll fetch + useState + useEffect for data that comes from the backend.
- Global client state (rare — auth session, theme, feature flags): React Context, or Zustand if the state is large/frequently updated. Do not reach for Redux unless the existing repo already uses it.

## Data fetching

- All API calls go through `src/api/` — typed functions wrapping fetch/axios, never inline `fetch()` calls inside components.
- Types for API responses live next to the api function that returns them.

## Styling

- Match whatever the existing repo uses (Tailwind, CSS Modules, styled-components). If starting fresh: Tailwind for utility styling, CSS Modules for anything Tailwind can't express cleanly.
- No inline `style={{}}` except for values computed at runtime (e.g. dynamic positioning).

## Testing

- Vitest + React Testing Library.
- Test behavior (what the user sees/does), not implementation details — don't assert on internal state or call counts unless that's the actual contract being tested.
- Every component with conditional rendering or user interaction needs at least one test covering the interaction, per the Test Integrity Rule in `reviewer.md`.

## Do / Don't

- Do keep components pure — no side effects during render.
- Do use `key` props correctly on lists (stable IDs, never array index if the list can reorder).
- Don't prop-drill more than 2 levels — use composition or context instead.
- Don't add a new dependency for something React/the existing toolchain already solves.
