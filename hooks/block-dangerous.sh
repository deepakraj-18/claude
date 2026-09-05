#!/usr/bin/env bash
# block-dangerous.sh
# PreToolUse hook for the Bash tool. Reads tool input as JSON on stdin and returns
# allow / ask / deny for the proposed command.
#
# WHY THIS FILE IS STRICT
# -----------------------
# 2026-08-15: a tester agent ran `git clean -fd` in a repository that had been
# initialised but never committed to. Every file was untracked, so the command
# destroyed the entire project — planning documents, original design assets, all
# source. `git clean` does not use the Recycle Bin, and there was no commit to
# recover from.
#
# The previous version of this hook had two holes, both closed below:
#   1. `git clean` was not in the pattern list at all.
#   2. `set -euo pipefail` + `grep -o` meant a payload that didn't match the
#      expected JSON shape killed the script before it printed a decision —
#      turning a parse failure into a silent bypass.
#
# Now: patterns are matched against BOTH the parsed command and the raw stdin,
# there is no `set -e`, and every code path prints an explicit decision.
#
# Tiers:
#   deny — catastrophic, no legitimate agent use. Blocked outright.
#   ask  — sometimes legitimate. User is prompted before it runs.
#
# Full policy: ~/.claude/rules/destructive-operations.md

input="$(cat)"

# --- Parse the command, with a raw-text fallback -----------------------------
# node rather than jq (jq is not installed here). If parsing fails for any
# reason, the raw payload is still scanned below, so the check cannot be
# bypassed by malformed or unexpected JSON.
command_text=""
if command -v node >/dev/null 2>&1; then
  command_text="$(printf '%s' "$input" | node -e "
    let d='';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => {
      try {
        const j = JSON.parse(d);
        process.stdout.write((j.tool_input && j.tool_input.command) || '');
      } catch (e) { process.stdout.write(''); }
    });
  " 2>/dev/null)"
fi

scan_target="$command_text
$input"

emit() { # $1 = decision, $2 = reason
  local reason="${2//\\/\\\\}"
  reason="${reason//\"/\\\"}"
  printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "%s", "permissionDecisionReason": "%s"}}\n' "$1" "$reason"
  exit 0
}

# --- DENY: catastrophic, never legitimate for an agent -----------------------
DENY_PATTERNS=(
  # Irreversible git. `git clean` in ANY form is what caused the incident: it
  # deletes untracked files, which in an uncommitted repo means everything.
  'git[[:space:]]+clean'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+checkout[[:space:]]+--[[:space:]]'
  'git[[:space:]]+restore[[:space:]]'
  'git[[:space:]]+push[[:space:]]+.*(--force|-f)([[:space:]]|$)'
  'git[[:space:]]+branch[[:space:]]+-D'
  'git[[:space:]]+filter-branch'
  'git[[:space:]]+reflog[[:space:]]+expire'
  'git[[:space:]]+update-ref[[:space:]]+-d'

  # Filesystem catastrophes
  'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+/([[:space:]]|$)'
  'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+~'
  'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+\*'
  'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+\.\.?([[:space:]]|/)*$'
  'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+\$'
  ':\(\)\{:\|:&\};:'
  'mkfs'
  'dd[[:space:]]+.*of=/dev/'
  'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'

  # Windows equivalents
  'Remove-Item[[:space:]]+.*-Recurse.*[[:space:]]+[A-Za-z]:\\?([[:space:]]|$)'
  'format[[:space:]]+[A-Za-z]:'

  # Destructive SQL
  'DROP[[:space:]]+DATABASE'
  'DROP[[:space:]]+SCHEMA'
  'DROP[[:space:]]+TABLE'
  'TRUNCATE[[:space:]]+TABLE'
)

for pattern in "${DENY_PATTERNS[@]}"; do
  if printf '%s' "$scan_target" | grep -qiE "$pattern"; then
    emit "deny" "BLOCKED by block-dangerous.sh - matches destructive pattern '$pattern'. This class of command is irreversible and is not run by agents. See ~/.claude/rules/destructive-operations.md. If you genuinely intend it, commit your work first and run it yourself in a terminal."
  fi
done

# --- ASK: sometimes legitimate, but confirm before it runs -------------------
ASK_PATTERNS=(
  'rm[[:space:]]+-[a-zA-Z]*r'
  'rm[[:space:]]+.*\*'
  'rmdir[[:space:]]+/[sS]'
  'Remove-Item[[:space:]]+.*-Recurse'
  'git[[:space:]]+rm[[:space:]]+.*-r'
  'git[[:space:]]+stash[[:space:]]+(drop|clear)'
  'find[[:space:]]+.*-delete'
  'find[[:space:]]+.*-exec[[:space:]]+rm'
  'truncate[[:space:]]+-s[[:space:]]*0'
  'DELETE[[:space:]]+FROM'
)

for pattern in "${ASK_PATTERNS[@]}"; do
  if printf '%s' "$scan_target" | grep -qiE "$pattern"; then
    emit "ask" "CONFIRM DELETE - matches '$pattern'. Before approving, check: is it scoped to a named path rather than a wildcard or the repo root? Is the target committed or otherwise recoverable? Did the agent create it? See ~/.claude/rules/destructive-operations.md."
  fi
done

printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\n'
