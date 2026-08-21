# Memory Management -- Rules for Claude

## What is Memory

Claude Code maintains an auto-memory system at `~/.claude/projects/<project-key>/memory/`.
This is where Claude stores **learnings** it discovers during a session -- things it figures out
about the codebase, the user's preferences, or recurring patterns that would be lost when the
session ends.

## Memory vs CLAUDE.md

| | CLAUDE.md | memory/ |
|---|---|---|
| **Who writes** | Human (you) or agents on your instruction | Claude automatically (or via `/memory`) |
| **Content** | Instructions, standards, rules | Learnings, discoveries, project facts |
| **Persistence** | Manual -- you edit the file | Auto -- Claude saves when it learns |
| **Committed** | Yes (project-level) | No (lives in ~/.claude/projects/) |

## Rules for Agents

### When to save a memory

Save a memory when you discover something **non-obvious** about the codebase that:
- Is NOT already documented in CLAUDE.md, plan.md, or technical_design.md
- Would take another agent (or a future session) significant time to re-discover
- Is a pattern, gotcha, or implicit convention

Examples:
- `dotnet ef` requires a specific `--project` flag in this repo because the solution structure is non-standard
- The pricing engine in RideKaroo silently swallows exceptions in the surge multiplier path -- any change to pricing must check this
- HappyBonding's WhatsApp template names are case-sensitive on Meta's side even though the API accepts mixed case
- Migration `20260815_AddIndexes` has a known issue: the compound index on `(CustomerId, OrderDate)` is in the wrong column order for the most common query pattern

### When NOT to save a memory

- Information already in CLAUDE.md or project docs
- Temporary debugging notes
- Task-specific context that won't apply to future tasks
- Obvious patterns that any developer would know

### Memory file naming

`~/.claude/projects/<project>/memory/<descriptive_name>.md`

Examples:
- `pricing_engine_gotchas.md`
- `whatsapp_template_naming.md`
- `migration_ordering_quirks.md`

### MEMORY.md index

If the `memory/` directory grows past ~5 files, create or update a `MEMORY.md` index:

```markdown
# Memory Index

- [Pricing Gotchas](pricing_engine_gotchas.md) -- Surge multiplier swallows exceptions silently
- [WhatsApp Templates](whatsapp_template_naming.md) -- Case-sensitive on Meta side
```

## Memory Management Rule for dev-manager

After completing a phase (all tasks in a phase reach PASS), check:
1. Did any task fail due to a non-obvious codebase quirk?
2. Did the reviewer leave notes about a pattern that future developers should know?
3. Did the quality-logger identify a project-specific (not rule-level) issue?

If yes, save a memory file. This is distinct from the quality-logger's job:
- **quality-logger** logs the failure and recommends rule/agent changes (cross-project)
- **memory** captures the project-specific fact that caused the failure (per-project)
