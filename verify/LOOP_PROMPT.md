# confepo — verification loop prompt

## How to run

From the repo root (`/home/laptop1/confepo`), start the loop with:

```
/loop verify the confepo repo by following verify/LOOP_PROMPT.md and updating verify/STATUS.md each iteration
```

(Plain `/loop` self-paces; add an interval like `/loop 10m ...` if you want fixed
spacing. To allow the deeper checks that need extra tools installed, include the
word **`install-ok`** in your `/loop` message. To allow the live install/idempotency
checks that touch `$HOME`, also include **`link-ok`**.)

---

## What you (the assistant) do each iteration

`verify/STATUS.md` is the **single source of truth**. Context may reset between
iterations — trust the file, not your memory.

1. **Read `verify/STATUS.md`.** Find the first item whose status is `pending`
   or `retry` (top to bottom). You may complete **1–3 related items** from the
   same phase in one iteration to keep momentum, but never skip ahead past a
   `fail`.
2. **If no `pending`/`retry`/`fail` items remain →** the run is **COMPLETE**:
   - Fill in the "Summary" block at the top of `STATUS.md` (counts + verdict).
   - Print `✅ VERIFICATION COMPLETE` and **stop the loop** (do not schedule
     another wake-up).
3. **Otherwise, run the selected item's command(s)** exactly as written in its
   section of `STATUS.md` (all commands assume CWD = repo root).
4. **Record the result** by editing that item in `STATUS.md`:
   - `pass` — only if you can paste the command output proving it.
   - `fail` — check uncovered a real defect. **If you can safely fix the repo
     file, do so, re-run the check, and mark `pass`** with a note describing the
     fix. If you cannot fix it confidently, leave it `fail` and write why.
   - `skip` — the check needs a tool that isn't installed and the run wasn't
     authorized to install it (no `install-ok`), or it's `[OPT-IN]` without the
     matching flag. State the reason.
   - `retry` — transient (e.g. network) failure to revisit next pass.
   - Append a dated one-line entry to the **Evidence Log** at the bottom with the
     command and a short output snippet.
5. **Update the "Last updated" timestamp** at the top, save the file, and (if
   items remain) schedule the next iteration.

## Rules

- **Show your work.** Never mark `pass` without real command output as evidence.
- **Non-destructive by default.** Phases A–D only read/run; they don't mutate
  `$HOME` or install anything. Run them in the sandbox.
- **Tool-gated items** (`[NEEDS: x]`): if `x` is on `PATH`, run it. If not:
  install `x` **only** when the run was started with `install-ok` (use the repo's
  own `pkg_install` / apt); otherwise mark `skip (needs <x>; pass install-ok)`.
- **`[OPT-IN]` items** (live install / idempotency that write to `$HOME` or the
  system): run **only** if the matching flag was given (`link-ok` for symlink/
  idempotency items; the full system install stays **manual** — never run it
  unattended). Otherwise `skip`.
- **Fixes stay in style.** Match the surrounding code; keep diffs minimal; don't
  reformat unrelated lines.
- **One source of truth.** Every status change goes into `STATUS.md`. Don't keep
  state anywhere else.
- If a fix changes a script, **re-run phase A1/A2 for that file** before marking
  the item `pass` (a fix must not introduce a syntax/lint regression).
