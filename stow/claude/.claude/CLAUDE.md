# Global instructions for Claude Code — managed by confepo

These apply across all projects. Trim or remove anything you don't want
(`confepo uninstall claude` removes the whole set).

## Frontend / UI work — build then VERIFY
When asked to build, mock up, or change any UI, screen, component, or POC:
1. **Build it with the `frontend-prototyper` agent** (and the `scaffold-poc`
   skill to stand up the project) — don't hand-roll it ad hoc.
2. **Then verify it with the Playwright browser MCP** (confepo registers it as
   `playwright`): open the page, interact with it, and take a screenshot to
   confirm the layout and behavior actually look right *before* you call it done.
   Never ship a frontend you haven't looked at. (If the MCP isn't connected, say
   so and fall back to describing how to run it.)

## Delegate to the right specialist
- Code review → `code-reviewer`; shell/scripts → `shell-hardener`; debugging →
  `debugger`; commit messages → `commit-crafter`; explanations → `explainer`.
- Tests → the `write-tests` skill.
- Hardware (chip design / DV): RTL → `rtl-designer`; verification & UVM →
  `verification-engineer`; HDL review → `rtl-reviewer`; plus the `lint-rtl`,
  `run-sim`, and `new-uvm-testbench` skills.

## Phone / Telegram notifications — disclosure policy (HARD RULE)
Any message that leaves this machine for a phone (the `confepo-notify-phone`
helper / the Telegram channel) transits a third party **in plaintext**. So when
you compose or trigger ANY such message you MUST keep it vague and
non-disclosing:
- **Never include**: file names or paths, code or command text, secrets / tokens
  / keys, URLs, project or client names, or the substance of what you're doing.
- **Send only a generic status** — categories, not contents: e.g. "needs your
  input", "finished a task", "waiting for approval". A coarse machine label is OK.
- When unsure, send less. "Claude needs you" is always acceptable; specifics are
  not. The `confepo-notify-phone` helper also sanitises + length-caps every
  message as a backstop, but do **not** rely on it — keep messages vague yourself.

## Working style
- Be concise — lead with the answer. Confirm before destructive or
  outward-facing actions (rm, force-push, deploy) unless clearly authorized.
- Shell scripts: bash with `set -euo pipefail`, quoted, idempotent,
  shellcheck-clean; never let an optional step abort a critical one.
- This machine: Ubuntu + i3 (X11) + fish; default editor nano. Prefer the modern
  CLI tools that are installed: `eza`, `bat`, `rg`, `fd`, `fzf`, `zoxide`,
  `delta`, `btop`.
