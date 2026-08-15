#!/usr/bin/env bash
# Freeze the confepo-notify-phone sanitize() redaction corpus. Every "must
# redact" case below was a real bypass found in the 2026-08 audit; the "must
# not touch" cases pin down the over-redaction boundary.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
NP=stow/bin/.local/bin/confepo-notify-phone

fails=0
check() {  # check <label> <input> <expected>
  local got
  got="$("$NP" --sanitize "$2")"
  if [ "$got" = "$3" ]; then
    echo "   ok: $1"
  else
    echo "   FAIL: $1"
    echo "         in:   $2"
    echo "         want: $3"
    echo "         got:  $got"
    fails=$((fails + 1))
  fi
}

# -- must redact (each was a live bypass once) --------------------------------
check "code span redacted whole"  'about to run `rm -rf /home/x` on prod-db' \
                                  'about to run [code] on prod-db'
check "single-segment home path"  'wrote key to ~/x: hunter2!' \
                                  'wrote key to [path]: hunter2!'
check "windows path"              'C:\Users\bob\salaries.xlsx leaked' \
                                  '[path] leaked'
check "bare /etc + ~/secrets + deep path" \
  'see /etc and ~/secrets plus /home/laptop1/confepo/install.sh' \
  'see [path] and [path] plus [path]'
check "url"                       'check https://example.com/secret?x=1 now' \
                                  'check [link] now'
check "long token"                'token ghp_abcdefghij1234567890 found' \
                                  'token [redacted] found'
check "newlines flattened"        $'line1\nline2' 'line1 line2'

# -- must NOT touch (over-redaction is its own bug) ---------------------------
check "fractions survive"         'progress 5/10 done and/or waiting' \
                                  'progress 5/10 done and/or waiting'
check "generic status survives"   'needs your input' 'needs your input'

# -- hard length cap ----------------------------------------------------------
long="$(printf 'word %.0s' $(seq 1 60))"
caplen="$("$NP" --sanitize "$long" | wc -c)"   # includes trailing newline
if [ "$caplen" -le 141 ]; then echo "   ok: 140-char cap"; else
  echo "   FAIL: cap — got $caplen bytes"; fails=$((fails + 1)); fi

exit "$fails"
