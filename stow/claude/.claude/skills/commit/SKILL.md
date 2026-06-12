---
name: commit
description: Stage (if needed) and create a clean Conventional Commit for the current changes. Use when the user says "commit", "commit this", or wants to wrap up a change.
---

# commit

Create a well-formed commit from the current changes.

1. Run `git status` and `git diff` (plus `git diff --cached`) to see exactly what
   changed. Don't commit blind.
2. If nothing is staged, propose what to stage — keep **one logical change per
   commit**. If the diff mixes unrelated concerns, suggest splitting it.
3. Draft a Conventional Commit message:
   `type(scope): imperative summary` (≤ 50 chars), then a body explaining the
   **why** when it's non-trivial (wrap at 72).
   Types: `feat fix docs refactor test chore perf build ci`.
4. Show the message and the file list, get a nod, then `git commit`.
5. Never describe changes that aren't in the diff. Append any commit trailer the
   project requires (e.g. a Co-Authored-By line).

For a substantial review before committing, invoke the **review-changes** skill or
the **code-reviewer** agent first.
