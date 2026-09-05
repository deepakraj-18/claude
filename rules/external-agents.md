# External AI Developers — Rules for Claude

**Binding on `dev-manager`, `business-analyst`, and `reviewer`.** Applies whenever a
component repo's implementation work is done by a tool other than this session's own
`developer`/`tester` agents — Antigravity, Cursor, Copilot, Codex, or a human. This project
runs exactly that setup: Antigravity implements against `happybonding-backend/AGENTS.md`
and `happybonding-frontend/AGENTS.md`, and Claude sessions plan, review, and verify.

## The core fact this file exists to handle

**An external tool cannot read `~/.claude/`.** It has never seen `reviewer.md`,
`guard-tests.md`, or this file. Everything it knows is what's written into its repo's
`AGENTS.md`. That has a consequence with no clean workaround: **a rule that only exists as
prose in `AGENTS.md` is a request, not a control.** The tool can misread it, skip it, or —
observed directly on this project — do the opposite of what it says.

Three confirmed incidents on Happy Bonding, each with the rule already written down at the
time:

1. **`AGENTS.md` §7 says the developer must never set `Status: PASS` — only the reviewer
   may.** A task (`BD005`) was reviewed, returned `FAIL` with a written retry brief, and
   nine days later was found back at `Status: PASS` with both original defects still
   unfixed in the code. Something set it to `PASS` directly, skipping review entirely.
2. **`AGENTS.md` §9 says push the branch as part of finishing a task.** 24 backend commits
   — an entire feature stream — sat committed locally and never reached `origin` for over
   a week, discovered only when a session happened to run `git fetch` and compare.
3. **A task ("tax engine") whose entire job was fixing a hardcoded-zero GST bug shipped
   with the same bug still present** — the rate now resolves correctly, but
   `CgstAmount`/`SgstAmount`/`IgstAmount` are still hardcoded to `0m` at the line-item
   level, on the very branch built to fix exactly that. The submitted `Test Results`
   reported success.

None of this means the external tool is acting in bad faith. It means: **treat instructions
to an external tool as a strong hint about intended behavior, never as a guarantee of
actual behavior.** Design the system so a rule being ignored is caught mechanically, not
discovered by a human three weeks later.

## The principle: verify, don't transcribe

When an external tool reports a task complete, that report is **input to review, not a
substitute for it.** Nothing progresses past `Status: Review` on the strength of a
self-report — not the task's `Status`, not what a Claude session tells the user, not
`business-analyst`'s tracker.

This applies to **every Claude session**, including one running solo without the full
`dev-manager` loop. If you are Claude and you are about to write `Status: PASS` into a task
file — or tell the user a task, a phase, or "everything" is done — because an external
tool said so, stop. That is the exact chain of events that produced incident #1 above. Run
the verification in this file first.

## What independent verification means, concretely

This is the protocol used successfully on this project to catch all three incidents above.
It is heavier than `reviewer.md`'s default pass, deliberately — the default pass assumes
`tester`'s recorded results came from a trusted Claude agent in this same session. That
assumption does not hold here.

1. **Clone to an isolated path, do not review in place.** The external tool may still be
   working in the live checkout; reviewing there risks colliding with in-progress edits
   (observed directly on this project — a review's file injection collided with a live
   `dotnet run` holding a lock) and risks silently reviewing a mix of two people's changes.
   ```
   git clone --local <repo> <scratch-path>
   git -C <scratch-path> checkout <branch-or-sha-being-reviewed>
   ```
   Copy in whatever gitignored config the app needs to actually run (`appsettings.Development.json`,
   `.env.local`) — copy, never author new secrets into a review clone.

2. **Build and run the real suite yourself. Do not read the submitted transcript as fact.**
   A reported "172 passing" is a claim. Run it. If it's a web app, actually start it
   (`dotnet run`, `npm run dev`) and exercise it as a live client would — this project's
   most severe finding (unauthenticated write access to two controllers) was invisible by
   reading the diff alone and took one `curl` with no `Authorization` header to prove.

3. **Re-run at least one guard-proof yourself, fresh.** Per `guard-tests.md`, pick the
   *exact* regression a test claims to catch, inject it in the isolated clone, confirm the
   test fails, restore, confirm green again. Do not accept a pasted before/after transcript
   as equivalent — a transcript can be edited or come from a different run than the one
   being reviewed. On this project, redoing this exercise found that a database
   idempotency guard was actually enforced by a different mechanism than the one the
   pre-check appeared to protect — invisible without re-injecting it personally.

4. **Cross-check against every prior finding, not just this task's stated scope.** If a
   previous review found defect X, check whether X still reproduces before trusting a
   later task built on that code — a hardcoded value can survive three "unrelated" tasks
   built directly on top of it, each with its own green test suite, because none of those
   suites asserted the thing that was actually wrong.

5. **Check whether the work is reachable by anyone else.** `git log --oneline main` vs.
   `git log --oneline origin/main`, and whether the branch under review is merged anywhere.
   A `PASS` on a branch nobody can `git pull` is not yet a fact about the project — it's a
   fact about one laptop.

## Detecting a self-graded PASS mechanically (for `business-analyst`)

Cheap, no code reading required, run on every pass over the tracker:

- **A `Status: PASS` task whose `## Review Notes` section is empty or still the literal
  template placeholder text is unreviewed by definition.** Flag it as `PASS but never
  reviewed` and recommend demoting to `Status: Review`, regardless of how confident the
  task file otherwise sounds.
- **A `Status: PASS` task whose `Dev Checkpoint` commit is not reachable from the
  component repo's `origin/main`** (`git branch -r --contains <sha>` against
  `origin/main` only) is `PASS` on an island. Report it as unreachable, separately from
  whether it's actually correct.
- **`git rev-list --count origin/main..main`** (or the equivalent for whatever branch the
  work is claimed against) greater than zero, sustained across more than one status check,
  is unpushed work accumulating — a standing project risk per
  `destructive-operations.md` §8, independent of code quality.

## For `dev-manager`: never relay a self-report as a verified fact

If a session is asked "is it all done" or receives an external tool's completion report:

1. Run the tracker check above first — this alone frequently answers the question, since
   the tracker's own `Pending`/`In Progress` counts are ground truth without needing to
   read a line of code.
2. For anything the tracker shows `PASS`, do not present it to the user as verified unless
   either `reviewer` genuinely ran against it in this session, or its `Review Notes`
   already show a prior real review — cite which.
3. State uncertainty plainly rather than rounding a self-report up to a fact: *"the task
   file says PASS; I have not independently verified it this session"* is a correct and
   useful sentence. Presenting an unverified self-report as verified is the failure mode
   this file exists to prevent.

## Building the technical gate, not just the written rule

A rule an external tool might not follow needs an enforcement point the tool cannot bypass
by ignoring text. Two layers, both tool-agnostic because they trigger on the `git` command
itself, not on which AI or human ran it:

**Layer 1 — a local `pre-commit` hook**, installed via `core.hooksPath` (tracked in the
repo, survives a fresh clone when `git-setup`/`devops-engineer` wires it at bootstrap,
unlike `.git/hooks/` which is never tracked). Blocks any commit that changes a task file's
`Status:` line to `PASS` unless that same file already contains a non-placeholder
`## Review Notes` section. This catches incident #1 at commit time, before it ever reaches
a branch, regardless of which tool is running `git commit`.

**Layer 2 — a CI check** on the repo holding the task files (typically the parent), running
on every push, doing the same check server-side. This is the layer that holds even if the
local hook was never installed on a given machine, or `core.hooksPath` was reset.

Neither layer can verify *correctness* — that still requires the protocol above. What they
enforce is *process*: a `PASS` with no review record cannot exist past the commit that
creates it, on any machine, by any tool.

`dev-manager` step 3a instantiates both alongside `AGENTS.md` at project start, not
`AGENTS.md` alone. If a project already exists without them (as Happy Bonding did when this
file was written), install both retroactively — see `scripts/hooks/README.md` in the
project's parent repo for the working implementation.
