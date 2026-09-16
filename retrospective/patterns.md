# Global Quality Patterns

Cross-project failure patterns logged by `quality-logger` agent.

**How to use this file:**
- Any pattern with `Count ≥ 2` is a signal that a rule or agent brief has a structural gap — fix it.
- Use the `/learn` slash command or manually edit the relevant rule/agent file.
- Mark fixed patterns `✅ Fixed` and note what changed.
- **`RULE-MISS`/`AGENT-BRIEF` patterns are tracked per `Produced by`, not collapsed across
  tools** — see `~/.claude/rules/external-agents.md`. An Antigravity instruction-miss and a
  later Cursor instruction-miss are separate patterns even with an identical symptom;
  merging them points a fix at the wrong file (a tool-specific quirk belongs in that
  repo's own `AGENTS.md` §5, not a global rule change). Entries predating this convention
  have no `Produced by` field — treat those as `unknown`, not as `internal`.

---

<!-- quality-logger appends patterns below this line -->

### [PATTERN-005] AC naming multiple paths but test covering only one path (sampling vs. enumeration)

**Root cause category:** RULE-MISS
**Produced by:** internal (tester)
**Affected rule/agent:** `~/.claude/rules/guard-tests.md` § 1 (Enumerate the population)
**Count:** 1 occurrence
**Projects affected:** Kurunji backend
**Tasks:** BD004 (Kurunji backend — Settings flow)
**Status:** ✅ Fixed — 2026-09-16: added the AC-enumeration example and rate-limit case study
to `guard-tests.md` §1; added an explicit "Test coverage: [path → test name]" sub-item
requirement to `task-planner.md`'s new Acceptance criteria discipline section; added a
matching per-path test step to `tester.md`'s job list and its guard-tests summary.

**Pattern description:**
Acceptance criterion explicitly names multiple state/path variations (e.g., "action X from State A or State B returns to menu"), implementation handles all variations correctly, but test coverage only exercises one representative case. Guard test passes despite missing coverage for the second path; regression injected into the second path alone does not fail the suite. Example: BD004 AC #8 named both Settings and SettingsAddress states; test only covered Settings. Reviewer proved the gap by deleting the SettingsAddress branch and observing all 12 tests still passed.

This violates `guard-tests.md` rule #1: "Enumerate the population — never sample it." When an AC lists N paths separated by "or" or commas, each path is part of the population and needs its own test case.

**Recommended fix:**
1. **Clarify `guard-tests.md` § 1:** Add concrete example showing AC with multiple paths and proper enumeration:
   - ❌ AC: "back_to_menu from Settings or SettingsAddress returns to menu" → 1 test (sampling)
   - ✅ AC: "back_to_menu from Settings or SettingsAddress returns to menu" → 2 tests (enumerate both)
2. **Task-planner template:** When creating test-coverage acceptance criteria, add a sub-item "Test coverage: [list each path/state variation and the test name that exercises it]" to force explicit enumeration into the AC.
3. **Tester agent brief:** Add step before completing a task: "For each path named in an AC with 'or' or multiple variations, confirm ≥1 dedicated test per path. Inject regression in each path alone; each must fail."

**Last seen:** 2026-09-14 (Kurunji backend BD004, SettingsFlowTests.cs guard test)

---

### [PATTERN-004] Developer does not follow explicit fallback branching instructions

**Root cause category:** RULE-MISS
**Affected rule/agent:** Task description not followed; developer agent brief may need clarification on verification step
**Affected project:** SIMS frontend (spear_sims_frontend)
**Count:** 1 occurrence
**Projects affected:** SIMS frontend
**Tasks:** TASK-017 (Razorpay payment flow)
**Status:** ✅ Fixed — 2026-09-16: added a fallback-base-branch verification step to
`developer.md` step 4 (`git merge-base --is-ancestor` check against both primary and
fallback, recorded in `Last Checkpoint`); added the matching AC requirement to
`task-planner.md`'s Acceptance criteria discipline section.

**Pattern description:**
Task description explicitly instructed "if dev doesn't have TASK-016 merged, branch from `task/TASK-016-fee-foundation` as fallback" due to expected stale-ref scenario. Developer instead branched from `origin/dev` (a stale remote ref predating TASK-016's reviewed implementation) and re-implemented TASK-016's already-reviewed foundation files as untested duplicates. Main deliverable (`src/presentation/pages/Fees.tsx`) was never touched. Detection required direct git inspection (git diff --stat, git reflog) rather than developer's own report, which claimed "Perfect!" while its own itemized "Remaining Work" list contradicted that framing.

**Recommended fix:**
1. **Task-planner template:** When a task explicitly states a fallback base branch (e.g., "use X if Y is unavailable"), add an AC verification step: "Branch base confirmed to be either the primary or the stated fallback; not an older ref. Task file's `Dev Checkpoint` field records which was used."
2. **Developer agent brief:** Add a pre-implementation checkpoint step — before writing code, verify the branch origin (print `git log -1 --format=%B` + `git merge-base --is-ancestor` check against expected base), and record it in the task's `Dev Checkpoint` field. This is a safety stop, not implementation work.
3. **dev-manager:** On task FAIL, compare agent's framing ("done", "perfect", "complete") against git artifacts (file list, diff --stat) before accepting the narrative. Self-contradiction between framing and itemized remaining-work is a red flag warranting direct verification.

**Last seen:** 2026-09-03 (SIMS frontend TASK-017, attempt 1)

---

### [PATTERN-003] AddFixedWindowLimiter creates global buckets; per-client partitioning required

**Root cause category:** RULE-GAP
**Affected rule:** `~/.claude/rules/api-design.md` (rate limiting section, currently incomplete)
**Affected project:** SIMS backend
**Count:** 1 occurrence in workflow; 6+ in codebase (systemic)
**Projects affected:** SIMS backend
**Tasks:** TASK-026 (rate limiting on /auth/login and /auth/refresh)
**Status:** ✅ Fixed — 2026-09-16: added a "Partition per client" subsection to
`api-design.md`'s Rate Limiting section with the `AddFixedWindowLimiter` footgun and correct
`RateLimitPartition` pattern; added the matching case study to `guard-tests.md` §1. SIMS
backend remediation of the six existing instances is a separate follow-up task, not a rule
change — tracked in that project's own tracker, not here.

**Pattern description:**
ASP.NET Core's `AddFixedWindowLimiter(name, opts => ...)` simple overload creates a single global rate-limit bucket shared by all clients, not per-client limits as developers typically expect. One unauthenticated attacker sending requests at the limit rate exhausts the global bucket and locks all users out. Code comments often claim "per IP" but implementation is global. This is a non-obvious API footgun; developers reaching for the simpler overload (not reading the full partitioning API docs) hit it repeatedly. SIMS backend has six instances: TASK-026 added two (`login`, `refresh`); five pre-existing policies (`register`, `catalog`, `verify`, `forgot-password`, `token-action`) appear to have the same issue, indicating systemic adoption of the wrong pattern across the rate-limiting surface.

**Recommended fix:**
1. **Update `~/.claude/rules/api-design.md`** — add subsection "Rate Limiting (per-client required)" under the Rate Limiting section:
   - Document that `AddFixedWindowLimiter` without partitioning creates global buckets and must NOT be used for per-client limits
   - Provide correct pattern: `AddPolicy(name, partitioner => RateLimitPartition.GetFixedWindowLimiter(..., context => context.Connection.RemoteIpAddress))` with example code
   - Link to ASP.NET Core rate-limiting docs
2. **Update `~/.claude/rules/guard-tests.md`** — add case study under § 1 (enumerate the population):
   - Single-client test suites (using one shared `HttpClient`) cannot distinguish per-client from global rate limits
   - Multi-client rate-limit tests must use separate `HttpClient` instances (or mock different IP addresses) and verify one client's consumption does not affect another's quota
3. **Task template (task-planner):** When creating rate-limiting tasks, add AC verification step: "For .NET rate limits, confirm use of `RateLimitPartition.GetFixedWindowLimiter(...)` keyed by client IP, not bare `AddFixedWindowLimiter(...)`.
4. **Remediation in SIMS backend:** Create follow-up task to audit and fix all six instances in `RateLimitingExtensions.cs`.

**Last seen:** 2026-09-02 (SIMS backend TASK-026, security-scanner BLOCKED)

---

### [PATTERN-002] Self-referential guard tests (assert against mock variables, not rendered output)

**Root cause category:** RULE-MISS
**Affected rule:** `~/.claude/rules/guard-tests.md` § 3
**Affected project:** SIMS frontend (spear_sims_frontend)
**Count:** 2 occurrences
**Projects affected:** SIMS frontend
**Tasks:** TASK-001 (interceptor-handler-index mismatch), TASK-008 (Batches envelope-unwrap)
**Status:** ✅ Fixed — 2026-09-16: added the self-referential-assertion ❌/✅ example to
`guard-tests.md` §3 (asserting against your own mock vs. asserting against rendered output).

**Pattern description:**
Guard test blocks in this project assert against the test's own local mock variables (`expect(mockVariable)`, `expect(localFixture)`) or mock call counts (`expect(apiClient.get).toHaveBeenCalledWith(url)`) instead of asserting against rendered DOM output or exposed component state. This violates guard-tests.md §3 ("Never cite a number from one scope as evidence about another") and §2 ("Prove the guard fails"). The tests pass (all 18 or 51 pass) but would pass even if the bug being guarded against were reintroduced. Example: Batches.test.tsx's "populate state" tests assert only that a fetch call happened, not that the resolved value actually populated the dropdown options — tests would be green both before and after the fix.

**Recommended fix:**
1. Add a concrete example to guard-tests.md §3 showing the self-referential anti-pattern:
   - ❌ `expect(mockCourses).toEqual([...])` — asserts against your own fixture, not the implementation
   - ✅ `expect(screen.getAllByRole('option')).toHaveLength(mockCourses.length)` — asserts against rendered output
2. In task acceptance criteria for guard tests, require explicit assertion on rendered output or component state, not mock call counts or local variables.
3. In SIMS frontend retro, flag tester's guard test blocks for review-before-sign-off to catch this pattern early.

**Last seen:** 2026-08-24 (SIMS frontend TASK-008, Batches.test.tsx guard test block lines 381–518)

---

### [PATTERN-001] External-origin code adopted without fresh developer verification

**Root cause category:** AGENT-BRIEF
**Affected agent:** `~/.claude/agents/dev-manager.md`
**Count:** 1 occurrence
**Projects affected:** SIMS backend
**Tasks:** TASK-011 (SIMS backend)
**Status:** ✅ Fixed — 2026-09-16: `dev-manager.md`'s per-task loop (step 4) now says that
pre-existing uncommitted changes of unknown origin found at `check-clean` must be routed
through a normal `developer` dispatch rather than adopted directly as the task's checkpoint.

**Pattern description:**
When unverified external-origin code (e.g. from an external tool session, pre-existing as uncommitted changes) is adopted as a developer-stage checkpoint and forwarded directly to tester without a fresh `developer` verification pass, AC defects bypass the developer's normal gate and surface only at tester stage. Example: missing config fields, architectural-layer violations that a developer would catch immediately.

**Recommended fix:**
Clarify in `dev-manager.md` that external origin does not bypass developer verification — it only changes the context (the developer is reviewing uncontrolled work rather than code they wrote in the session). When adopting external-origin code as a task checkpoint, route it through a fresh `developer` dispatch or explicitly verify all AC and rule-file compliance before forwarding to tester, documenting the verification as done.

**Last seen:** 2026-08-18 (SIMS backend TASK-011)
