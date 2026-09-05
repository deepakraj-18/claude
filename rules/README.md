# Stack Rule Files — Index

Lives at `~/.claude/rules/` once installed. Each file is binding convention for its layer — `planner`, `developer`, and `reviewer` all read the applicable files (see `CLAUDE.md`'s Tech Stack Defaults table and Stack Confirmation Rule).

| File | Layer |
|---|---|
| **`task-streams.md`** | **Universal — task ids, streams (IF/SC/DB/BD/FD/FI), ordering, file layout.** |
| **`guard-tests.md`** | **Universal — binding on `tester` and `reviewer`. A guard test that cannot fail is worse than none.** |
| **`destructive-operations.md`** | **Universal — binding on every agent with Bash access, on every task, regardless of stack. Not optional, not selected per-project.** |
| `react.md` | Web frontend — React |
| `react-native.md` | Mobile — React Native via the Community CLI (not Expo) |
| `dotnet.md` | Backend — .NET |
| `sql-server.md` | Database — SQL Server |

`destructive-operations.md` is the one file here that is not a stack rule. It always applies. It was written after a `tester` agent ran `git clean -fd` in a repository with zero commits and destroyed an entire project — documents, original design assets, and all source — unrecoverably.

## Adding a new stack

When a project needs a layer not covered here (e.g. Python, Angular, Postgres):

1. Add `~/.claude/rules/<layer>.md` following the structure of an existing file (Project setup, Structure, conventions specific to the layer, Testing, Do/Don't).
2. Add a row to this table and to the Tech Stack Defaults table in `CLAUDE.md`.
3. `planner` will pick it up automatically the next time it asks the stack-confirmation question — no agent `.md` file needs to change, since they all reference `Stack Rules` generically rather than hardcoding the four current files.

## Templates for external AI tools

`~/.claude/templates/` holds files that are **instantiated into projects**, not read from
here at runtime:

| Template | Instantiated to | By | Purpose |
|---|---|---|---|
| `AGENTS.template.md` | `<component-repo>/AGENTS.md` | `dev-manager` step 3a | The only rules file external tools (Antigravity, Cursor, Copilot, Codex) read. Must be **self-contained** — inline the stack rules, never link to `~/.claude/`. |
| `TASK-BRIEF.template.md` | `.claude-context/briefs/<ID>.md` | `dev-manager` step 3b | Per-task brief: the traps this task will hit, exact files to change, what must not change, guard proofs required. Mandatory on a retry. |

External agents read **none** of the files in `~/.claude/`. Anything they must follow has
to be inlined into `AGENTS.md` in their repo, verbatim.
