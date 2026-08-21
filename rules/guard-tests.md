# Guard Tests — Rules for Claude

**Binding on `tester` and `reviewer`.** A guard test exists to fail when something regresses. A guard test that cannot fail is worse than no test at all: it retires the question, and everyone downstream believes the property is protected.

This file exists because that happened five times in six tasks on one project. Every instance passed CI, read as thorough, and checked less than it appeared to.

---

## The five ways a guard silently checks nothing

Each of these shipped, passed, and was caught only by review.

| # | What happened | Why it passed |
|---|---|---|
| 1 | An empty `UnitTest1.Test1()` template stub was cited as evidence tests ran | It genuinely passed — it asserted nothing |
| 2 | Enumerated constants had "contains" assertions, no completeness check | Renaming `Shipped` → `Dispatched` kept the count and the members it checked for |
| 3 | An integration project had three compile errors, so its tests never ran, while "61/61 passing" was reported | The 61 came from a *different* project in the same solution |
| 4 | A UTC value converter existed only in the test's own `TestDbContext`; production had none | The test validated its own setup, in a parallel context |
| 5 | A money-column test filtered by `LIKE '%Amount%'` and silently excluded one of the six columns the criterion named | The filter looked exhaustive and was not |

The common shape: **a number or a green tick that is true of something other than the thing being claimed.**

---

## 1. Enumerate the population — never sample it

For any finite set — enum members, columns of a type, indexes, routes, roles — the guard must cover the **whole population**, not a filter over it.

**Prefer querying the population over listing it.** A hardcoded list is a guard that needs maintenance and will drift; a population query stays correct as the system grows.

```csharp
// ❌ Heuristic filter — silently misses whatever doesn't match the pattern
WHERE COLUMN_NAME LIKE '%Amount%' OR COLUMN_NAME LIKE '%Price%'

// ⚠️ Explicit list — correct today, stale the moment a column is added
var money = new[] { "Subtotal", "TotalAmount", "CgstAmount", /* ... */ };

// ✅ Population query — self-maintaining, covers columns that don't exist yet
WHERE DATA_TYPE = 'decimal' AND (NUMERIC_PRECISION != 18 OR NUMERIC_SCALE != 2)
```

Use an explicit list only when there is no natural population to query, and then say in the test's name or a comment what keeps it in sync.

**Exact-set equality, not membership.** `Assert.Contains(x, set)` tells you one member survived. Compare the whole set:

```csharp
// ❌ Passes after a rename, an addition, or a removal
Assert.Contains("shipped", statuses);

// ✅ Fails on rename, addition, and removal alike
Assert.Equal(new HashSet<string> { "new","confirmed","shipped","delivered","cancelled" }, statuses);
```

A count check is not set equality — five members stays five when one is renamed.

## 2. Prove the guard fails

**A guard you have not watched fail is not yet a guard.** Before reporting a guard test complete:

1. Back up the file you will edit, to the scratchpad, and record a checksum
2. Inject the *exact* regression the guard exists to catch — not a nearby one
3. Run the test and observe the failure, with its message
4. Restore from the backup and verify the checksum matches
5. Re-run and confirm green

Report the failing output alongside the passing output. "The test passes" is not evidence about what it would do if the code were wrong.

Never restore with `git checkout --` or `git restore` — see `destructive-operations.md`. Restore from your backup.

## 3. A test fixture must never supply behaviour production lacks

If a test configures something to make its assertion pass, the assertion is about the test.

**Red flag:** the fixture has setup the production path does not have — a converter, a mapping, a default, a registration.

**Rule:** a fixture that exercises production behaviour must *derive from or delegate to* the production type. Given a `DbContext`, the test context inherits it and calls `base.OnModelCreating`. It does not re-declare the configuration.

When in doubt, apply the disabling test: turn the production feature off. If the test still passes, it was never testing production.

## 4. Never cite a number from one scope as evidence about another

A green summary line for one project says nothing about a sibling that failed to compile. Before quoting a test count:

- Confirm the **build** succeeded across everything in scope, not just that some tests ran
- Confirm every project you are claiming for **appears in the output with a real count**
- "No test is available in X" means the tests did not run — it is not a pass

Runners help here. `~/.claude/hooks/run-tests.sh` builds first and refuses to run tests on a build failure, precisely so a stale green line cannot mask a broken project.

## 5. An empty or always-true test is a defect

Delete `dotnet new` / framework template stubs rather than leaving them. An assertion-free test inflates the count and makes a green run meaningless. Never cite one as evidence.

---

## For `reviewer`

Test adequacy is part of the contract, not a courtesy pass. Judge every guard against:

- **Does it enumerate or sample?** A `LIKE`, a name heuristic, or a hand-written subset over a finite population is a FAIL.
- **Would it survive a rename?** Membership assertions usually would — wrongly.
- **Was a failure demonstrated?** If not, demonstrate it yourself before accepting. Reviewers on the project behind this file did exactly that twice and found one genuine guard and one that needed rewriting — inspection alone would have passed both.
- **Does the fixture configure what production should?** Compare test setup against production setup and account for every difference.
- **Do the claimed numbers match what actually ran?** Re-run rather than reading the recorded figure.

A task whose implementation is correct but whose tests cannot detect regression is a **FAIL on the tester**, not a pass with a note. The implementation is right today; the tests are what keep it right.
