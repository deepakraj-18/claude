#!/usr/bin/env bash
# git-checkpoint.sh
# Checkpoint / revert / commit mechanics for the Development Loop, kept deterministic
# rather than model-decided.
#
# Usage:
#   git-checkpoint.sh check-clean                     # exit 1 if working tree is dirty
#   git-checkpoint.sh record <task-file> [field]      # write HEAD sha into "<field>:" (default "Last Checkpoint")
#   git-checkpoint.sh revert <task-file> [field]      # restore tree to the recorded sha, SAFELY
#   git-checkpoint.sh commit <task-id> <message>      # commit all changes tagged with the task id
#
# Two named checkpoints:
#   "Last Checkpoint" — sha before developer starts
#   "Dev Checkpoint"  — sha after developer finishes, before tester starts
# A tester FAIL reverts to "Dev Checkpoint" (keeps the implementation); a developer FAIL
# reverts to "Last Checkpoint" (redoes both).
#
# ---------------------------------------------------------------------------
# SAFETY NOTICE — read before editing `revert`
# ---------------------------------------------------------------------------
# This script previously ended `revert` with:
#     git reset --hard "$sha"
#     git clean -fd            # <-- REMOVED
#
# That is the exact command pair that destroyed an entire project on 2026-08-15:
# `git clean -fd` deletes untracked files, which in a repo with no commits (or any
# repo holding uncommitted docs, context, or assets) means everything. It does not
# use the Recycle Bin and nothing recovers it.
#
# It was especially dangerous here because the PreToolUse hook
# (~/.claude/hooks/block-dangerous.sh) inspects the *Bash command text* an agent
# runs. An agent invoking `bash git-checkpoint.sh revert ...` presents nothing
# destructive to the hook — the hook cannot see inside a script. Scripts on this
# path must therefore be safe by construction, not by expecting the hook to catch
# them.
#
# `revert` now:
#   1. stashes everything (including untracked) as a recoverable safety net
#   2. resets to the recorded sha
#   3. QUARANTINES leftover untracked files instead of deleting them
# Nothing on this path destroys data. See ~/.claude/rules/destructive-operations.md
# ---------------------------------------------------------------------------
set -euo pipefail

cmd="${1:-}"
DEFAULT_FIELD="Last Checkpoint"

checkpoint_field() {
  local task_file="$1"
  local field="$2"
  grep -m1 "^${field}:" "$task_file" | sed -E "s/^${field}:[[:space:]]*//"
}

# --- Multi-repo support ------------------------------------------------------
# Task files live in the PARENT repo (.claude-context/tasks/) but the code they
# describe usually lives in a COMPONENT repo (backend/, frontend/). Recording a
# checkpoint from the parent stores a commit that does not exist in the component
# — so a later revert would target the wrong repository entirely.
#
# Each task file declares `Repo: backend|frontend|parent`. We cd into that repo
# before running any git command. Caught by a reviewer on TASK-001, where the
# checkpoint held a parent sha for work committed in backend/.
resolve_repo() {
  local task_file="$1"
  local tasks_dir parent repo
  tasks_dir="$(cd "$(dirname "$task_file")" && pwd)"
  parent="$(cd "$tasks_dir/../.." && pwd)"          # .claude-context/tasks -> parent root
  repo="$(grep -m1 '^Repo:' "$task_file" | sed -E 's/^Repo:[[:space:]]*//' | tr -d '\r')"
  case "$repo" in
    ""|parent) printf '%s' "$parent" ;;
    *)
      if [[ -d "$parent/$repo/.git" ]]; then printf '%s' "$parent/$repo"
      else
        echo "ERROR: task declares 'Repo: $repo' but $parent/$repo is not a git repository." >&2
        exit 1
      fi ;;
  esac
}

case "$cmd" in
  check-clean)
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "Working tree is not clean. Commit, stash, or revert before selecting a new task." >&2
      exit 1
    fi
    echo "Working tree clean."
    ;;

  record)
    task_file="${2:?usage: git-checkpoint.sh record <task-file> [field-name]}"
    field="${3:-$DEFAULT_FIELD}"
    # Absolutise BEFORE cd, or the write-back below targets the wrong path.
    task_file="$(cd "$(dirname "$task_file")" && pwd)/$(basename "$task_file")"
    cd "$(resolve_repo "$task_file")"
    if ! git rev-parse HEAD >/dev/null 2>&1; then
      echo "ERROR: repository has no commits. Make an initial commit before recording a checkpoint." >&2
      echo "A repo with zero commits cannot be reverted to — every mistake is permanent." >&2
      exit 1
    fi
    sha="$(git rev-parse HEAD)"
    if grep -q "^${field}:" "$task_file"; then
      sed -i.bak -E "s/^${field}:.*/${field}: ${sha}/" "$task_file" && rm -f "${task_file}.bak"
    else
      printf '\n%s: %s\n' "$field" "$sha" >> "$task_file"
    fi
    echo "Recorded checkpoint $sha in $task_file under \"$field\""
    ;;

  revert)
    task_file="${2:?usage: git-checkpoint.sh revert <task-file> [field-name]}"
    field="${3:-$DEFAULT_FIELD}"
    task_file="$(cd "$(dirname "$task_file")" && pwd)/$(basename "$task_file")"
    cd "$(resolve_repo "$task_file")"
    sha="$(checkpoint_field "$task_file" "$field")"

    if [[ -z "$sha" || "$sha" == "(none yet)" ]]; then
      echo "No checkpoint recorded under \"$field\" in $task_file — refusing to revert." >&2
      exit 1
    fi
    if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
      echo "ERROR: recorded sha '$sha' is not a commit in this repository — refusing to revert." >&2
      exit 1
    fi

    stamp="$(date +%Y%m%d-%H%M%S)"
    task_name="$(basename "$task_file" .md)"

    # 1. Safety net: stash EVERYTHING, including untracked, before touching the tree.
    #    Survives the reset and is listed below so the work is recoverable.
    stash_ref=""
    if [[ -n "$(git status --porcelain)" ]]; then
      if git stash push --include-untracked -m "pre-revert ${task_name} ${stamp}" >/dev/null 2>&1; then
        stash_ref="$(git rev-parse stash@{0} 2>/dev/null || echo '')"
        echo "Safety stash created: stash@{0} (${stash_ref:0:8}) — 'git stash list' to review, 'git stash pop' to restore."
      else
        echo "WARNING: could not create safety stash. Aborting revert rather than risk losing work." >&2
        exit 1
      fi
    fi

    # 2. Reset tracked files to the checkpoint.
    echo "Reverting tracked files to $sha (field: $field)"
    git reset --hard "$sha"

    # 3. Quarantine leftover untracked files. NEVER `git clean` — see the safety
    #    notice at the top of this file. Ignored files (bin/, obj/, node_modules/)
    #    are left alone; only untracked-but-not-ignored files are moved.
    mapfile -t leftovers < <(git ls-files --others --exclude-standard)
    if [[ ${#leftovers[@]} -gt 0 ]]; then
      quarantine=".claude-quarantine/${stamp}"
      mkdir -p "$quarantine"
      for f in "${leftovers[@]}"; do
        [[ "$f" == .claude-quarantine/* ]] && continue
        mkdir -p "$quarantine/$(dirname "$f")"
        mv "$f" "$quarantine/$f"
      done
      echo "Quarantined ${#leftovers[@]} untracked file(s) to $quarantine/ (moved, not deleted)."
      echo "Review and remove manually when you are certain they are not needed."
    fi

    echo "Revert complete. Nothing was deleted."
    ;;

  commit)
    task_id="${2:?usage: git-checkpoint.sh commit <task-id> <message>}"
    message="${3:?usage: git-checkpoint.sh commit <task-id> <message>}"
    git add -A
    # No co-author trailer — commits are attributed to the repo author only.
    git commit -m "[${task_id}] ${message}"
    echo "Committed as $(git rev-parse --short HEAD)"
    ;;

  *)
    echo "Usage: git-checkpoint.sh {check-clean|record <task-file> [field]|revert <task-file> [field]|commit <task-id> <message>}" >&2
    exit 2
    ;;
esac
