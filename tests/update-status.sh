#!/usr/bin/env bash
# Rewrite the auto-verification block in verify/STATUS.md (the lines between
# the nightly:begin/end markers) with the given text. Used by the
# verify-nightly workflow; safe to run by hand too.
#   tests/update-status.sh "✅ 2026-08-14 — everything green"
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

f="verify/STATUS.md"
line="$*"
[ -n "$line" ] || { echo "usage: tests/update-status.sh <text for the ledger line>" >&2; exit 2; }
grep -q '<!-- nightly:begin -->' "$f" || { echo "no nightly markers in $f" >&2; exit 1; }

awk -v line="$line" '
  /<!-- nightly:begin -->/ { print; print "> " line; skip = 1; next }
  /<!-- nightly:end -->/   { skip = 0 }
  !skip { print }
' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
