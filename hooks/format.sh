#!/usr/bin/env bash
# format.sh
# Deterministic formatter, run after edits so no model turn is spent deciding
# whether to format. Auto-detects common formatters; override with CLAUDE_FORMAT_CMD.
set -euo pipefail

if [[ -n "${CLAUDE_FORMAT_CMD:-}" ]]; then
  echo "Running custom format command: $CLAUDE_FORMAT_CMD"
  eval "$CLAUDE_FORMAT_CMD"
  exit $?
fi

if [[ -f package.json ]] && grep -q '"prettier"' package.json 2>/dev/null; then
  echo "Running prettier --write ."
  npx prettier --write . >/dev/null
elif [[ -f pyproject.toml ]] && grep -q 'black' pyproject.toml 2>/dev/null; then
  echo "Running black ."
  black . >/dev/null
elif [[ -f go.mod ]]; then
  echo "Running gofmt -w ."
  gofmt -w .
elif [[ -f Cargo.toml ]]; then
  echo "Running cargo fmt"
  cargo fmt
else
  echo "No recognized formatter found — skipping (set CLAUDE_FORMAT_CMD to enable)."
fi
