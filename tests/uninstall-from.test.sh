#!/usr/bin/env bash
# uninstall --from with a bogus stamp must die BEFORE unlinking anything.
# (It used to unlink every package and THEN discover the backup didn't exist —
# a fully deconfigured $HOME with nothing restored.)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

S="$(mktemp -d)"
trap 'rm -rf "$S"' EXIT

# Canary: a confepo-owned symlink that a runaway unlink pass WOULD remove.
ln -s "$PWD/stow/nano/.nanorc" "$S/.nanorc"

fails=0
if out="$(HOME="$S" ./uninstall.sh --from 19990101-000000 2>&1)"; then
  echo "   FAIL: bogus stamp was accepted"; fails=$((fails + 1))
else
  echo "   ok: bogus stamp rejected (exit $?)" || true
fi
case "$out" in
  *"no such backup"*) echo "   ok: error names the missing backup" ;;
  *) echo "   FAIL: unexpected error output: $out"; fails=$((fails + 1)) ;;
esac
if [ -L "$S/.nanorc" ]; then
  echo "   ok: nothing was unlinked before the failure"
else
  echo "   FAIL: canary symlink is gone — unlink ran before validation"
  fails=$((fails + 1))
fi

exit "$fails"
