# Task Streams & Numbering — Rules for Claude

**Binding on `task-planner`.** `dev-manager`, `developer`, `tester`, `reviewer` and
`business-analyst` all read task ids, so they must understand this scheme too.

A task id should tell you three things before you open the file: which layer of the system it
belongs to, roughly when it happens, and what has to exist first. `TASK-047` tells you none of
them.

---

## The six streams

| Prefix | Stream | Covers |
|---|---|---|
| `IF` | Infrastructure | Repos, submodules, CI/CD pipelines, branch protection, cloud provisioning, secrets wiring, deployment |
| `SC` | Scaffolding | Solution/project skeletons, constants files, configuration binding, logging, error handling, cross-cutting middleware |
| `DB` | Database | Entities, migrations, schema, indexes, seed data, stored procedures, tax/rate tables |
| `BD` | Backend | Use cases, services, API endpoints, auth, integrations (payment, messaging, AI), business rules |
| `FD` | Frontend design | Scaffold, routing, layout, screens, components, styling — everything that renders without live data |
| `FI` | Frontend integration | Typed API clients, data fetching, mutations, wiring screens to real endpoints, loading/error/empty states |

Numbering restarts per stream and is zero-padded to three digits: `IF001`, `DB014`, `BD102`.

**Why FD and FI are separate.** A screen can be built against the design before its endpoint
exists; wiring it up cannot. Merging them creates a task that is blocked on the backend from
the moment it is written, which hides real parallelism and makes the dependency graph lie.

Add a stream only when a real body of work fits none of the above (e.g. `MB` mobile, `QA`
hardening, `RL` release). Do not invent one per feature — streams are layers, not topics.

---

## Ordering

The streams give the **default sequence**: `IF → SC → DB → BD → FD → FI`. Plan in that order,
and number within it.

**Dependencies override that sequence, and are the real execution order.** Every task carries
an explicit `Dependencies:` list, and that list decides what is actually next — not the prefix,
not the number.

This is not a loophole; cross-stream dependencies are normal and pretending otherwise produces
a plan that cannot be followed:

- A backend task that quotes prices to customers depends on the tax engine. If the tax engine
  is planned late, the bot quotes pre-tax totals to real people. On one project this was caught
  only because the dependency was written down explicitly.
- A frontend integration task depends on exactly one backend endpoint, not on the whole backend
  stream finishing.
- Location scoping in auth gates every data-returning endpoint after it, across two streams.

**When a dependency points backwards** — a `DB` task needed by an earlier-numbered `BD` task —
say so in the task's `Notes` and flag it in the plan's Execution Order section. A backwards
dependency is legitimate but it is also the single most common source of a stalled build, so it
must be visible rather than discovered.

---

## Layout

One directory per stream, one file per task:

```
.claude-context/tasks/
├── INDEX.md          all tasks, all streams, in dependency order
├── IF/  IF001.md  IF002.md  …
├── SC/  SC001.md  …
├── DB/  DB001.md  …
├── BD/  BD001.md  …
├── FD/  FD001.md  …
└── FI/  FI001.md  …
```

`INDEX.md` is the map: id, title, stream, dependencies, estimate, status. It is regenerated
from the task files, never hand-maintained as a parallel source of truth.

---

## Task file format

Every task file opens with machine-readable state, then human-readable spec:

```markdown
# DB014 — Add TaxRate entity with effective dating

Status: Pending
Failed Stage:
Attempts: 0
Last Checkpoint: (none yet)
Dev Checkpoint: (none yet)

Stream: DB
Order: 14
Phase: 7 — GST & finance
Dependencies: DB001, DB006
Blocks: BD048
Repo: <project>-backend
Estimate: 1.5
Spec: docs/task_plan.md

## Description
## Acceptance Criteria
## Relevant Files
## Stack Rules
## Notes
## Review Notes
## Test Results
```

- `Status` values: `Pending` → `In Progress` → `Implemented` → `Review` → `PASS`, plus
  `Blocked`, `Deferred`.
- `Repo` names the component repository the work lands in, so `git-checkpoint.sh` records the
  checkpoint in the right repo. In a multi-repo project a checkpoint stored against the parent
  is useless for reverting a component.
- `Blocks` is the inverse of `Dependencies`. Maintaining both makes "what does this unblock?"
  answerable without scanning every file, which is what `dev-manager` needs to pick the next task.

## Commits and branches

```
branch:  <stream>/<ID>-<short-description>     e.g. db/DB014-taxrate-effective-dating
commit:  [DB014] <imperative summary>
```

No AI-attribution trailers, per `~/.claude/CLAUDE.md`.

---

## For `task-planner`

1. Assign every task to exactly one stream. If a task spans two, it is two tasks — a screen and
   its API wiring, a migration and the service that uses it.
2. Number within the stream, in the default sequence.
3. Write `Dependencies` from what the task genuinely needs, **not** from its position. Then
   populate `Blocks` as the inverse.
4. In the plan's Execution Order section, give the critical path by id and call out every
   backwards dependency explicitly.
5. Keep `Relevant Files` to ~5. More than that means the task should split — and a task
   spanning two streams almost always should.
