# Guard Tests — Rules for Claude

**Binding on `tester` and `reviewer`.** A guard test exists to fail when something
regresses. One that *cannot* fail is worse than none — it retires the question and everyone
downstream believes the property is protected. This happened five times in six tasks on one
project; every instance passed CI and checked less than it appeared to. The common shape:
**a number or a green tick that is true of something other than the thing being claimed.**
Full five-case table: `~/.claude/rules/appendix/incidents.md`.

## 1. Enumerate the population — never sample it

For any finite set — enum members, columns of a type, indexes, routes, roles — cover the
**whole population**, not a filter over it. Prefer *querying* the population to listing it;
a hardcoded list drifts.

```csharp
// ❌ heuristic filter — misses whatever doesn't match
WHERE COLUMN_NAME LIKE '%Amount%' OR COLUMN_NAME LIKE '%Price%'
// ✅ population query — self-maintaining
WHERE DATA_TYPE = 'decimal' AND (NUMERIC_PRECISION != 18 OR NUMERIC_SCALE != 2)
```

**Exact-set equality, not membership.** `Assert.Contains(x, set)` passes after a rename, an
addition, or a removal. `Assert.Equal(new HashSet<string>{...}, actual)` fails on all three.
A count check is not set equality — five members stays five when one is renamed.

**An acceptance criterion naming multiple paths is also a population.** "Action X from State
A or State B returns to menu" names two states — a test covering only State A is sampling,
not enumeration, and a regression injected into State B alone won't fail the suite. One test
per named path, minimum.

**Case study — rate limits.** A test suite backed by one shared `HttpClient`/client identity
cannot tell a per-client limiter from a global one; both look identical from a single caller.
`AddFixedWindowLimiter(name, opts => ...)`'s simple overload creates one global bucket for
every caller regardless of a comment claiming "per IP" — see `api-design.md`'s Rate Limiting
section. A multi-client guard needs separate `HttpClient`/IP identities and must assert that
one identity's consumption never reduces another's remaining quota.

## 2. Prove the guard fails

A guard you have not watched fail is not yet a guard. Before reporting one complete: back up
the file (scratchpad + checksum), inject the *exact* regression it exists to catch, run and
observe the failure message, restore from backup and verify the checksum, re-run green.
Report the failing output alongside the passing one. Never restore with `git checkout --` /
`git restore` (see `destructive-operations.md`) — restore from your backup.

## 3. A fixture must never supply behaviour production lacks

If a test configures something to make its assertion pass, the assertion is about the test.
Red flag: fixture setup the production path lacks — a converter, mapping, default,
registration. A fixture exercising production behaviour must *derive from or delegate to*
the production type (a test `DbContext` inherits it and calls `base.OnModelCreating`, it
does not re-declare config). Disabling test: turn the production feature off — if the test
still passes, it was never testing production.

**Self-referential assertions are the same failure in different clothes.** Asserting against
your own mock variable, or that a mock was *called*, proves the test invoked its own fixture
— not that the result reached production behaviour.

```tsx
// ❌ asserts against your own fixture — passes even if the fetched data never reached the DOM
expect(mockCourses).toEqual([...])
expect(apiClient.get).toHaveBeenCalledWith(url)

// ✅ asserts against rendered output — fails if the resolved value never populated the UI
expect(screen.getAllByRole('option')).toHaveLength(mockCourses.length)
```

## 4. Never cite a number from one scope as evidence about another

A green line for one project says nothing about a sibling that failed to compile. Before
quoting a test count: confirm the **build** succeeded across everything in scope; confirm
every project you claim for appears in the output with a real count; "no test is available
in X" means tests did not run, not a pass. `~/.claude/hooks/run-tests.sh` builds first and
refuses to run on a build failure, precisely so a stale green line can't mask a broken
project.

## 5. An empty or always-true test is a defect

Delete `dotnet new` / framework template stubs. An assertion-free test inflates the count
and makes a green run meaningless. Never cite one as evidence.

## For `reviewer`

Test adequacy is part of the contract. Judge every guard: Does it enumerate or sample (a
`LIKE`, name heuristic, or hand-written subset over a finite population is a FAIL)? Would it
survive a rename? Was a failure demonstrated — if not, demonstrate it yourself before
accepting. Does the fixture configure what production should? Do the claimed numbers match
what actually ran (re-run, don't read the recorded figure)? A correct implementation whose
tests cannot detect regression is a **FAIL on the tester**, not a pass with a note.
