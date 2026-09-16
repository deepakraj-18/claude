# Multi-Model Workflow — Full Detail

Moved out of `~/.claude/CLAUDE.md` so it is not billed into every session and every
subagent. `dev-manager` reads this once when it starts coordinating a project. Other
agents do not need it.

## Agent Roster (full)

`gatherer` (Opus, interactive requirements gathering) → `planner` (Sonnet, architecture
plan from requirements.md) → `task-planner` (Sonnet) → `developer` (Haiku, implementation
only) → `tester` (Haiku, writes and runs tests independently from Acceptance Criteria,
never sees implementation internals) → `reviewer` (Sonnet, checks both against contract and
stack rules) → `security-scanner` (Sonnet, pre-commit security scan on diffs) →
`docs-writer` (Haiku, changelog/release notes/API docs after all tasks PASS) →
`dev-manager` (Sonnet, coordinates all of the above, routes retries to whichever stage
failed).

Outside the per-task loop:

- **`devops-engineer`** (Sonnet) — repository topology and CI/CD. Runs first, at project
  start, before any code exists: creates the parent repo, the per-component repos, wires
  them as submodules, makes the initial commit in each. Then owns submodule pointer
  updates, pipelines, branch protection, releases. The backend repo owns all database
  artefacts including SQL and stored procedures.
- **`business-analyst`** (Sonnet) — project state. Owns `.claude-context/tracker.md` and
  `project-state.md`, verifies claimed status against the repository rather than the
  tracker, reports drift, dependency violations, stale external blockers, uncommitted work.
- **`bug-triage`** (Haiku) — production error diagnosis. Takes a stack trace / Sentry alert
  / error log, locates the offending code via Grep, identifies root cause, outputs a
  structured bugfix `requirements.md` for the normal pipeline.
- **`git-setup`** (Sonnet) — Git initialisation. Once per project, before any other agent.
  Collects owner name, email, GitHub username, remote URL per repo (parent + submodules);
  configures identity; wires remotes; makes the initial commit in every repo; pushes in
  correct submodule order; writes `.claude-context/git-config.md`.
- **`quality-logger`** (Haiku) — failure logging & pattern detection. Auto-invoked after
  every FAIL, BLOCKED, or ESCALATED verdict. Appends structured entries to
  `.claude-context/quality-log.md` and updates `~/.claude/retrospective/patterns.md`.
- **`delegate`** (Sonnet) — routes a unit of work to the cheapest sufficient path
  (fast-lane Haiku / full pipeline / return to operator) before any other agent spawns.

## Claude is the brain; external AI tools may only be the developer

Every role except `developer` and `tester` is exclusively and always a Claude subagent.
Those roles hold authority — scope, architecture, sequencing, the final `PASS`/`FAIL`
verdict — that no external tool's contract ever grants it. `developer` and `tester` are the
only roles with two fulfilment paths for the same contract, and both paths are normal on
the same repo, often on adjacent tasks. On one project, Claude implemented two
database/infrastructure tasks directly while an external tool implemented the other 44 in
the same backend repo, in the same week:

- **Internal** — Claude's own `developer`/`tester` subagents, in-session, full visibility.
  Reach for this when a task needs judgment the external tool's `AGENTS.md` deliberately
  withholds (an architecture call, a task the external tool escalated, or simply because
  it's faster to do directly than to write a brief for).
- **External** — any tool that reads only `AGENTS.md` at a repo root (Cursor, Antigravity,
  Copilot, Codex, a human) — governed entirely by that file plus, on a retry or non-obvious
  task, `.claude-context/briefs/<ID>.md`. It may only implement the one task it was
  assigned; never selects its own next task; never makes a scope/architecture call unstated
  in the task; never sets `Status` to anything but `Review`.

**The repo-level declaration in `git-config.md`'s `Implementation` column
(`Internal` / `External: <tool>` / `Mixed`) is a default and a bootstrap signal, not a
constraint on any individual task.** It tells `dev-manager` whether a repo needs `AGENTS.md`
instantiated at all (skip only for a repo that will never see external work; instantiate
for `External` or `Mixed`) and gives `reviewer` a starting assumption. It is not where the
true record of who did what lives, and nothing needs updating it when the mix changes task
to task. **The authoritative record for any one task is that task's own `Claimed By`
field** (see `~/.claude/rules/task-streams.md`). Whichever mix a repo uses,
`devops-engineer` wires the same enforcement (`templates/pre-commit.template.sh` and
`templates/ci-review-gate.template.yml`) unconditionally: a real project found 44 of 56
tasks marked `PASS` had no review record at all, most of it Claude-implemented work. The
gate protects against review-discipline drift generally.

See `~/.claude/rules/external-agents.md` for the full protocol and the three incidents that
produced it (self-graded PASS nine days after a FAIL; 24 commits unpushed for a week; a
tax-engine task shipped with the exact bug it existed to fix).

## Slash Commands

Type `/user:<name>`:

| Command | Does | Delegates to |
|---|---|---|
| `/user:status` | Session-start health check | `business-analyst` (session-start mode) |
| `/user:feature <description>` | Start a new feature | `gatherer` |
| `/user:resume` | Resume from where it stopped | `dev-manager` (Section A + task loop) |
| `/user:bug <error details>` | Diagnose a production error | `bug-triage` |
| `/user:retro` | Quality retrospective & pattern analysis | `quality-logger` |
| `/user:git-init` | Set up Git for a project | `git-setup` |

## Project File Map

### Global (`~/.claude/`)
| File | Purpose |
|---|---|
| `CLAUDE.md` | Slim always-loaded preferences |
| `docs/workflow.md` | This file — full workflow detail, read by dev-manager only |
| `settings.json` | Permissions, hooks |
| `agents/*.md` | Agent definitions (frontmatter + system prompt) |
| `rules/*.md` | Convention rule files |
| `rules/appendix/incidents.md` | Full incident write-ups moved out of the rule files |
| `hooks/*.sh` | Lifecycle scripts (block-dangerous, format, git-checkpoint, run-tests) |
| `commands/*.md` | Slash commands |
| `retrospective/patterns.md` | Cross-project failure patterns (quality-logger writes) |
| `projects/<key>/memory/` | Auto-memory per project |
| `templates/AGENTS.template.md` | Self-contained brief for external AI tools, per component repo |
| `templates/START_HERE.template.md` | Kickoff pasted as first message to an external tool |
| `templates/TASK-BRIEF.template.md` | Heavier per-task brief for non-obvious tasks / retries |
| `templates/pre-commit.template.sh` | Review/claim-discipline gate, instantiated by devops-engineer |
| `templates/ci-review-gate.template.yml` | Server-side twin of the pre-commit gate |

### Per Project (`<repo>/`)
| File | Owner | Purpose |
|---|---|---|
| `CLAUDE.md` | Human | Project context, applicable rules, dev commands |
| `.claude-context/requirements.md` | `gatherer` | Approved requirements |
| `.claude-context/plan.md` | `planner` | Approved implementation plan |
| `.claude-context/tasks/<STREAM>/<ID>.md` | `task-planner` | Tasks with AC, status, checkpoints |
| `.claude-context/tracker.md` | `business-analyst` | Per-task status table |
| `.claude-context/project-state.md` | `business-analyst` | Durable decisions, risks, external blockers |
| `.claude-context/log.md` | `dev-manager` | Append-only activity log (one line per task) |
| `.claude-context/quality-log.md` | `quality-logger` | Structured failure/review entries |
| `.claude-context/git-config.md` | `git-setup` | Git identity, remotes, environment |

## Token Discipline (full notes)

- **Read only what your role needs.** `gatherer` uses Glob for project structure only, not
  source files; `planner` reads `requirements.md` + relevant modules; `developer` reads
  `Relevant Files` and its `Stack Rules`; `tester` reads only public interfaces, not
  implementation bodies; `reviewer` reads diffs and recorded test results, not full
  pre-existing files unless a diff is genuinely ambiguous.
- **Keep `Relevant Files` short.** More than ~5 files on a task is a signal to split the
  task, not to widen the list.
- **Scope test reruns on retry.** `hooks/run-tests.sh <path>` runs just the affected tests.
- **On retry, read only `Review Notes`.**
- **Push determinism into hooks.** Test execution, formatting, git checkpoint/revert/commit,
  dangerous-command blocking are all scripts under `hooks/`.
- **Keep `dev-manager` thin.** Reads `Status`/`Failed Stage` + last ~20 lines of `log.md`,
  never full task history or prior transcripts. Rotate older entries into
  `.claude-context/log-archive.md` once `log.md` passes ~50 lines.
- **Limit `gatherer` rounds** to 2-3 max — capture remaining ambiguity under "Open
  Questions".
- **Batch trivial, sequential tasks** into one task file — every task file costs a fixed
  round of agent-call overhead.
- **Break long autonomous runs.** After each task PASS + commit, all state lives in the
  task file + `log.md` — that is a clean context boundary. When `dev-manager` runs directly
  (not as a subagent), reset context every 3-5 tasks, or run it per-phase rather than
  whole-project. A 93-task single-session run guarantees a >150k-token context.
