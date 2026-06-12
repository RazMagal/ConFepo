---
name: review-changes
description: Review the current uncommitted changes (or a named diff/PR/commit range) for real bugs before committing. Use for "review my changes", "is this safe to commit", "look over this diff".
---

# review-changes

Adversarially review the working changes and report real defects.

1. Gather the diff: `git diff` + `git diff --cached` (or the PR / commit range the
   user names, e.g. `git diff main...HEAD`).
2. Read each changed hunk **with its surrounding context** — pull up the file, not
   just the patch.
3. Report prioritized findings — **CRITICAL → MAJOR → MINOR** — each with
   `file:line`, the concrete problem, and a fix. Separate real bugs from style nits.
4. Specifically check: error handling, edge/empty/zero/locale inputs, quoting &
   injection, idempotency & re-runs, secret leakage, and whether the docs/tests
   match the change.
5. End with a verdict: safe to commit, or the must-fix list.

For anything large, spawn the **code-reviewer** agent so the review runs with its
own context.
