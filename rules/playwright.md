# Playwright — Rules for Claude

Applies whenever a task's `QA:` field is `Playwright`. Read this file before writing or
running any E2E test. Binding on `qa-tester`; `task-planner` sets the field per
`task-streams.md`'s QA scoping rule; `reviewer` reads `qa-tester`'s report as part of the
task's evidence.

## Project setup

- Install once per repo: `npm install -D @playwright/test`, then
  `npx playwright install --with-deps` to fetch browsers.
- Config file `playwright.config.ts` at the repo root (or the frontend root in a
  parent+submodule layout — never the parent, which holds no app code per
  `git-workflow.md`).
- Config must capture evidence by default:
  ```ts
  export default defineConfig({
    use: { screenshot: 'on', video: 'retain-on-failure', trace: 'on-first-retry' },
    outputDir: '.claude-context/qa/<task-id>/artifacts',
  })
  ```
  One artifacts directory per task keeps evidence from colliding across tasks and matches
  the project's other `.claude-context/` conventions.
- Use the `webServer` option to start/stop the dev server automatically when the repo's dev
  command is known and boots fast; otherwise `qa-tester` starts it manually and tears it down
  itself.

## Folder structure

```
.claude-context/qa/<task-id>/
├── scenarios.md    positive / negative / edge case list — written before any test
├── report.md       pass/fail summary + bug entries
├── specs/          the Playwright spec file(s)
└── artifacts/       screenshots/, videos/, trace/ (Playwright's own output structure)
```

## Test case categories — derive all three before running anything

- **Positive** — the happy path named directly by the Acceptance Criterion.
- **Negative** — invalid input, a rejected action, an error state. Per
  `error-handling.md`'s envelope, assert the user-visible error message/state, not just that
  a request failed.
- **Edge** — boundaries and unusual-but-valid states: empty list, max pagination page size
  (per `api-design.md`), a field at its exact length limit, slow network (`page.route` with
  an injected delay), double-submit / rapid click.

Each scenario gets its own `test()` — never one test asserting multiple scenarios. A failure
in the second scenario must fail independently of the first, the same enumerate-the-population
principle as `guard-tests.md` §1.

## Selectors

Prefer `getByRole`, `getByLabel`, `getByText` — semantic queries that survive a markup
refactor. Use `data-testid` only when no semantic query exists. Never a CSS class or
`nth-child` selector — it breaks on a styling change unrelated to the behavior under test.

## Evidence capture

- Screenshot at each scenario's key assertion point, not only on failure —
  `page.screenshot({ path: ... })` — plus Playwright's automatic on-failure screenshot.
- Video: `retain-on-failure` by default. Keeping every video for every green run bloats the
  repo for no benefit past the current review cycle.
- Trace: `on-first-retry` — the most useful artifact for a flaky failure, too expensive to
  keep for every green run.

## Assertions

Assert on rendered output (`expect(page.getByText(...)).toBeVisible()`), never only that a
network call happened. The self-referential-assertion failure `guard-tests.md` §3 warns
against — a test that proves it called its own mock, not that the result reached the user —
applies to E2E exactly as much as unit tests.

Don't fast-forward past a real wait with an arbitrary `page.waitForTimeout()`. Use
`waitFor(...)` / `expect(...).toBeVisible()` polling instead — a fixed sleep is either too
slow (wastes time every run) or too fast (flaky under load), never reliably correct.

## Bugs found

Log every failing scenario as a discrete entry in `report.md`:

```
### BUG-<n>: <one-line summary>
Scenario: <positive|negative|edge> — <scenario name>
Steps: <numbered steps>
Expected: <what the AC says should happen>
Actual: <what happened>
Screenshot: artifacts/<path>
Video: artifacts/<path>
```

This is what the retry `developer` reads. A bug entry without a screenshot/video path is
incomplete, not brief.

## Starting and stopping the app

- Confirm the dev server's port isn't already bound before starting one — a collision here is
  not hypothetical, see `external-agents.md`'s runtime-isolation note. Use the port the repo's
  Stack Rules / README specify.
- Wait for actual readiness (poll the URL) before running tests — never sleep-and-hope.
- Tear down the server process you started when done, pass or fail. Never kill a process you
  did not start — another session or the developer's own `npm run dev` may hold that port for
  a real reason.

## Git hygiene

Add `.claude-context/qa/**/artifacts/` to the target repo's `.gitignore` — screenshots,
videos, and traces are evidence for the current review cycle, not durable history, and bloat
the repo fast. Commit `scenarios.md` and `report.md` — both are small text, and `report.md`
is the bug record a `developer` retry reads. `devops-engineer` adds the artifacts path to
`.gitignore` at bootstrap alongside `node_modules/`, `bin/`, `obj/`.

## Do / Don't

- Do run scenarios independently — one browser context per test, no shared mutable state a
  later scenario depends on an earlier one having run first.
- Do treat a scenario that can't be made to fail on a real regression the same way
  `guard-tests.md` treats any other guard that can't fail — not yet a guard.
- Don't add Playwright as a second E2E framework if the repo already has one (Cypress, Detox
  for React Native) — that's an architecture-level addition; escalate rather than introduce a
  competing framework silently.
- Don't run QA against the team's live/shared environment — same isolated-instance discipline
  `external-agents.md` requires for review clones applies here.
