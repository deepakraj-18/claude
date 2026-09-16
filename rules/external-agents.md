# External AI Developers — Rules for Claude

**Binding on `dev-manager`, `business-analyst`, `reviewer`.** Applies whenever a component
repo's implementation is done by a tool other than this session's own `developer`/`tester`
— Antigravity, Cursor, Copilot, Codex, a human. Happy Bonding runs exactly this: Antigravity
implements against each repo's `AGENTS.md`; Claude sessions plan, review, verify.

## The core fact

**An external tool cannot read `~/.claude/`.** All it knows is its repo's `AGENTS.md`. So a
rule that exists only as prose in `AGENTS.md` is a request, not a control — the tool can
misread it, skip it, or do the opposite. Three confirmed incidents on this project, each
with the rule already written down (full detail: `~/.claude/rules/appendix/incidents.md`):
a task self-set to `PASS` nine days after a `FAIL` with defects unfixed; 24 commits
unpushed for a week; a tax-engine task shipped with the exact hardcoded-zero bug it existed
to fix, reporting test success. Not bad faith — **treat instructions to an external tool as
a hint about intent, never a guarantee of behavior. Catch a violation mechanically, not
three weeks later by a human.**

## Verify, don't transcribe

An external tool's completion report is **input to review, not a substitute for it.**
Nothing moves past `Status: Review` on a self-report — not the `Status` field, not what a
Claude session tells the user, not the tracker. This binds **every Claude session**,
including a solo one with no `dev-manager` loop. If you are about to write `Status: PASS`,
or tell the user a task/phase/"everything" is done, because an external tool said so — stop
and run the protocol below first.

## Independent verification protocol

Heavier than `reviewer.md`'s default pass on purpose — the default assumes `tester`'s
recorded results came from a trusted in-session Claude agent, which does not hold here.

1. **Clone to an isolated path; never review in place.** The external tool may still be
   editing the live checkout.
   `git clone --local <repo> <scratch>` then `git -C <scratch> checkout <branch/sha>`.
   Copy in gitignored config the app needs (`appsettings.Development.json`, `.env.local`) —
   copy, never author new secrets. **A separate file tree is not enough** — the real
   collision was a shared port + shared LocalDB name. Before your review run: use a
   different port, append `_ReviewClone` to the DB name (never point a review run at the
   live DB, even read-only), and check for an already-bound port / running instance first.
2. **Build and run the real suite yourself.** "172 passing" is a claim — run it. For a web
   app, actually start it and exercise it as a client would: this project's worst finding
   (unauthenticated write access to two controllers) was invisible in the diff and took one
   `curl` with no `Authorization` header.
3. **Re-run at least one guard-proof fresh** (per `guard-tests.md`): inject the exact
   regression in the isolated clone, confirm the test fails, restore, confirm green. A
   pasted before/after transcript is not equivalent.
4. **Cross-check every prior finding, not just this task's scope.** A hardcoded value can
   survive three "unrelated" tasks built on top, each with its own green suite.
5. **Check reachability.** `git log --oneline main` vs `origin/main`, and whether the
   branch is merged anywhere. A `PASS` nobody can `git pull` is a fact about one laptop.

## Mechanical self-graded-PASS detection (for `business-analyst`)

Cheap, no code reading, every pass over the tracker:

- `Status: PASS` with an empty or placeholder `## Review Notes` = unreviewed by definition.
  Flag `PASS but never reviewed`, recommend demoting to `Status: Review`.
- `Status: PASS` whose `Dev Checkpoint` commit is not reachable from the component's
  `origin/main` (`git branch -r --contains <sha>`) = `PASS` on an island. Report as
  unreachable, separately from correctness.
- `git rev-list --count origin/main..main` > 0 sustained across more than one check =
  unpushed work accumulating, a standing risk per `destructive-operations.md` §8.

## For `dev-manager`: never relay a self-report as a verified fact

On "is it all done" or an external completion report: run the tracker check first (the
`Pending`/`In Progress` counts often settle it). For anything showing `PASS`, present it as
verified **only** if `reviewer` ran against it this session or `Review Notes` shows a prior
real review — cite which. "The task file says PASS; I have not independently verified it
this session" is a correct, useful sentence.

## The technical gate, not just the written rule

Two tool-agnostic layers, triggering on the `git` command itself:

- **Layer 1 — local `pre-commit` hook** via `core.hooksPath` (tracked; survives a fresh
  clone). Blocks any commit setting a task file's `Status:` to `PASS` without a
  non-placeholder `## Review Notes` section.
- **Layer 2 — CI check** on the repo holding the task files, same check server-side, holds
  even if the local hook was never installed.

Neither verifies correctness — that needs the protocol above. They enforce *process*: a
`PASS` with no review record cannot exist past the commit that creates it. `dev-manager`
step 3a instantiates both alongside `AGENTS.md`. Retrofit both if a project predates them —
see `scripts/hooks/README.md` in the parent repo.
