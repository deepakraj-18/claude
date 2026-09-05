# AGENTS.md — external agent template

**This is a template.** `dev-manager` instantiates it into each component repo at project
start, one copy per repo (backend, frontend, mobile), filling every `<...>` placeholder
from `requirements.md`, `plan.md`, and the confirmed stack.

**Why this file exists.** Claude Code agents read `~/.claude/agents/*.md` and
`~/.claude/rules/*.md`. Antigravity, Cursor, Copilot, Codex, and every other tool read
**none of them**. `AGENTS.md` at a repo root is the cross-tool convention they *do* read.
So this file must be **self-contained**: inline the rules, never link to `~/.claude/`.
An external agent cannot follow a rule it cannot see.

**Instantiation rules for `dev-manager`:**

1. Copy to `<repo>/AGENTS.md` in **every component repo**, not the parent.
2. Replace every `<placeholder>`. Leave none — a placeholder that ships reads as noise and
   trains the agent to skim.
3. Inline the **full text** of the rules for that repo's stack from `~/.claude/rules/`.
   Summarising loses the specific line that matters. On Happy Bonding, a summarised REST
   section omitted "deleting a non-existent resource returns 204, not 404", and BD005
   failed review on exactly that.
4. Fill §5 (Traps) as an **empty section with a heading** at project start. It is
   populated over time from review findings — that is the section that earns its keep.
5. Re-instantiate is not re-generate: when updating, **preserve §5**, which accumulates.

Delete this whole block when instantiating.

---

# <Project> — <Component> Agent Brief

**Read this file completely before writing any code.** It is self-contained on purpose: it
inlines every rule that governs this repository. There is no other rule file to fetch.

You are working on **<component> only**. Do not touch <other component> repositories.

---

## Who else is working on this project

You are not working alone, and you are not the architect. This project is planned,
tracked, and reviewed by an AI coordination system on the human's side (Claude, via Claude
Code) that you cannot see or message directly — you only see its output, in this file and
in the task files at `../.claude-context/tasks/`. Knowing the shape of that process is what
makes the rules below make sense, rather than reading as arbitrary restrictions.

Concretely, before any task file reached you:
- Requirements were gathered and turned into an approved plan.
- That plan was broken into the individual task files you work from — one task, one file,
  with acceptance criteria already decided. If a criterion looks wrong, say so in your
  report; don't quietly implement something different because you think it's better.
- Tasks were sequenced by real dependencies, not by number — see §7.

After you submit a task:
- **Someone else reviews it independently before it counts as done.** Not you, and not
  automatic. Your own `Test Results` are your account of what you ran, not the basis the
  review works from — expect it to be re-run from scratch. This is why §7 says you may only
  ever set `Status: Review`, never `PASS`.
- **Project status is tracked from the repository, not from what you report.** A status
  report to the human doesn't come from your notes; it comes from checking the code and
  the tracker against each other.
- **You may not be the only implementer on this repo.** A human, another AI tool, or
  Claude's own implementer may work here too — sometimes on the same repo in the same
  week. This is normal, not an exception. It's why §7 requires **claiming** a task (writing
  `Claimed By`/`Claimed At` and pushing that *before* you start implementing) — so two of
  us can't silently work the same task at once.

None of this requires you to do anything differently day to day beyond what §7 and §8
already say — claim before you implement, set `Review` not `PASS`, report honestly. It's
here so those rules read as "this is how the team works," not as unexplained restrictions
you might reasonably decide don't apply this once.

---

## 1. What this project is

<2–4 sentences from requirements.md: what the product does and who uses it.>

<State the 1–3 consequences that shape every decision. Be concrete about what a bug
actually costs — "the bot quotes prices to real customers, so a wrong price is a wrong
amount charged to a person" beats "quality matters".>

## 2. Stack and structure

| Layer | Technology |
|---|---|
| <Runtime> | <e.g. .NET 9 — note any LTS/version debt> |
| <API/UI> | <framework> |
| <Data> | <ORM + database> |
| <Logging> | <library> |
| <Tests> | <framework> |

```
<directory tree, depth 2, with a one-line purpose per directory>
```

<State the dependency direction and anything that must not reference anything else.>

### Commands

```bash
<install> / <build> / <test full> / <test scoped> / <run> / <migration>
```

**Current baseline: <N> tests passing (<X> unit, <Y> integration). Never report a number
lower than this as "passing" without explaining which tests you removed and why.**

---

## 3. HARD SAFETY RULES — read before any shell command

<If the project has a real incident, tell it here in two or three sentences: what command,
what was lost, whether it was recoverable. A concrete story is followed; an abstract
warning is skimmed. If there is no incident yet, keep the rules and drop the story.>

### Never run these. There is no <component> task that requires them.

- The git working-tree cleaning command (`clean`), in **any** form or flag combination
- `git reset --hard`
- `git checkout -- <path>` and `git restore <path>` — these discard uncommitted work
- `git rm -r`, `git stash drop`, `git stash clear`
- `git push --force`, `git branch -D`, `git filter-branch`
- `rm -rf`, `rm -r`, `Remove-Item -Recurse`, `del /f /s /q`
- Any wildcard delete
- Redirecting over an existing file, `truncate`, `dd`
- `DROP DATABASE`, `TRUNCATE TABLE`

<Note any same-named safe command, e.g. "`dotnet clean` is fine. The git one is not.">

### Before deleting anything, answer all four. Cannot answer one? Do not delete.

1. **What exactly will this remove?** Run the read-only preview first: `git status
   --short`, `ls <path>`. Never run the destructive form before reading the preview.
2. **Is it recoverable?** `git log --oneline -1`. If that errors or the repo has no
   commits, nothing is recoverable — stop.
3. **Did I create it?** "I created it" means **the path was empty before you wrote
   there.** Writing a fixture over an existing file does not make it yours.
4. **Is there a non-destructive alternative?** Move to a quarantine directory. Delete one
   named file, never a pattern.

### Modifying a file temporarily (you will do this to prove tests fail)

1. Back it up **outside the repo** first, and record a checksum
2. Restore **from that backup**, never with a git checkout or restore
3. **Verify the restore by comparing checksums**
4. Confirm the build and full suite are green again before reporting

### If you destroy something anyway

Stop. Do not run another filesystem command. Say so **at the top** of your report, not as
a footnote. The task is **failed** regardless of whether its criteria are met. Do not
attempt recovery — you will overwrite what is still recoverable.

---

## 4. TEST INTEGRITY — the rules that catch fake green

<If the project has caught fake-green tests, say how many and that review caught them all,
not the suite. Otherwise state these as standing rules.> They are binding.

### 4.1 Enumerate the population — never sample it

For any finite set (enum members, columns of a type, indexes, routes, roles, response
fields), cover the **whole population**. Prefer querying it over listing it.

A name heuristic — `LIKE '%Amount%'`, or a hand-written list of field names you expect to
be absent — silently misses whatever does not match the pattern. Use **exact-set
equality, not membership**: a `Contains` assertion survives a rename, wrongly. A count
check is not set equality; five members stays five when one is renamed.

### 4.2 Prove the guard fails

**A guard you have not watched fail is not yet a guard.**

1. Back the file up outside the repo, record the checksum
2. Inject the **exact** regression the guard exists to catch — not a nearby one
3. Run the test, **observe the failure and its message**
4. Restore from backup, **verify the checksum matches**
5. Re-run, confirm green

**Report both outputs.** "The test passes" says nothing about what it would do if the code
were wrong.

Picking the exact regression matters. On Happy Bonding an injection that defeated a seed
idempotency pre-check left all 25 tests passing — because a unique index, not the
pre-check, was doing the work. A near-miss injection proves nothing.

### 4.3 A fixture must never supply behaviour production lacks

If a test configures something to make its assertion pass, the assertion is about the
test. A test context must **derive from the production type** and call into it, never
re-declare configuration. When unsure, apply the **disabling test**: turn the production
feature off. If the test still passes, it was never testing production.

### 4.4 Never cite a count from one scope as evidence about another

Confirm the **build** succeeded across everything in scope, and that **every project you
claim for appears in the output with a real count**. "No test is available in X" means the
tests did not run. It is not a pass.

### 4.5 An empty or always-true test is a defect

Delete framework template stubs. An assertion-free test inflates the count and makes a
green run meaningless.

### 4.6 <Any project-specific test-execution constraint>

<e.g. "Test parallelism is disabled deliberately — integration tests share a database.
Do not re-enable parallel collections." Delete if not applicable.>

---

## 5. Project-specific traps

**Populated from review findings as they occur. Empty at project start — that is
expected.** Each entry is one defect that already reached review, written so the next
agent does not repeat it.

Format each as: what looks right, why it is wrong, and the correct form in code.

<At project start, seed with any traps already known from plan.md or technical_design.md —
non-obvious key strategies, framework quirks, ordering constraints. Otherwise leave the
heading and this note.>

---

## 6. Coding conventions

<Inline the FULL text of the applicable `~/.claude/rules/*.md` files for this repo's
stack. Do not summarise and do not link. For a backend that is typically the stack rule,
the database rule, api-design, error-handling, constants, db-migration, and performance;
for a frontend, the framework rule plus error-handling, constants, and performance.

Verbatim inclusion matters: BD005 on Happy Bonding failed review because a summarised REST
section kept the "DELETE → 204" status row but dropped the sentence "deleting a
non-existent resource returns 204, not 404". The agent had no way to know.>

---

## 7. The task system

Tasks live at `<path to tasks dir>`, one file per task.

| Prefix | Stream | Covers |
|---|---|---|
| `IF` | Infrastructure | repos, CI/CD, provisioning, deployment |
| `SC` | Scaffolding | project skeletons, constants, config, logging, middleware |
| `DB` | Database | entities, migrations, indexes, seed data |
| `BD` | Backend | use cases, endpoints, auth, integrations, business rules |
| `FD` | Frontend design | scaffold, routing, layout, screens, styling |
| `FI` | Frontend integration | typed clients, data fetching, wiring to real endpoints |

**The number is not the execution order. The `Dependencies:` field is.** A task is ready
only when every id in `Dependencies` has `Status: PASS`. Cross-stream dependencies are
normal.

### Task file header — who may write which field

```
Status:            <- REVIEWER ONLY. You must never set this to PASS.
Failed Stage:      <- reviewer only
Attempts:          <- increment by 1 when you start an attempt
Claimed By:        <- you: your tool name, written and pushed BEFORE you implement
Claimed At:        <- you: UTC timestamp, same commit as Claimed By
Last Checkpoint:   <- you: sha before you start
Dev Checkpoint:    <- you: sha after implementation
Dependencies:      <- planner only
```

**You set `Status: Review` when your work is ready, and nothing else.** Only the reviewer
sets `PASS` or `FAIL`. **Never overwrite a `FAIL` verdict or its Review Notes** — if you
disagree, say so in your report and stop. An agent that can rewrite its own verdict is not
being reviewed, and the tracker becomes a self-report.

**This is enforced, not just requested.** Task files live in the **parent** repo
(`../.claude-context/tasks/`), not here, so this repo's own commits can't set `Status`. But
whoever commits a `Status: PASS` change in the parent — a person or another session — is
rejected at commit time if `## Review Notes` isn't populated (parent repo's
`scripts/hooks/pre-commit`, wired via `core.hooksPath`), and checked again in CI on push. A
task marked `PASS` without a real review will not merge, regardless of whether the
underlying work is actually correct. Set `Status: Review` in your own report and stop —
someone else sets `PASS` once it's confirmed. **A task's `Test Results` are also
independently re-run before anything downstream depends on it** — the recorded transcript
is what you believe happened, not what the review is based on. Report exactly what you
tested and how, since a claim that doesn't reproduce is the finding, not the number of
tests you counted.

### <Any known ordering exception>

<e.g. "The bot price-quoting task depends on the tax engine two phases later. If you reach
it and the tax engine does not exist, stop and escalate." Delete if none.>

---

## 8. Your working loop, per task

### Check for a task brief first

Before anything else, look for `<briefs dir>/<ID>.md` (or `<ID>-retry.md` on a retry). If
one exists it is **binding and takes precedence over your own judgement about scope**. It
names the traps this specific task will hit, the exact files to change, what must *not*
change, and the guard proofs required.

If no brief exists, proceed from the task file alone — but if the task needs one (unclear
scope, a criterion you cannot see how to test, a conflict with this document), say so and
stop rather than guessing.

### The loop

Do **one task at a time**, in dependency order.

1. **Read the task file** in full — Description, Acceptance Criteria, Relevant Files.
2. **Claim it before touching code.** Record `Last Checkpoint` (current HEAD sha) together
   with `Claimed By` (your tool name) and `Claimed At` (UTC timestamp) in the same edit,
   commit that field-write **alone**, and **push it immediately** — before writing any
   implementation. This is what stops two tools picking up the same task at once: task
   files live in the parent repo, so whichever push lands first wins. If your push is
   rejected, pull and check — if someone else has claimed it, **stop and pick a different
   ready task.** A commit advancing `Status` past `Pending` with an empty `Claimed By` is
   rejected by this repo's review-discipline gate.
3. **Create the branch**: `<stream>/<ID>-<short-description>`. **Never commit to `main`.**
4. **Read the constants file** plus the files under Relevant Files. Do not explore broadly.
5. **Implement.** Where this document conflicts with an established repo pattern, follow
   the repo and note the conflict rather than silently picking one.
6. **Build clean.** Record `Dev Checkpoint`.
7. **Write tests from the Acceptance Criteria** — one per criterion minimum, written from
   the *contract*, not by reading your implementation back to itself. Apply every rule in §4.
8. **Prove at least one guard fails** (§4.2). Paste both outputs into `## Test Results`.
9. **Run the full suite unscoped.** Confirm ≥ baseline and that every test project reports
   a real count.
10. **Self-review against §4, §5 and the Definition of Done** before declaring done.
11. **Commit** to the branch as `[<ID>] <imperative summary>`, then set `Status: Review`
    and stop. Do not start the next task.

### Definition of done — all must hold

- [ ] Every acceptance criterion has a test that **would fail** if it were violated
- [ ] At least one guard demonstrated failing, with output recorded
- [ ] Full suite green, every test project reporting a real count, ≥ baseline
- [ ] **Every "must NOT contain / must NOT expose" criterion asserts an exact set**, never
      a list of guessed names — see §4.1
- [ ] No new hardcoded constants outside the constants file
- [ ] No entity/model exposed directly on the wire
- [ ] <stack-specific mandatory checks — error envelope, pagination, idempotency>
- [ ] No secret, token, or PII in any log statement
- [ ] Committed to a branch, not `main`; working tree clean
- [ ] `Status: Review` — **not** `PASS`

### When to stop and ask instead of deciding

Stop if the task appears to require an architecture change, a change to a public contract,
a runtime/framework version bump, a new configuration provider, a business rule not stated
in the task, or a migration that drops a column or table. **Write the question into the
task file and stop.** Do not make that call alone.

---

## 9. Git

- Branch: `<stream>/<ID>-<short-description>`
- Commit: `[<ID>] <imperative summary>`, ≤72 chars
- **No AI-attribution trailers and no co-author lines.** Commit message only
- Never commit secrets, local config files, build output, or dependency directories
- **Never commit directly to `main`; never force-push**

<If the repo is a submodule, state the ordering rule: a submodule records a commit SHA,
not a branch, so commit in the child → push the child → then the parent updates its
pointer. Pushing the parent first publishes a pointer to a commit that exists only on your
machine, and every other clone breaks.>

---

## 10. Next tasks, in dependency order

<Table: Order | ID | Title | Depends on. Keep it to the next ~10 tasks and refresh it when
the plan changes. Flag any dependency that is not yet PASS, and say plainly that starting
on an unverified foundation is not allowed.>
