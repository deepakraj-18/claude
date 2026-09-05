<!--
TEMPLATE — instantiated by `dev-manager` alongside AGENTS.md (step 3a), once per component
repo that isn't purely Internal, as `<repo>/START_HERE.md`. Re-instantiate whenever
AGENTS.md is updated, so this stays in sync with it — don't let the two drift.

This is the file the human pastes as their first message when opening a new session with
an external AI tool ("read START_HERE.md"). It is deliberately short: a kickoff, not the
contract. AGENTS.md is the contract. This file's only job is to point at it, confirm the
tool actually read it, and get it to its first task.

Fill every <placeholder>. Delete this comment block when instantiating.
-->

# Start here

You've just been added to an existing project as an **implementer**. This file gets you
oriented in under a minute. Do the four things below, in order, before writing any code.

## 1. Read `AGENTS.md` in this repo, completely

Not skimmed. It is short enough to read in full and it is binding — it inlines every rule
that governs this repository, including which files you're touching, safety rules, test
requirements, and exactly how work here gets reviewed. There is no other rules file; you
won't find more context by exploring further.

## 2. Know what you are, and what you aren't

You are the **implementer** for one task at a time in **`<repo-name>`** only. You do not:
plan architecture, decide what gets built next, review your own work, or touch any other
repository in this project. Someone else already decided the task's acceptance criteria;
someone else reviews your submission independently before it counts as done. See
`AGENTS.md`'s "Who else is working on this project" section — read that part twice if
anything below feels like an arbitrary restriction.

## 3. Find your task

- If you were told a specific task ID, open `../.claude-context/tasks/<STREAM>/<ID>.md`.
- Otherwise, check `../.claude-context/briefs/` for anything addressed to you, or ask the
  human which task ID to start on — don't self-select from the tracker.
- Check `../.claude-context/briefs/<ID>.md` too, if it exists — it's binding and takes
  precedence over your own judgement about scope.

**Claim it before writing any code** — see `AGENTS.md` §7/§8 for the exact mechanics. This
is not optional ceremony: someone else may be working in this same repo right now.

## 4. Confirm, then work

Before starting, reply with exactly this, filled in:

```
Read AGENTS.md in full.
My task: <ID> — <title>
Claimed: <yes, pushed | not yet, will claim first>
```

Then follow `AGENTS.md` §8's working loop. When you're done, set `Status: Review` — never
`PASS` — and stop. Someone else takes it from there.
