# Task Brief — `<ID>` <title>

**How to use this template.** The reviewer (or whoever hands work to an external agent)
fills this in *before* the agent starts, and hands it over together with the task file.
The task file says *what* to build; this brief says *what will go wrong* and *what will be
checked*. Delete any section that genuinely does not apply — do not leave it blank.

Briefs live in `.claude-context/briefs/<ID>.md`, or `<ID>-retry.md` for a retry.

`dev-manager` writes these at step 3b. A brief is warranted when the task has non-obvious
traps, has a criterion whose obvious test would be too weak, or is a retry. **On a retry it
is mandatory.**

---

## Status going in

| | |
|---|---|
| Task | `.claude-context/tasks/<STREAM>/<ID>.md` |
| Branch | `<stream>/<ID>-<slug>` — create it, or continue if it exists |
| Base commit | `<sha>` |
| Dependencies | `<ID>` … — **all must be `PASS`**; list their status |
| Suite baseline | **N passing** (X unit, Y integration) — must not drop |

State plainly whether this is a first attempt or a retry. On a retry, say **which
criteria already pass and must not be touched** — a retry that rewrites working code is a
failure even if it ends green.

---

## Traps specific to this task

The single most valuable section. Standing rules live in `AGENTS.md`; this is where you
name the ones **this** task will actually collide with, before it happens.

Work through this list and keep only the live ones:

- **Money** — any `decimal` column is `decimal(18,2)`, including ones whose names contain
  neither "amount" nor "price"
- **Ids** — strings on the wire, never integers; COMB GUIDs, never `Guid.CreateVersion7()`
- **Idempotency** — `DELETE` on an unknown id returns 204; `GET`/`PUT` return 404
- **Pagination** — every collection paginated, default 20, max 100, over-max rejected 400
- **Validation** — all failing fields returned at once, not the first
- **Constants** — no literal that belongs in `AppConstants.cs`
- **Cascades** — nothing financial or legally retained cascade-deletes
- **EF exceptions** — provider errors arrive wrapped in `DbUpdateException`
- **Location scoping** — does this endpoint return data that must be scoped?
- **Logging** — no secret, token, or full phone number, at any level
- **Migration safety** — new columns nullable or defaulted

For each one kept, say concretely how it applies here. "Watch out for money" is useless;
"`OrderItem.TaxRatePercent` is a money column despite the name" is a brief.

---

## Exactly what to change

Name files and, where useful, show the before/after. Precision here is what buys a correct
first attempt instead of a review cycle.

**File:** `path/to/File.cs`

```csharp
// current
```

```csharp
// required
```

### Do NOT change

List the neighbouring things that look wrong but are correct, and say why. This is as
important as the change list — most retry damage comes from an agent "fixing" something
adjacent that was already right.

---

## Tests required

Per acceptance criterion, name the test and what it must assert. Be explicit where the
obvious assertion would be too weak:

- Any **"must not contain / must not expose"** criterion asserts an **exact set**, never a
  list of guessed names
- Any **finite population** (enum members, columns, routes, roles) is **enumerated**, not
  sampled — prefer querying the population over hardcoding a list
- No `Assert.Contains` where set equality is meaningful
- No fixture supplying behaviour production lacks — derive from the production type

## Guard proofs required (§4.2)

| Fix / criterion | Regression to inject | Test that must fail |
|---|---|---|
| | | |

Pick the **exact** regression the guard exists to catch, not a nearby one. A near-miss
injection proves nothing: on DB003 an injection that defeated the idempotency pre-check
left all 25 tests passing, because the unique index — not the pre-check — was doing the
work. Back up outside the repo, inject, observe the failure, restore from backup, verify
the checksum, re-run green, and paste **both** outputs.

---

## Definition of done

- [ ] Every acceptance criterion has a test that **would fail** if it were violated
- [ ] Every guard proof in the table above demonstrated, with both outputs recorded
- [ ] Full suite green, **both** projects reporting real counts, ≥ baseline
- [ ] No new constants outside `AppConstants.cs`; no entity exposed on the wire
- [ ] Errors use the standard envelope; collections paginated
- [ ] No secret, token, or PII in any log statement
- [ ] Working tree clean, committed as `[<ID>] <imperative summary>`
- [ ] `Status: Review`, `Dev Checkpoint` set to the new sha

## Do not

- Do not start any other task
- Do not reformat or rename outside the named files
- Do not weaken an assertion to make a test pass
- Stop and ask if the task appears to need an architecture change, a public-contract
  change, a `TargetFramework` bump, a new config provider, an unstated business rule, or a
  migration that drops a column or table
