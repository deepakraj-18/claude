# Git Workflow Conventions (GitHub Flow)

These conventions apply to all git operations in the workflow. `dev-manager` must follow them when committing and branching; `developer` must follow them if making any git operations; `devops-engineer` owns repository topology and pipelines; all agents must respect branch context.

> **Destructive git commands are governed by `~/.claude/rules/destructive-operations.md`**, which is binding and takes precedence over anything here. `git clean`, `reset --hard`, `checkout -- <path>`, and `restore` are never run by an agent.

## Repository Topology — parent + submodules

Multi-component projects use a parent repository for documentation and context, with each independently-deployable component in its own repository, wired in as a submodule. `devops-engineer` owns this structure; see that agent's brief for the full bootstrap and maintenance procedure.

```
<project>/                              ← parent: docs, .claude-context, scripts, pointers. No app code.
├── <project>-frontend/  → submodule → <project>-frontend
├── <project>-backend/   → submodule → <project>-backend   (includes database/ — SQL + stored procs)
└── <project>-mobile/    → submodule → <project>-mobile
```

### Rule: every component lives INSIDE the parent directory

**Component working copies are subdirectories of the parent, never siblings of it.** A component checkout beside the parent is wrong, even before submodules are wired.

| | |
|---|---|
| ✅ Correct | `happybonding/happybonding-backend/` |
| ❌ Wrong | `happybonding-backend/` sitting beside `happybonding/` |

The directory sits inside the parent and carries the full qualified name. Those are two separate rules and both matter: inside, because the submodule path *is* that directory; fully named, because the path should mean the same thing everywhere it appears.

**Why this is a rule and not a preference:** the submodule path *is* the directory inside the parent. A sibling checkout has to be moved before it can be registered, so a sibling layout guarantees a later restructure — and moving repos around after work has accumulated is exactly when pointers, relative paths, and build outputs break. Clone the whole project by cloning the parent; nothing about the project should live outside that one directory.

### Naming

**The component directory name matches its remote repository name, exactly.**

| Thing | Convention | Example |
|---|---|---|
| Parent directory & repo | `<project>` | `happybonding` |
| Component directory (in parent) | `<project>-<component>` | `happybonding-backend` |
| Component remote repo | `<project>-<component>` | `happybonding-backend` |

Keeping them identical means a path in a log, a CI job, an error message, or a task file's `Repo:` field names one unambiguous thing whether you are reading it inside the parent or in a list of every repo the account owns. The shorter `backend/` form reads more cleanly inside the parent, but it forces a mental translation at every boundary — and each of those is a place a script or a person picks the wrong one.

Renaming later is not free: on Windows an editor holding a handle on a repository root blocks the directory rename outright, and the fallback is moving contents and repairing `.gitmodules` and the index by hand. Set the names correctly at bootstrap.

### No application code in the parent — ever

The parent holds `docs/`, `.claude-context/`, `scripts/`, `README.md`, `.gitmodules`, and the submodule pointers. It holds **no** `.sln`, `.csproj`, `package.json`, `src/`, or `tests/`.

If a scaffold lands in the parent root, it is in the wrong repository: move it into the owning component before committing. A solution at the parent root will build, pass its tests, and look entirely fine — which is what makes it easy to miss until the component needs to deploy on its own.

**Branching conventions below apply per-repository.** A feature touching both frontend and backend gets a `feature/TASK-0XX-*` branch in each repo, and a parent commit updating both pointers once the children are merged and pushed.

### The one rule everyone must know

**A submodule records a commit SHA, not a branch.** So the order is always:

1. Commit in the child → 2. **Push the child** → 3. `git add <path>` in the parent → 4. Commit the parent → 5. Push the parent

Pushing the parent before the child publishes a pointer to a commit that exists only on your machine, and every other clone breaks with `fatal: reference is not a tree`. Verify with `git submodule foreach 'git log @{u}.. --oneline'` — it must print nothing.

**Cloning:** `git clone --recurse-submodules`. A plain clone leaves every submodule directory empty.

**Working inside a submodule:** `git checkout main` first. `git submodule update` leaves detached HEAD, and commits made there are reachable from no branch and discarded by the next update.

## Branching Model — GitHub Flow

```
main (protected, always deployable)
 ├── feature/TASK-001-user-authentication
 ├── feature/TASK-002-order-api
 ├── bugfix/TASK-003-login-redirect
 └── hotfix/critical-payment-fix
```

### Branch Types

| Prefix | Purpose | Base branch | Merge target |
|---|---|---|---|
| `feature/` | New features and enhancements | `main` | `main` via PR |
| `bugfix/` | Bug fixes (non-critical) | `main` | `main` via PR |
| `hotfix/` | Critical production fixes | `main` | `main` via PR (expedited review) |

### Branch Naming

```
{type}/TASK-{id}-{short-description}
```

- Use the task ID from `.claude-context/tasks/TASK-*.md`
- Short description: 2-4 words, kebab-case
- Examples:
  - `feature/TASK-001-user-authentication`
  - `bugfix/TASK-003-login-redirect-loop`
  - `hotfix/critical-payment-timeout`

### Branch Lifecycle

1. **Create** feature branch from `main` before `developer` starts first task of a feature
2. **All tasks** for that feature are committed to the same feature branch
3. **PR** is created after all tasks PASS
4. **Merge** into `main` via squash merge (one clean commit per feature)
5. **Delete** the feature branch after merge

## Commit Messages

Format (enforced by the workflow):
```
[TASK-{id}] {summary}
```

- Summary: imperative mood, max 72 characters ("Add user login endpoint", not "Added user login endpoint")
- No co-author trailers or AI attribution (per `CLAUDE.md`)
- One commit per task (after reviewer PASS)

Examples:
```
[TASK-001] Add user authentication endpoint
[TASK-002] Create order placement API with validation
[TASK-003] Fix login redirect loop on expired sessions
```

## Pull Requests

### PR Title
```
[FEATURE] {feature name from plan.md}
```
or
```
[BUGFIX] {bug description}
[HOTFIX] {critical fix description}
```

### PR Description Template
```markdown
## Summary
{2-3 sentences from plan.md's Business Intent}

## Changes
{List of completed TASK-* IDs with one-line summaries from log.md}

## Testing
{Summary of test coverage from tester's work}

## Screenshots (if UI changes)
{Attach relevant screenshots}
```

### PR Rules
- **All tasks must be PASS** before PR is created
- **No direct commits to `main`** — everything goes through PRs
- **Squash merge** — one clean commit per feature on `main`
- **Delete branch** after merge

## Protected Branch Rules (`main`)

- Require PR before merge
- Require at least 1 approval (human review for the PR, even though agents reviewed individual tasks)
- Require status checks to pass (CI/CD)
- No force pushes
- No deletions

## When `dev-manager` Should Create Branches

- **New feature**: Create `feature/` branch before delegating first task to `developer`
- **Bug fix**: Create `bugfix/` branch before delegating to `developer`
- **Hotfix**: Create `hotfix/` branch — same flow but expedited (skip `gatherer`, use existing requirements)

## Git Hygiene

- **Never commit secrets**, API keys, connection strings, or `.env` files. Use `.gitignore` and environment variables.
- **Never commit build artifacts**, `node_modules/`, `bin/`, `obj/`, or generated files.
- **Keep `.gitignore` up to date** per stack (Node, .NET, etc.).
- **Pull before branch creation** — always branch from latest `main`.
