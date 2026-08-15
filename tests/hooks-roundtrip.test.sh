#!/usr/bin/env bash
# setup_claude_hooks / remove_claude_hooks must round-trip: after install +
# uninstall, ~/.claude/settings.json is byte-identical in content to what the
# user had — their own hooks survive, ours vanish, empty containers pruned.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
export CONFEPO_DIR="$PWD"

command -v jq >/dev/null 2>&1 || { echo "   skip: jq not installed"; exit 0; }

S="$(mktemp -d)"
trap 'rm -rf "$S"' EXIT
mkdir -p "$S/.claude" "$S/bin"
# setup_claude_hooks is gated on a `claude` binary being present — stub one.
printf '#!/usr/bin/env bash\nexit 0\n' > "$S/bin/claude"; chmod +x "$S/bin/claude"

fails=0
run() { HOME="$S" PATH="$S/bin:$PATH" bash -c ". lib/common.sh; $1"; }

# Case 1: user has their own PreToolUse hook — it must survive the round-trip.
jq -n '{model:"opus",hooks:{PreToolUse:[{matcher:"Bash",
        hooks:[{type:"command",command:"my-own-hook"}]}]}}' \
  > "$S/.claude/settings.json"
cp "$S/.claude/settings.json" "$S/orig.json"

run "setup_claude_hooks" >/dev/null
n="$(jq '.hooks | keys | length' "$S/.claude/settings.json")"
if [ "$n" -ge 4 ]; then echo "   ok: hooks installed ($n event types)"; else
  echo "   FAIL: expected >=4 hook events, got $n"; fails=$((fails + 1)); fi

run "remove_claude_hooks" >/dev/null
if diff -q <(jq -S . "$S/orig.json") <(jq -S . "$S/.claude/settings.json") >/dev/null; then
  echo "   ok: round-trip clean — user hooks intact, ours gone"
else
  echo "   FAIL: settings.json differs after setup+remove:"
  diff <(jq -S . "$S/orig.json") <(jq -S . "$S/.claude/settings.json") || true
  fails=$((fails + 1))
fi

# Case 2: empty settings — ours must not leave husks behind.
printf '{}\n' > "$S/.claude/settings.json"
run "setup_claude_hooks >/dev/null; remove_claude_hooks" >/dev/null
if [ "$(jq -c . "$S/.claude/settings.json")" = "{}" ]; then
  echo "   ok: empty settings restored to {}"
else
  echo "   FAIL: leftovers: $(cat "$S/.claude/settings.json")"; fails=$((fails + 1))
fi

exit "$fails"
