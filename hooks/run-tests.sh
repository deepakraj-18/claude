#!/usr/bin/env bash
# run-tests.sh
# Deterministic test runner for the Development Loop. Keeps "did the tests pass" out of
# model reasoning — this script's exit code is the source of truth for dev-manager,
# tester, and reviewer.
#
# Usage:
#   run-tests.sh                        # full suite
#   run-tests.sh <path> [<path> ...]    # scoped run — only these test files/projects
#
# Scoped runs matter for token cost: on a retry, only the tests tied to this task need
# re-running. Pass the paths from the task's Relevant Files (or their test counterparts);
# use no arguments for the pre-review full run.
#
# Detection order is deliberate: .NET is checked BEFORE npm, because a full-stack repo
# with a frontend under src/ would otherwise match package.json and silently run only the
# JS tests while reporting success for the whole solution.
#
# Override with CLAUDE_TEST_CMD to bypass detection entirely (scope args pass through).
set -euo pipefail

scope=("$@")
has_scope=$(( ${#scope[@]} > 0 ? 1 : 0 ))

if [[ -n "${CLAUDE_TEST_CMD:-}" ]]; then
  echo "Running custom test command: $CLAUDE_TEST_CMD ${scope[*]-}"
  if (( has_scope )); then eval "$CLAUDE_TEST_CMD" "${scope[@]}"; else eval "$CLAUDE_TEST_CMD"; fi
  exit $?
fi

# --- .NET --------------------------------------------------------------------
# Checked first. A scoped run takes either a .csproj or a fully-qualified test filter.
#
# IMPORTANT: `dotnet test` on a solution still prints a green "Passed!" line for each
# project that built, even when a DIFFERENT project fails to compile. Anything that
# greps for "Passed!" therefore reads a false positive, and tests that never ran get
# reported as passing. This happened on TASK-003: an integration-test project with three
# compile errors was reported as "all criteria PASS / 61 tests passing" — the 61 were
# from the one project that did build.
#
# So: build explicitly first and stop on failure, before any test output can mislead.
dotnet_run() { # "$@" = args to dotnet test
  local out rc
  out="$(dotnet build ${target:+"$target"} --nologo 2>&1)"; rc=$?
  if (( rc != 0 )); then
    echo "$out" | grep -E "error|Error\(s\)" | head -20
    echo ""
    echo "########################################################################"
    echo "# BUILD FAILED — no tests were run. Any 'Passed!' line below is stale. #"
    echo "########################################################################"
    return 1
  fi
  dotnet test "$@"
}

sln="$(ls -1 ./*.sln 2>/dev/null | head -1 || true)"
if [[ -n "$sln" ]] || compgen -G "**/*.csproj" >/dev/null 2>&1; then
  target="${sln:-}"
  if (( has_scope )); then
    for s in "${scope[@]}"; do
      if [[ "$s" == *.csproj ]]; then
        echo "Detected .NET — running scoped project: dotnet test $s"
        dotnet_run "$s" --nologo
        exit $?
      fi
    done
    # Non-csproj scope args are treated as test-name filters.
    filter="$(printf '%s' "${scope[0]}" | sed -E 's#.*/##; s#\.(cs|csproj)$##')"
    echo "Detected .NET — running scoped filter: dotnet test ${target:-} --filter FullyQualifiedName~$filter"
    dotnet_run ${target:+"$target"} --nologo --filter "FullyQualifiedName~$filter"
    exit $?
  fi
  echo "Detected .NET — running: dotnet test ${target:-(all projects)}"
  dotnet_run ${target:+"$target"} --nologo
  exit $?
fi

# --- Node --------------------------------------------------------------------
if [[ -f package.json ]] && grep -q '"test"' package.json; then
  if (( has_scope )); then
    echo "Detected npm project — running scoped: ${scope[*]}"
    npx vitest run "${scope[@]}" 2>/dev/null || npx jest "${scope[@]}"
  else
    echo "Detected npm project — running: npm test"
    npm test
  fi
  exit $?
fi

# --- Python ------------------------------------------------------------------
if [[ -f pyproject.toml || -f pytest.ini || -f setup.cfg ]]; then
  if (( has_scope )); then
    echo "Detected Python project — running scoped: pytest ${scope[*]}"
    pytest "${scope[@]}"
  else
    echo "Detected Python project — running: pytest"
    pytest
  fi
  exit $?
fi

# --- Go ----------------------------------------------------------------------
if [[ -f go.mod ]]; then
  if (( has_scope )); then
    echo "Detected Go project — running scoped: go test ${scope[*]}"
    go test "${scope[@]}"
  else
    echo "Detected Go project — running: go test ./..."
    go test ./...
  fi
  exit $?
fi

# --- Rust --------------------------------------------------------------------
if [[ -f Cargo.toml ]]; then
  if (( has_scope )); then
    echo "Detected Rust project — running scoped: cargo test ${scope[*]}"
    cargo test "${scope[@]}"
  else
    echo "Detected Rust project — running: cargo test"
    cargo test
  fi
  exit $?
fi

echo "No recognized test setup found. Set CLAUDE_TEST_CMD to your test command." >&2
exit 2
