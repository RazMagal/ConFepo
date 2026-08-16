#!/usr/bin/env bash
# confepo-apps: conf parsing, comma splitting (with args + stray whitespace),
# and one launch per command — no more, no less — via a stubbed i3-msg.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
APPS="$PWD/stow/bin/.local/bin/confepo-apps"

S="$(mktemp -d)"
trap 'rm -rf "$S"' EXIT
fails=0

cat > "$S/apps.conf" <<'EOF'
# comment line
work  = firefox ,  alacritty -e btop, code /tmp/some dir
empty =
chill = mpv --shuffle /tmp/x
EOF

# stub i3-msg: get_version succeeds; exec logs its final arg
mkdir -p "$S/bin"
printf '#!/usr/bin/env bash\n[ "$1" = -t ] && exit 0\nfor a; do :; done\nprintf "%%s\\n" "$a" >> "%s"\n' "$S/exec.log" > "$S/bin/i3-msg"
chmod +x "$S/bin/i3-msg"
run() { CONFEPO_APPS_CONF="$S/apps.conf" PATH="$S/bin:$PATH" "$APPS" "$@"; }

# --list shows every parsed group
if run --list | grep -q '^work =' && run --list | grep -q '^chill ='; then
  echo "   ok: --list parses groups"
else
  echo "   FAIL: --list output: $(run --list)"; fails=$((fails + 1))
fi

# launching a group runs each comma-separated command exactly once, trimmed
run work >/dev/null 2>&1
if [ "$(grep -c '' "$S/exec.log")" = 3 ] \
   && grep -qx 'firefox' "$S/exec.log" \
   && grep -qx 'alacritty -e btop' "$S/exec.log" \
   && grep -qx 'code /tmp/some dir' "$S/exec.log"; then
  echo "   ok: group launches its 3 commands, args + spaces intact"
else
  echo "   FAIL: exec log:"; sed 's/^/         /' "$S/exec.log"; fails=$((fails + 1))
fi

# unknown and empty groups fail loudly, launching nothing
: > "$S/exec.log"
run nosuch >/dev/null 2>&1 && { echo "   FAIL: unknown group accepted"; fails=$((fails + 1)); } \
  || echo "   ok: unknown group rejected"
run empty >/dev/null 2>&1 && { echo "   FAIL: empty group accepted"; fails=$((fails + 1)); } \
  || echo "   ok: empty group rejected"
[ -s "$S/exec.log" ] && { echo "   FAIL: bad groups launched something"; fails=$((fails + 1)); } \
  || echo "   ok: bad groups launch nothing"

# first run writes a template instead of erroring
if CONFEPO_APPS_CONF="$S/fresh/apps.conf" "$APPS" 2>/dev/null; [ -f "$S/fresh/apps.conf" ]; then
  echo "   ok: first run writes a conf template"
else
  echo "   FAIL: no template written"; fails=$((fails + 1))
fi

exit "$fails"
