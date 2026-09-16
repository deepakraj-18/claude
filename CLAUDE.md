# Global Preferences — Claude Code Multi-Model Workflow

Loaded into every session and every subagent. Keep it short. Full workflow detail
(roster rationale, file maps, internal-vs-external model) lives in
`~/.claude/docs/workflow.md` — `dev-manager` reads that once when it starts coordinating;
nothing else needs it.

## Agent Roster

Pipeline: `gatherer` → `planner` → `task-planner` → `developer` → `tester` → `reviewer` →
`security-scanner` → `docs-writer`, coordinated by `dev-manager`. Outside the loop:
`devops-engineer` (repo topology/CI), `business-analyst` (tracker/state), `git-setup`
(git init), `bug-triage` (error → bugfix requirements), `quality-logger` (FAIL/BLOCKED/
ESCALATED logging), `delegate` (routes work to cheapest sufficient path).

Models are set in each `agents/*.md` frontmatter. Full brief for each is its own file.

**Claude is the brain.** Every role except `developer`/`tester` is always a Claude subagent.
Only `developer`/`tester` may be fulfilled by an external tool (Antigravity/Cursor/Copilot/
Codex/human) reading `AGENTS.md`. An external submission is `Status: Review` regardless of
what its `Status` field says, and goes through `reviewer`'s external-submission protocol.
The authoritative record of who did a task is that task's `Claimed By` field, not any
repo-level column. Details + incident history: `~/.claude/rules/external-agents.md`.

## Tech Stack Defaults & Universal Rules

| Layer / Topic | Default | Rule file |
|---|---|---|
| Web frontend | **React** (alt: Vue 3 + Inertia) | `react.md` / `vue-inertia.md` |
| Mobile | **React Native, Community CLI** (not Expo) | `react-native.md` |
| Backend | **.NET** (alt: Laravel, PHP 8.2+) | `dotnet.md` / `laravel.md` |
| Database | **SQL Server** (alt: MySQL) | `sql-server.md` / `mysql.md` |
| Error handling | Universal | `error-handling.md` |
| API design | REST, universal | `api-design.md` |
| Constants & static data | Universal | `constants.md` |
| DB migrations | Universal | `db-migration.md` |
| Performance | Universal | `performance.md` |
| Git workflow | GitHub Flow | `git-workflow.md` |
| Task streams | Universal — binding on task-planner | `task-streams.md` |
| Guard tests | Universal — binding on tester + reviewer | `guard-tests.md` |
| Destructive ops | Universal — every agent with Bash | `destructive-operations.md` |
| Memory | Universal | `memory.md` |

All rule files are `~/.claude/rules/<name>`. Use defaults unless the repo already
establishes a different stack (follow the repo) or the requirement says otherwise.

**Load only the rule files your task's stack needs** — a backend task reads `dotnet.md` +
`sql-server.md` + the four universal rules (error-handling, constants, performance,
destructive-operations) and nothing else. A `/status` run reads none. Do not read the
whole `rules/` directory.

## Destructive Operations (non-negotiable)

`~/.claude/rules/destructive-operations.md` binds every agent with Bash access, always.
The two that prevent total loss:

1. **Never run `git clean`, `git reset --hard`, `git checkout -- <path>`, `rm -rf`, or any
   wildcard delete** without explicit authorization naming that target in the current
   conversation. "Implement", "verify", "clean up" are not authorization.
2. **Make an initial commit before running any tooling against a new project.** Zero commits
   = every mistake permanent. This was violated 2026-08-15 and destroyed an entire project.

## Stack Confirmation (at requirements time)

Before `gatherer` writes `requirements.md` it must settle the stack: follow the repo if one
exists, else use what the requirement specifies, else stop and ask the user (offer the
defaults above). Record the confirmed layers and matching rule files in `requirements.md`
under `Confirmed Stack` / `Applicable stack rules`. `planner`/`task-planner`/`developer`/
`reviewer` must never be the ones discovering a stack ambiguity.

## Commit Message Convention

`[TASK-<id>] <summary>` only. No co-author trailer, no AI-attribution line, no other
trailers. Applies to `git-checkpoint.sh commit` and any manual commit.

## Memory

`~/.claude/projects/<project-key>/memory/` holds learnings Claude discovers (gotchas,
quirks) — distinct from CLAUDE.md, which holds instructions humans write. Save one after a
phase if a task failed on a non-obvious project-specific fact. Read `MEMORY.md` (the index)
at session start. Full rules: `~/.claude/rules/memory.md`.

## Token Discipline

- **Read only what your role needs.** Never default to "the whole file" / "the whole repo"
  — it is the biggest cost driver here. `developer` reads `Relevant Files` + its stack
  rules; `tester` reads public interfaces only; `reviewer` reads diffs + recorded test
  results, not whole pre-existing files.
- **On retry, read only the `Review Notes` section** — description and AC are unchanged.
- **Keep `Relevant Files` ≤ 5.** More is a signal to split the task.
- **Scope test reruns on retry**: `hooks/run-tests.sh <path>`, not the full suite.
- **`dev-manager` stays thin**: route off `Status`/`Failed Stage` + last ~20 lines of
  `log.md`, never full task history or transcripts. Rotate `log.md` past ~50 lines into
  `log-archive.md`.
- **Never forward accumulated conversation into a subagent** — pass only the task file
  (plus `plan.md` for planner/task-planner).
- **Cap `gatherer` at 2–3 clarifying rounds**; park the rest under "Open Questions".
- **Push determinism into hooks** — never spend a model turn deciding whether to run one.
