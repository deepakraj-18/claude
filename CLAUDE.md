# Global Preferences — Claude Code Multi-Model Workflow

Copy this file to `~/.claude/CLAUDE.md` (merge with any existing global memory rather than overwrite). These rules apply across every project using the gatherer/planner/task-planner/developer/tester/reviewer/security-scanner/docs-writer/dev-manager workflow.

## Agent Roster

`gatherer` (Opus, interactive requirements gathering) → `planner` (Sonnet, architecture plan from requirements.md) → `task-planner` (Sonnet) → `developer` (Haiku, implementation only) → `tester` (Haiku, writes and runs tests independently from Acceptance Criteria, never sees implementation internals) → `reviewer` (Sonnet, checks both against contract and stack rules) → `security-scanner` (Sonnet, pre-commit security scan on diffs) → `docs-writer` (Haiku, changelog/release notes/API docs after all tasks PASS) → `dev-manager` (Sonnet, coordinates all of the above, routes retries to whichever stage failed). See `agents/*.md` for each one's full brief.

### Claude is the brain; external AI tools may only be the developer

Every role above **except `developer` and `tester`** is exclusively and always a Claude
subagent. Those roles hold authority — scope, architecture, sequencing, and the final
`PASS`/`FAIL` verdict — that no external tool's contract ever grants it. `developer` and
`tester` are the only roles with two fulfilment paths for the same contract, and **both
paths are normal on the same repo, often on adjacent tasks** — this is not an edge case to
plan around, it is the expected shape of real work. On one project, Claude implemented two
database/infrastructure tasks directly while an external tool implemented the other 44 in
the same backend repo, in the same week:

- **Internal** — Claude's own `developer`/`tester` subagents, in-session, full visibility
  into this directory. Reach for this when a task needs judgment the external tool's
  `AGENTS.md` contract deliberately withholds from it (an architecture call, a task the
  external tool escalated, or simply because it's faster to do directly than to write a
  brief for).
- **External** — any tool that reads only `AGENTS.md` at a repo root (Cursor, Antigravity,
  Copilot, Codex, or a human) — governed entirely by that file plus, on a retry or a
  non-obvious task, `.claude-context/briefs/<ID>.md`. An external tool may only implement
  the one task it was assigned; it never selects its own next task, never makes a
  scope/architecture call unstated in the task, and never sets `Status` to anything but
  `Review`. See `~/.claude/rules/external-agents.md` — a real project had a task reviewed
  `FAIL` and found nine days later back at `Status: PASS` with the same defects still
  unfixed, because that rule existed only as prose an external tool could ignore.

**The repo-level declaration in `git-config.md`'s `Implementation` column
(`Internal` / `External: <tool>` / `Mixed`) is a default and a bootstrap signal, not a
constraint on any individual task.** It tells `dev-manager` whether a repo needs
`AGENTS.md` instantiated at all (skip only for a repo that will never see external work;
instantiate for `External` or `Mixed`) and gives `reviewer` a starting assumption. It is
**not** where the true record of who did what lives, and nothing needs updating it when the
mix changes task to task. **The authoritative record for any one task is that task's own
`Claimed By` field** (see `~/.claude/rules/task-streams.md`) — read that, not the repo-level
column, to know whether a specific task's submission needs the internal or external review
path. Whichever mix a repo ends up using, `devops-engineer` wires the same enforcement —
see `templates/pre-commit.template.sh` and `templates/ci-review-gate.template.yml` below —
**unconditionally**: a real project found 44 of 56 tasks marked `PASS` across its whole
history had no review record at all, and most of that was Claude-implemented work, not
only external. The gate protects against review-discipline drift generally.

Three agents sit outside that per-task loop:

- **`devops-engineer`** (Sonnet) — repository topology and CI/CD. Runs **first, at project start, before any code exists**: creates the parent repo, the per-component repos, wires them as submodules, and makes the initial commit in each. Then owns submodule pointer updates, pipelines, branch protection, and releases. The backend repo owns all database artefacts including SQL and stored procedures.
- **`business-analyst`** (Sonnet) — project state. Owns `.claude-context/tracker.md` and `project-state.md`, verifies claimed status against the repository rather than the tracker, and reports drift, dependency violations, stale external blockers, and uncommitted work.
- **`bug-triage`** (Haiku) — production error diagnosis. Takes a raw stack trace, Sentry alert, or error log, locates the offending code via Grep, identifies the root cause, and outputs a structured bugfix `requirements.md` for the normal pipeline to act on.
- **`git-setup`** (Sonnet) — Git initialisation. Run **once per project**, before any other agent. Asks for owner name, email, GitHub username, and remote URL for each repo (parent + submodules); configures identity; wires remotes; makes the initial commit in every repo; pushes in the correct submodule order; and writes `.claude-context/git-config.md` so every other agent knows the repo topology and environment (dev/staging/production).
- **`quality-logger`** (Haiku) — Failure logging & pattern detection. Auto-invoked after every FAIL, BLOCKED, or ESCALATED verdict. Appends structured entries to `.claude-context/quality-log.md` (per project) and updates `~/.claude/retrospective/patterns.md` (cross-project). Surfaces recurring patterns to drive rule and agent improvements.

## Tech Stack Defaults & Universal Rules

| Layer / Topic | Default / Scope | Rule file |
|---|---|---|
| Web frontend (default) | **React** | `~/.claude/rules/react.md` |
| Web frontend (alt) | **Vue 3 + Inertia.js** | `~/.claude/rules/vue-inertia.md` |
| Mobile | **React Native, via the Community CLI** (not Expo) | `~/.claude/rules/react-native.md` |
| Backend (default) | **.NET** | `~/.claude/rules/dotnet.md` |
| Backend (alt) | **Laravel** (PHP 8.2+) | `~/.claude/rules/laravel.md` |
| Database (default) | **SQL Server** | `~/.claude/rules/sql-server.md` |
| Database (alt) | **MySQL** | `~/.claude/rules/mysql.md` |
| Error Handling | **Universal** (all code & APIs) | `~/.claude/rules/error-handling.md` |
| API Design | **REST** (all web/backend APIs) | `~/.claude/rules/api-design.md` |
| Constants & Data | **Universal** (hardcoding rules) | `~/.claude/rules/constants.md` |
| DB Migrations | **Universal** (schema change safety) | `~/.claude/rules/db-migration.md` |
| Performance | **Universal** (N+1, caching, optimization) | `~/.claude/rules/performance.md` |
| Git Workflow | **GitHub Flow** (branching & commits) | `~/.claude/rules/git-workflow.md` |
| **Task Streams** | **Universal — binding on task-planner; read by all task agents** | `~/.claude/rules/task-streams.md` |
| **Guard Tests** | **Universal — binding on tester and reviewer** | `~/.claude/rules/guard-tests.md` |
| **Destructive Ops** | **Universal — every agent with Bash access** | `~/.claude/rules/destructive-operations.md` |
| Memory Management | **Universal** (when to save learnings) | `~/.claude/rules/memory.md` |

Use these defaults for any new project or component unless the repository already establishes a different stack (in which case follow the existing repo, don’t fight it), or the requirement explicitly says otherwise.

## Slash Commands

Quick shortcuts available in all projects. Type `/user:<name>` in Claude Code to invoke:

| Command | What it does | Delegates to |
|---|---|---|
| `/user:status` | Session-start health check | `business-analyst` (session-start mode) |
| `/user:feature <description>` | Start a new feature | `gatherer` |
| `/user:resume` | Resume work from where it stopped | `dev-manager` (Section A + task loop) |
| `/user:bug <error details>` | Diagnose a production error | `bug-triage` |
| `/user:retro` | Quality retrospective & pattern analysis | `quality-logger` (phase-retrospective) |
| `/user:git-init` | Set up Git for a project | `git-setup` |

## Memory System

Claude Code maintains an auto-memory system at `~/.claude/projects/<project-key>/memory/`.

**What goes in memory vs CLAUDE.md:**
- `CLAUDE.md` = instructions you write (standards, rules, commands)
- `memory/` = learnings Claude discovers (gotchas, non-obvious patterns, codebase quirks)

**When agents should save a memory:** After a phase completes, if any task failed due to a non-obvious project-specific fact (not a general rule gap), save it to `memory/<descriptive_name>.md`. See `~/.claude/rules/memory.md` for full rules.

**When starting a new session:** Read `~/.claude/projects/<project>/memory/MEMORY.md` (index) to recover project-specific learnings from past sessions.

## Project File Map

Every file type agents may need to read or write:

### Global (`~/.claude/`)
| File | Purpose |
|---|---|
| `CLAUDE.md` | This file — agent roster, stack defaults, universal rules |
| `settings.json` | Permissions (allow/deny), hooks, model selection |
| `agents/*.md` | 15 agent definitions (YAML frontmatter + system prompt) |
| `rules/*.md` | 17 convention rule files |
| `hooks/*.sh` | 4 lifecycle scripts (block-dangerous, format, git-checkpoint, run-tests) |
| `commands/*.md` | 6 slash commands (status, feature, resume, bug, retro, git-init) |
| `retrospective/patterns.md` | Cross-project failure patterns (quality-logger writes) |
| `projects/<key>/memory/` | Auto-memory per project (learnings, gotchas) |
| `templates/AGENTS.template.md` | Self-contained brief instantiated into each component repo for external AI tools |
| `templates/START_HERE.template.md` | Short kickoff instantiated alongside AGENTS.md — what the human pastes as their first message to onboard an external tool |
| `templates/TASK-BRIEF.template.md` | Optional heavier per-task brief for non-obvious tasks or retries |
| `templates/pre-commit.template.sh` | Task-file review/claim discipline gate, instantiated by `devops-engineer` at bootstrap |
| `templates/ci-review-gate.template.yml` | Server-side twin of the above, wired into the parent repo's CI |

### Per Project (`<repo>/`)
| File | Owner Agent | Purpose |
|---|---|---|
| `CLAUDE.md` | Human | Project context, applicable rules, dev commands |
| `.claude-context/requirements.md` | `gatherer` | Approved requirements |
| `.claude-context/plan.md` | `planner` | Approved implementation plan |
| `.claude-context/tasks/TASK-*.md` | `task-planner` | Individual tasks with AC, status, checkpoints |
| `.claude-context/tracker.md` | `business-analyst` | Per-task status table |
| `.claude-context/project-state.md` | `business-analyst` | Durable decisions, risks, external blockers |
| `.claude-context/log.md` | `dev-manager` | Append-only activity log |
| `.claude-context/quality-log.md` | `quality-logger` | Structured failure/review entries |
| `.claude-context/git-config.md` | `git-setup` | Git identity, remotes, environment |

## Destructive Operations Rule (universal, non-negotiable)

`~/.claude/rules/destructive-operations.md` is binding on **every agent with Bash access**, on every task, regardless of stack. It is not a stack rule to be selected — it always applies.

Two rules deserve repeating here because they are the ones that prevent total loss:

1. **Never run `git clean`, `git reset --hard`, `git checkout -- <path>`, `rm -rf`, or any wildcard delete** without explicit authorization naming that target in the current conversation. A general instruction to implement, verify, or clean up is **not** authorization.
2. **Make an initial commit before running any tooling against a new project.** A repository with zero commits is one where every mistake is permanent — `git clean -fd` there deletes everything, and nothing recovers it.

This rule exists because both were violated on 2026-08-15 and an entire project was destroyed: planning documents, original design assets, and all source, unrecoverably. The file documents the incident in full.

**Every agent that reads or writes code for a given layer must read that layer's rule file before doing so** — `planner` when architecting, `developer` when implementing, `reviewer` when reviewing. Treat the rule file as binding convention, not optional style advice.

## Stack Confirmation Rule (requirements gathering time)

Before `gatherer` writes `.claude-context/requirements.md`, it must check whether the input requirement specifies the tech stack / tools / infra it needs (frontend framework, backend framework, database, hosting, key libraries).

- If the repository already has an established stack, follow it.
- If the requirement specifies them, use what's specified.
- If neither applies, `gatherer` must stop and ask the user to confirm the stack — offering the defaults above as the suggested answer, not silently assuming it.
- Once confirmed, `gatherer` records exactly which layers apply and lists the matching `~/.claude/rules/*.md` files in `requirements.md` under `Confirmed Stack` / `Applicable stack rules`.

This check happens once, at requirements gathering time. `planner`, `task-planner`, `developer`, and `reviewer` should never be the ones discovering a stack ambiguity — by the time planning starts, the stack and its rule files are settled and recorded in `requirements.md`.

## Commit Message Convention

Commits made through the workflow (via `hooks/git-checkpoint.sh commit`, or manually by any agent) must **not** include a co-author trailer or any other "Generated by Claude" / AI-attribution line. Commit messages are `[TASK-<id>] <summary>` only — no additional trailers.

## Token Discipline

These apply across every agent, not just one:

- **Read only what your role needs.** `gatherer` uses Glob for project structure only, not source files; `planner` reads `requirements.md` + relevant modules; `developer` reads `Relevant Files` and its `Stack Rules`; `tester` reads only public interfaces, not implementation bodies; `reviewer` reads diffs and recorded test results, not full pre-existing files unless a diff is genuinely ambiguous. Reaching for "the whole file" or "the whole repo" by default is the single biggest cost driver in this workflow — don't.
- **Keep `Relevant Files` short.** More than ~5 files on a task is a signal to split the task, not to widen the list.
- **Scope test reruns on retry.** `hooks/run-tests.sh <path>` runs just the affected tests instead of the full suite — use it on retries, run unscoped only for the pre-review full pass.
- **On retry, read only `Review Notes`.** The retry agent (developer or tester) should read the reviewer's `Review Notes` section, not re-read the full task file from scratch — the description and acceptance criteria haven't changed.
- **Push determinism into hooks.** Test execution, formatting, git checkpoint/revert/commit, and dangerous-command blocking are all scripts under `hooks/` — never spend a model turn deciding whether to run one.
- **Keep `dev-manager` thin.** It reads `Status`/`Failed Stage` fields and the last ~20 lines of `.claude-context/log.md`, never full task history or prior transcripts. Rotate older entries into `.claude-context/log-archive.md` once `log.md` passes ~50 lines.
- **Limit `gatherer` rounds.** `gatherer` is the most expensive agent (Opus). Cap clarifying questions to 2-3 rounds maximum — capture remaining ambiguity under "Open Questions" rather than burning tokens on endless back-and-forth.
- **Enable prompt caching** for the agent `.md` files — they're identical on every invocation and shouldn't be re-billed as fresh input each call.
- **Batch trivial, sequential tasks** into one task file instead of many — every task file costs a fixed round of agent-call overhead regardless of size.

