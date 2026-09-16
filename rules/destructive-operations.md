# Destructive Operations — Hard Rules

**Binding on every agent with Bash access.** Not style guidance — violated once with total,
unrecoverable loss of a project. Full incident write-ups: `~/.claude/rules/appendix/incidents.md`.

## 1. Never run these without explicit, current authorization naming the target

- **Git:** `git clean` (any form), `git reset --hard`, `git checkout -- <path>` /
  `git restore <path>`, `git rm -r`, `git stash drop`/`clear`, `git push --force` /
  `--force-with-lease`, `git branch -D`, `git rebase`, `git filter-branch`,
  `git reflog expire`.
- **Filesystem:** `rm -rf` / `rm -r` on a directory, `rmdir /s`, `Remove-Item -Recurse`,
  `del /f /s /q`, any wildcard delete, `truncate`, `> file` on an existing file, `dd`,
  `mv` that overwrites existing content.
- **Build/pkg:** `npm ci` (wipes `node_modules`), `--force` flags. (`dotnet clean` is fine
  — it is not `git clean`.)

"Explicit authorization" = the user, in this conversation, asked for *this* operation on
*this* target. "Implement the task", "verify it works", "clean up after yourself" are not
authorization. Neither is your own earlier statement that you intended to do it.

## 2. Pre-deletion protocol — all four, every time

1. **What exactly will this remove?** Run the read-only preview first — `git clean -nd`,
   `ls`/`Get-ChildItem` the path, `git status --short`. Never run the destructive form
   before reading the preview.
2. **Is it recoverable?** Committed? `git log --oneline -1` — **if this errors or the repo
   has zero commits, nothing is recoverable; do not delete anything.** Tracked?
   `git ls-files --error-unmatch <path>`. Untracked + uncommitted = gone forever = hard stop.
3. **Did I create it?** You may delete a file you created this session for verification, and
   nothing else. "I created it" means **the path was empty before you wrote to it** —
   writing a fixture over an existing file does not make it yours. Before writing any
   temp/fixture file, check whether the path exists; if it does, use a different name or
   back up + restore with a checksum. Best option is often `git check-ignore`, which answers
   path questions without touching the filesystem.
4. **Is there a non-destructive alternative?** Usually yes — quarantine dir instead of
   delete, `git stash` instead of `checkout --`/`reset --hard`, delete one named file
   instead of a recursive/wildcard clean, or just leave the mess and report it.

## 3. Scope every destructive command to a named path

Never run one with no path argument, from the repo root, or with a wildcard. `rm -rf ./build`
is a decision; `rm -rf .` is an accident waiting for a wrong cwd. Verify `pwd` immediately
before.

## 4. Restoring a file you modified

Back it up to the scratchpad **before** the edit; restore from that backup, not from memory;
verify with a checksum or re-read+diff; confirm build/tests green before reporting. Never
`git checkout -- <file>` to undo your own edit unless you have confirmed the file was
committed — on uncommitted work it discards the original.

## 5. If you destroy something anyway

Stop immediately — no more filesystem commands. Say so plainly at the **top** of your
report, not as a footnote. The task is **FAILED** regardless of acceptance criteria. Report
the exact command, working directory, and what is gone. Do not attempt recovery yourself —
you will likely overwrite what is still recoverable. Escalate.

## 6. For the agent that spawns other agents

- State the destructive-command prohibition **in every brief** — subagents start cold, it
  is not inherited.
- Never phrase cleanup permission broadly. Write "delete only the specific files you
  created, by name" — not "clean up after yourself".
- Confirm the repo has ≥1 commit before delegating anything that touches git plumbing.

## 7. Enforcement — `block-dangerous.sh`

A `PreToolUse` hook on every Bash call, returning deny / ask / allow. It is a backstop, not
permission to be careless: it matches known patterns only — not a novel one, a command
built from variables, or anything outside the Bash tool. Sections 1–6 bind regardless of
what it allows.

**It cannot see inside scripts.** `bash git-checkpoint.sh revert …` presents nothing
destructive to the hook. So **any script on an agent-invoked path must be safe by
construction** — audit it for destructive commands directly when you write or edit it. Run
the regression suite (`bash ~/.claude/hooks/tests/run.sh`) after editing the hook, and add
a case with every new pattern. History + rationale: `appendix/incidents.md`.

## 8. Commit early — the structural fix

A repo with zero commits is one where every mistake is permanent. Make an initial commit as
soon as a project has any content, before running any tooling. Commit at every task
boundary so the blast radius of any error is one task. This single rule would have made the
founding incident a non-event.
