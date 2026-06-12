---
name: harden-shell
description: Lint and harden shell scripts — runs bash -n + shellcheck and fixes common robustness bugs (set -e aborts, quoting, exit-code masking, idempotency). Use for "check this script", "harden", "shellcheck this".
---

# harden-shell

Make a shell script robust. Given a script path (or "all scripts in the repo"):

1. Syntax + lint: `bash -n <script>` and `shellcheck -S warning <script>`.
2. Fix the real findings, prioritising:
   - `set -e` aborting on an optional/expected-to-fail command (add `|| true`, or
     restructure so the critical final step always runs);
   - missing/incorrect quoting and word-splitting;
   - exit-code masking in `local x=$(...)` → split into `local x; x="$(...)"`;
   - unguarded empty-array expansion under `set -u`;
   - non-idempotent operations and missing `command -v` guards for optional tools;
   - a function ending in `[ … ] && …` returning nonzero → add `return 0`.
3. Re-run `bash -n` and `shellcheck` after **each** fix — never introduce a
   regression.
4. Keep edits minimal and matched to the script's existing style; explain any
   non-obvious change.

Defer to the **shell-hardener** agent for a large multi-file audit.
