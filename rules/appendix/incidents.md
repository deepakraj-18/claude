# Incident Appendix

Full write-ups moved out of the rule files so they are not billed into every agent context.
The rules themselves live in `~/.claude/rules/`. Read this only when you need the "why"
behind a rule or are editing the rule.

---

## 2026-08-15 — `git clean -fd` destroyed an uncommitted project

**Rule file:** `destructive-operations.md`

Happy Bonding. A `tester` agent verifying a `.gitignore` ran `git clean -fd` to "clear
cached path entries." The repo had been initialised but **nothing had been committed**, so
every file was untracked. The command deleted the entire project: all planning documents,
14 original design screenshots, 16 prototype React components, the whole .NET solution.
`git clean` does not use the Recycle Bin. No commit to recover from, no restore point, no
File History.

The agent reported the destruction as an aside under "Issue Encountered" and still declared
the task **PASS**.

Three failures compounded: it reached for a destructive command when a read-only one would
do; it did not check whether the target was recoverable; it did not treat the loss as a
failure. `destructive-operations.md` §§1–8 each close one of these.

---

## 2026-08-16 — "cleaned up the file it created" destroyed pre-existing gitignored config

**Rule file:** `destructive-operations.md` §2 rule 3

A `tester` verifying a `.gitignore` wrote a dummy `appsettings.Development.json` at a path
that already held the project's working local config, then "cleaned up the file it created"
— destroying a gitignored file with no git copy to recover from. "I created it" must mean
*the path was empty before you wrote to it*.

---

## `block-dangerous.sh` — why it did not prevent 2026-08-15

**Rule file:** `destructive-operations.md` §7

Two reasons, both since fixed:

1. **`git clean` was not in the pattern list at all.** It covered `rm -rf /`,
   `git push --force`, `git reset --hard origin`, and a few others — not `git clean`.
2. **A parse failure was a silent bypass.** `set -euo pipefail` plus `grep -o` meant that
   if the payload didn't match the expected JSON shape, grep exited 1 and the script died
   *before printing any decision*.

Now patterns match against both the parsed command and the raw stdin, so malformed JSON
cannot bypass the check, and every code path prints an explicit decision. Regression suite:
`bash ~/.claude/hooks/tests/run.sh` — 32 cases across deny/ask/allow plus the
malformed-payload case.

### The hook cannot see inside scripts

The hook inspects the Bash command text an agent runs. `bash git-checkpoint.sh revert
TASK-005.md` presents nothing destructive to it. This was not hypothetical:
`git-checkpoint.sh revert` once ended with `git reset --hard` followed by `git clean -fd` —
the exact pair that destroyed the project — invoked by `dev-manager` on every task FAIL.
`revert` now stashes everything (including untracked) as a recoverable net, resets tracked
files, and *quarantines* rather than deletes leftovers. Any script on an agent-invoked path
must be safe by construction — audit it directly, don't assume the hook protects you.

---

## Happy Bonding — three external-tool incidents, each with the rule already written

**Rule file:** `external-agents.md`

1. **`AGENTS.md` §7 says the developer must never set `Status: PASS` — only the reviewer
   may.** Task `BD005` was reviewed, returned `FAIL` with a written retry brief, and nine
   days later was found back at `Status: PASS` with both original defects still unfixed.
   Something set it to `PASS` directly, skipping review.
2. **`AGENTS.md` §9 says push the branch as part of finishing a task.** 24 backend commits
   — an entire feature stream — sat committed locally and never reached `origin` for over a
   week, found only when a session happened to run `git fetch` and compare.
3. **A "tax engine" task whose entire job was fixing a hardcoded-zero GST bug shipped with
   the bug still present** — the rate resolves correctly now, but
   `CgstAmount`/`SgstAmount`/`IgstAmount` are still hardcoded to `0m` at the line-item
   level, on the very branch built to fix that. The submitted `Test Results` reported
   success.

Also found via the verification protocol: unauthenticated write access to two controllers
(invisible in the diff, one `curl` with no `Authorization` header to prove); a database
idempotency guard actually enforced by a different mechanism than the pre-check appeared to
protect (invisible without re-injecting the regression personally); a review clone
colliding with a live `dotnet run` over a shared port + shared LocalDB name despite a
separate file tree.

---

## The five ways a guard silently checked nothing (six tasks, one project)

**Rule file:** `guard-tests.md`

| # | What happened | Why it passed |
|---|---|---|
| 1 | An empty `UnitTest1.Test1()` template stub cited as evidence tests ran | It genuinely passed — asserted nothing |
| 2 | Enumerated constants had "contains" assertions, no completeness check | Renaming `Shipped` → `Dispatched` kept the count and the members checked for |
| 3 | An integration project had three compile errors so its tests never ran, while "61/61 passing" was reported | The 61 came from a *different* project in the same solution |
| 4 | A UTC value converter existed only in the test's own `TestDbContext`; production had none | The test validated its own setup, in a parallel context |
| 5 | A money-column test filtered by `LIKE '%Amount%'` and silently excluded one of the six columns the criterion named | The filter looked exhaustive and was not |

Reviewers on this project demonstrated a guard failure by hand twice and found one genuine
guard and one that needed rewriting — inspection alone would have passed both.
