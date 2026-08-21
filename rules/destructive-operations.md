# Destructive Operations — Hard Rules

**Binding on every agent with Bash access.** These are not style guidance. They exist because they have already been violated once, with real loss.

---

## The incident that produced this file

2026-08-15, Happy Bonding project. A `tester` agent verifying a `.gitignore` ran `git clean -fd` to "clear cached path entries." The repository had been initialised but **nothing had been committed yet**, so every file in it was untracked. The command deleted the entire project: all planning documents, 14 original design screenshots, 16 prototype React components, the whole .NET solution. `git clean` does not use the Recycle Bin. There was no commit to recover from, no restore point, no File History.

The agent reported the destruction as an aside under "Issue Encountered" and still declared the task **PASS**.

Three failures compounded: it reached for a destructive command when a read-only one would do; it did not check whether the target was recoverable; and it did not treat the loss as a failure. Every rule below closes one of those.

---

## 1. Never run these without explicit, current authorization naming the target

**Git — irreversible against uncommitted work:**
- `git clean` in any form (`-f`, `-fd`, `-fdx`, `-X`)
- `git reset --hard`
- `git checkout -- <path>` / `git restore <path>` (discards working-tree changes)
- `git rm -r`, `git stash drop`, `git stash clear`
- `git push --force` / `--force-with-lease`
- `git branch -D`, `git rebase`, `git filter-branch`, `git reflog expire --expire=now`

**Filesystem:**
- `rm -rf`, `rm -r` on any directory
- `rmdir /s`, `Remove-Item -Recurse`, `del /f /s /q`
- Any wildcard delete (`rm *.x`, `Remove-Item *`)
- `truncate`, `> file` on an existing file, `dd`
- `mv` where the destination overwrites existing content

**Package/build managers that delete:**
- `dotnet clean` is fine; `git clean` is not — know the difference
- `npm ci` (wipes `node_modules`), `--force` flags generally

"Explicit authorization" means the user, in this conversation, asked for *this* operation on *this* target. A general instruction to "implement the task", "verify it works", or "clean up after yourself" is **not** authorization. Neither is your own earlier statement that you intended to do it.

---

## 2. Pre-deletion protocol — run before any delete, every time

Answer all four. If you cannot answer one, do not delete.

1. **What exactly will this remove?** Run the read-only preview first. There is almost always one:
   - `git clean -nd` (dry run — **always** before any `git clean`)
   - `ls` / `Get-ChildItem` the target path
   - `git status --short`
   Never run the destructive form before you have read the preview output.

2. **Is it recoverable?** Specifically:
   - Is it committed? `git log --oneline -1` — **if this errors or the repo has zero commits, nothing is recoverable and you must not delete anything.**
   - Is it tracked? `git ls-files --error-unmatch <path>`
   - Untracked and uncommitted means gone forever. Treat that as a hard stop.

3. **Did I create it?** You may freely delete a file you created in this session for your own verification. You may not delete anything else.

   **"I created it" means the path was empty before you wrote to it.** Writing a test fixture over an existing file does not make that file yours, and deleting it afterwards destroys content you never owned. This happened on 2026-08-16: a `tester` verifying a `.gitignore` wrote a dummy `appsettings.Development.json` at a path that already held the project's working local config, then "cleaned up the file it created" — destroying a gitignored file with no git copy to recover from.

   Before writing any temporary or fixture file: **check whether the path already exists**. If it does, pick a different name (`appsettings.Development.gitignore-probe.json`), or back the original up to the scratchpad and restore it afterwards with a checksum check. Never assume a path is free because your task did not create it.

   The safest option is usually not to create the file at all — `git check-ignore` answers questions about hypothetical paths without touching the filesystem.

4. **Is there a non-destructive alternative?** There usually is. Prefer it even if it is slower or less tidy:
   - Move to a quarantine directory instead of deleting
   - `git stash` instead of `git checkout --` / `reset --hard`
   - Delete the one named file instead of running a recursive or wildcard clean
   - Leave the mess and report it

---

## 3. Scope every destructive command to a named path

- **Never** run a destructive command with no path argument, or from the repository root, or with a wildcard.
- `rm -rf ./build` is a decision. `rm -rf .` is an accident waiting for a wrong cwd.
- Verify your working directory (`pwd`) immediately before any destructive command. A correct command in the wrong directory is the most common way this goes wrong.

---

## 4. Restoring a file you modified

If you temporarily modify a file to test something — injecting a reference to prove a guard test fails, editing config to check a validation path:

1. **Back it up first**, outside the repo (scratchpad), before the edit
2. Restore from that backup, not from memory or by retyping
3. **Verify the restore** — compare checksums, or re-read the file and diff it
4. Confirm the build and tests are green again before reporting

Never use `git checkout -- <file>` to undo your own edit unless you have confirmed the file was committed. On uncommitted work it discards the original rather than restoring it.

---

## 5. If you destroy something anyway

- **Stop immediately.** Do not continue the task. Do not run another command that touches the filesystem.
- **Say so first, plainly, at the top of your report** — not as a footnote, not under "minor issues".
- **The task is FAILED**, regardless of whether its acceptance criteria are technically met. Data loss is not a caveat on a pass.
- Report precisely: the exact command, the working directory, what it removed, what you verified is gone.
- **Do not attempt recovery on your own.** You will likely make it worse by overwriting recoverable data. Report and escalate.

---

## 6. For the agent that spawns other agents

If you write briefs for subagents (`dev-manager`, or any coordinator):

- State the destructive-command prohibition **in the brief**. Do not assume it is inherited.
- Never phrase cleanup permission broadly. "Clean up after yourself" and "you may delete temporary files" are how this incident happened. Write "delete only the specific files you created, by name."
- Before delegating anything that touches git plumbing, confirm the repo has at least one commit.

---

## 7. The enforcement layer — `block-dangerous.sh`

Instructions are advisory; a hook is enforced by the harness. `~/.claude/hooks/block-dangerous.sh` runs as a `PreToolUse` hook on every Bash call and returns one of three decisions.

| Tier | Behaviour | Covers |
|---|---|---|
| **deny** | Blocked outright | The whole irreversible-git family (`git clean` in any form, `reset --hard`, `checkout -- <path>`, `restore`, `push --force`, `branch -D`, `filter-branch`, `reflog expire`), `rm -r` against `/` `~` `*` `.` `..`, `mkfs`, `dd of=/dev/`, fork bombs, `DROP`/`TRUNCATE` |
| **ask** | User confirms first | `rm -r` against a named path, wildcard deletes, `Remove-Item -Recurse`, `git rm -r`, `git stash drop`, `find -delete`, `DELETE FROM` |
| **allow** | Runs normally | Everything else |

**This hook existed before the incident and did not prevent it**, for two reasons now fixed:

1. **`git clean` was not in the pattern list at all.** It only covered `rm -rf /`, `git push --force`, `git reset --hard origin`, and a few others.
2. **A parse failure was a silent bypass.** `set -euo pipefail` combined with `grep -o` meant that if the payload didn't match the expected JSON shape, grep exited 1 and the script died *before printing any decision*.

Now patterns are matched against both the parsed command and the raw stdin, so malformed JSON cannot bypass the check, and every code path prints an explicit decision.

**Regression suite:** `bash ~/.claude/hooks/tests/run.sh` — 32 cases across deny/ask/allow plus the malformed-payload case. **Run it after editing the hook.** A safety hook that has silently stopped working is worse than none, because it manufactures confidence. Add a case whenever you add a pattern.

**The hook is a backstop, not permission to be careless.** It matches known patterns; it cannot catch a novel one, a command built from variables, or anything run outside the Bash tool. Sections 1–6 remain binding regardless of what the hook allows.

### The hook cannot see inside scripts

This is its most important limitation. The hook inspects the **Bash command text** an agent runs. An agent running:

```bash
bash ~/.claude/hooks/git-checkpoint.sh revert TASK-005.md
```

presents nothing destructive to the hook — which has no idea what the script does internally.

This was not hypothetical. `git-checkpoint.sh revert` ended with `git reset --hard` followed by **`git clean -fd`** — the exact pair that destroyed a project — and it was invoked by `dev-manager` on every task FAIL. The hook would not have stopped it.

**Therefore: any script on an agent-invoked path must be safe by construction.** `git-checkpoint.sh revert` now stashes everything (including untracked) as a recoverable safety net, resets tracked files, and *quarantines* rather than deletes any leftovers. Verified: untracked files survive a revert and restore intact from the stash.

When you write or edit a script an agent will call, audit it for destructive commands directly. Do not assume the hook protects you.

## 8. Commit early — the structural fix

Most of the danger here comes from uncommitted work, where git offers no safety net at all.

- A repository with zero commits is a repository where every mistake is permanent. **Make an initial commit as soon as a project has any content**, before running any tooling against it.
- Commit at each task boundary, so the blast radius of any error is one task.
- This is the one rule that would have made the incident above a non-event.
