#!/usr/bin/env bash
# Test harness for block-dangerous.sh. Reads expected/command pairs from cases.txt
# so this script's own command line never contains the patterns under test.
HOOK="C:/Users/Techn/.claude/hooks/block-dangerous.sh"
CASES="C:/Users/Techn/.claude/hooks/tests/cases.txt"
pass=0; fail=0

while IFS=$'\t' read -r expected cmd; do
  [ -z "$expected" ] && continue
  payload="$(CMD="$cmd" node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",tool_input:{command:process.env.CMD}}))')"
  actual="$(printf '%s' "$payload" | bash "$HOOK" | node -e "
    let d='';process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{try{process.stdout.write(JSON.parse(d).hookSpecificOutput.permissionDecision)}catch(e){process.stdout.write('PARSE-FAIL')}})")"
  if [ "$actual" = "$expected" ]; then
    pass=$((pass+1)); printf '  ok   %-6s %s\n' "$actual" "$cmd"
  else
    fail=$((fail+1)); printf '  FAIL want=%-6s got=%-6s %s\n' "$expected" "$actual" "$cmd"
  fi
done < "$CASES"

echo ""
echo "passed: $pass   failed: $fail"

# Malformed-payload check: a parse failure must NOT become a bypass.
echo ""
echo "malformed payload (the old silent-bypass bug):"
bad="$(node -e 'process.stdout.write("{not valid json, command: git " + "clean -fd}")')"
printf '%s' "$bad" | bash "$HOOK"
echo ""
echo "empty payload:"
printf '' | bash "$HOOK"
