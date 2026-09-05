#!/usr/bin/env bash
# TEMPLATE — instantiated by `devops-engineer` at project bootstrap into
# <parent-repo>/scripts/hooks/pre-commit, then wired via:
#   git config core.hooksPath scripts/hooks
#
# Enforces two task-file invariants at commit time, regardless of which tool or human
# runs `git commit` — Claude's own developer, an external tool (Cursor, Antigravity,
# Copilot, Codex), or a human editing the file by hand:
#
#   1. Status: PASS requires a real, non-placeholder Review Notes section.
#   2. Status past Pending requires a non-empty Claimed By field.
#
# Neither check can verify the work is actually correct or that the claim is honest —
# they only verify a record exists before the state transition is allowed to exist.
# Correctness is `reviewer`'s job, done separately; the claim race is resolved by whoever
# pushes first (see ~/.claude/rules/task-streams.md).
#
# Built from an incident on a real project: a task was reviewed FAIL, then found nine
# days later back at Status: PASS with the same defects still in the code — something set
# PASS directly, skipping review, and prose in that project's AGENTS.md asking developers
# not to do that did not stop it. See ~/.claude/rules/external-agents.md for the full
# incident record and why this is enforced rather than only requested.
set -euo pipefail

PLACEHOLDER='_(populated by reviewer on FAIL)_'
failed=0

# Only look at task files that are actually staged in this commit.
mapfile -t staged_task_files < <(git diff --cached --name-only --diff-filter=ACM -- '.claude-context/tasks/*/*.md')

for f in "${staged_task_files[@]}"; do
  [ -f "$f" ] || continue

  staged_content=$(git show ":$f" 2>/dev/null || true)

  # --- Check 1: PASS requires a real Review Notes section --------------------------
  if printf '%s\n' "$staged_content" | grep -qE '^Status: PASS[[:space:]]*$'; then
    review_notes=$(printf '%s\n' "$staged_content" | awk '/^## Review Notes/{flag=1; next} /^## /{flag=0} flag')
    trimmed=$(printf '%s' "$review_notes" | tr -d '[:space:]')

    if [ -z "$trimmed" ] || printf '%s' "$review_notes" | grep -qF "$PLACEHOLDER"; then
      echo "BLOCKED: $f sets Status: PASS but ## Review Notes is empty or still the" >&2
      echo "         template placeholder. PASS requires a real reviewer verdict written" >&2
      echo "         into this file first. Set Status: Review instead, or add the actual" >&2
      echo "         review findings to ## Review Notes before committing PASS." >&2
      echo "" >&2
      failed=1
    fi
  fi

  # --- Check 2: any Status past Pending requires a claim ----------------------------
  if printf '%s\n' "$staged_content" | grep -qE '^Status: (Implemented|Review|PASS)[[:space:]]*$'; then
    claimed_by=$(printf '%s\n' "$staged_content" | grep -E '^Claimed By:' | sed 's/^Claimed By:[[:space:]]*//')
    if [ -z "$claimed_by" ]; then
      echo "BLOCKED: $f advances Status past Pending but Claimed By is empty. Claim the" >&2
      echo "         task (Claimed By / Claimed At), commit and push that alone, before" >&2
      echo "         starting implementation — see ~/.claude/rules/task-streams.md. This" >&2
      echo "         is what stops two tools picking up the same task simultaneously." >&2
      echo "" >&2
      failed=1
    fi
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "See ~/.claude/rules/external-agents.md and ~/.claude/rules/task-streams.md for" >&2
  echo "why these are enforced at commit time rather than left as written convention." >&2
  exit 1
fi

exit 0
