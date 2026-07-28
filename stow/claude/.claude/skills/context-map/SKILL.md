---
name: context-map
description: Work a large codebase without flooding the context window — give the model the INTERFACE of everything and the IMPLEMENTATION of only the working set, expanding one body on demand. Use when a change touches a big/unfamiliar tree and loading whole modules (plus their transitive imports) would dilute attention ("context rot"). Backed by the confepo-api-surface tool.
---

# context-map

Loading the transitive import closure of a change doesn't just cost tokens — it
*degrades* the model: every frontier model gets less accurate as the window
fills, even with irrelevant tokens ("context rot"). Treat context as an
**attention budget**: spend full-fidelity tokens on what you're editing, cheap
signature tokens on the boundary, and defer the rest.

## The rule

1. **Working set = full bodies.** The file(s) you're editing, their direct
   (1-hop) callers/callees, and any frame named in a failing test / stack trace.
   Read these normally.
2. **Everything else = skeleton.** For any *other* module you only need to call
   into, run `confepo api-surface <path>` (signatures + docstrings, bodies elided)
   instead of `Read`-ing it. A distant dependency then costs ~hundreds of tokens,
   not thousands.
3. **Expand exactly one body, on demand.** Call `confepo api-surface <file> --full
   <symbol>` only when a signature is genuinely insufficient — you're about to
   edit that symbol, a stack trace points *into* it, or its type surface doesn't
   explain the behaviour. Pull one body, not the whole module.
4. **Seed the working set from the task and the errors — don't wait to feel
   stuck.** Models chronically under-invoke "go deeper" tools; when a test fails,
   auto-expand the frames the traceback names rather than hoping you remember to.
5. **`grep`/`rg` is the fallback for what imports can't show.** Dynamic dispatch,
   dependency injection, registries, reflection, and string-keyed calls have no
   import edge — the skeleton won't reveal them. Drop to search there.

## Honest caveats (why this is a default, not a wall)

- **Import distance ≠ relevance.** A 1-hop `import utils` may use 1 of 50
  functions (over-includes); a callback across a DI boundary has no import edge
  (under-includes). Use nearness as a cheap prior, not a hard fence — and the bug
  is often *inside* a distant body, so keep expansion frictionless.
- **No stale skeletons.** `confepo api-surface` regenerates from source on each
  call — never cache a skeleton across an edit; a stale interface is worse than
  none. Trust signatures/types over prose docstrings.
- **Small or near targets:** just read the file. Skeletonising a 40-line module
  costs more than reading it — reserve this for large or far dependencies.

## Shared primitive
`confepo api-surface`'s "signatures, no bodies" output is the *same* CONTRACT the
blind `spec-tester` agent consumes (see the `spec-test` skill). One extraction
primitive, two uses: **oracle independence** there, **context economy** here.
