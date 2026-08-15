#!/usr/bin/env bash
# confepo-claude-inject: one message must be exactly ONE submission (embedded
# newlines were Enter keypresses once — each answered a prompt blind), and a
# missing pane must be a clean error, not a typo-matched regex hit.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
INJ="$PWD/stow/bin/.local/bin/confepo-claude-inject"

command -v tmux >/dev/null 2>&1 || { echo "   skip: tmux not installed"; exit 0; }

SOCK="confepo-test-$$"
OUT="$(mktemp)"
STUB="$(mktemp -d)"
printf '#!/usr/bin/env bash\nexec /usr/bin/tmux -L %s "$@"\n' "$SOCK" > "$STUB/tmux"
chmod +x "$STUB/tmux"
# shellcheck disable=SC2329  # invoked via the EXIT trap below
cleanup() { /usr/bin/tmux -L "$SOCK" kill-server 2>/dev/null || true; rm -rf "$OUT" "$STUB"; }
trap cleanup EXIT

/usr/bin/tmux -L "$SOCK" new-session -d "cat > $OUT"
pane="$(/usr/bin/tmux -L "$SOCK" list-panes -a -F '#{pane_id}')"

fails=0

# multi-line reply -> single flattened submission
printf '2\r\nlooks good\ny' | PATH="$STUB:$PATH" "$INJ" "$pane"
sleep 1
if [ "$(cat "$OUT")" = "2 looks good y" ] && [ "$(grep -c '' "$OUT")" = 1 ]; then
  echo "   ok: newlines flattened, one submission"
else
  echo "   FAIL: pane received: $(cat -A "$OUT")"; fails=$((fails + 1))
fi

# unknown pane -> exit 5, nothing typed
if printf 'x' | PATH="$STUB:$PATH" "$INJ" '%999' 2>/dev/null; then
  echo "   FAIL: bogus pane accepted"; fails=$((fails + 1))
else
  [ $? -eq 5 ] && echo "   ok: unknown pane rejected (exit 5)" \
               || { echo "   FAIL: wrong exit code for bogus pane"; fails=$((fails + 1)); }
fi

# regex-metachar pane arg must not match a real pane (grep -Fxq guard)
if printf 'x' | PATH="$STUB:$PATH" "$INJ" "${pane}." 2>/dev/null; then
  echo "   FAIL: '${pane}.' matched a pane via regex"; fails=$((fails + 1))
else
  echo "   ok: pane match is literal, not regex"
fi

exit "$fails"
