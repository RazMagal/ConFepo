---
name: spec-test
description: Author a feature's acceptance tests BLIND to the implementation — delegate to the spec-tester agent, which sees only the spec + public contract, then run/triage/mutation-gate the suite. Use when tests should encode intended behaviour rather than confirm whatever the code already does; i.e. for any non-trivial feature where "the author grading their own homework" is a real risk. For a quick local unit test, use write-tests instead.
---

# spec-test

Set up a feature's tests through an **independent, implementation-blind author**, so the suite
encodes the *spec*, not the code. You (the orchestrator) are not blind — you see everything —
so your job is to feed the blind `spec-tester` agent only what it should see, then run and
triage what it produces. The enforcement is real: a `PreToolUse` hook denies the `spec-tester`
agent any read outside the staged spec/contract + test dirs, and it has no shell.

## Pipeline

1. **Write the SPEC** — `.confepo/spec-test/spec.md`. The intended, observable behaviour and
   acceptance criteria for the feature: inputs → outputs, error cases, boundaries, invariants.
   Derive it from the feature request / user story / existing design doc — in the user's terms.
   **No implementation detail** (no "it loops over…", no internal function names). If the spec
   is ambiguous, resolve it with the user now; ambiguity found later is more expensive.

2. **Extract the CONTRACT** — `.confepo/spec-test/contract.md`. The public surface the tests
   bind to: function/method signatures + types + docstrings, CLI `--help` output, HTTP
   routes/schemas, error codes, and the project's test framework + test directory. **Signatures
   only — never paste function bodies or logic.** This is the black-box boundary.

3. **Delegate to `spec-tester`** (blind). Point it at `.confepo/spec-test/spec.md` and
   `contract.md`; ask for a behavioural/acceptance suite in the project's framework, one
   behaviour per test, covering every acceptance criterion + happy path + boundaries + error
   paths. It writes tests into the test dir and cannot read the implementation (hook-enforced).
   Do **not** paste implementation code into its prompt — that defeats the whole exercise.

4. **Run the suite** — you run it, not the tester (a traceback would leak the code to it).
   Run against the real implementation and collect pass/fail.

5. **Triage every failure** — decide, and say which:
   - **Implementation is wrong** → fix the code (hand to `debugger`/the implementer). Keep the
     test. This is the suite doing its job: it caught a real bug the author would have missed.
   - **Spec is ambiguous/wrong** → fix the **spec** (with the user), then have `spec-tester`
     regenerate. **Never** silently edit an accepted acceptance test to go green — that
     re-introduces the circular oracle. Relay only the failure/expected-vs-actual to the tester,
     never the implementation.

6. **Mutation gate** — prove the suite has teeth: run mutation testing (`mutmut`/`cosmic-ray`
   for Python, StrykerJS for JS/TS, `go-mutesting` for Go, etc.). The tests must **kill**
   mutants. Surviving mutants = weak/missing assertions → feed the *surviving behaviour* (not
   the mutated code) back to `spec-tester` to strengthen. Report the mutation score; a green
   suite that kills nothing is not done.

7. **Persist as the regression list** — the accepted suite is the project's regression: it runs
   in CI on every change, and each new feature appends its spec-derived tests. Don't let the
   implementer delete or weaken a regression test to pass; a red regression is triaged (step 5),
   not silenced.

## The invariant (why this exists)
The oracle must be causally independent of the artifact under test: whoever wrote the code must
neither write nor edit the criteria that judge it, and those criteria derive from the spec, not
the implementation. Steps 3–5 enforce authorship independence; step 6 is the teeth.

## Hardware DV mapping (same discipline)
This is exactly how serious design verification is structured — and why designer ≠ verifier:
`spec.md` ≙ the **verification/test plan** (derived from the spec, not the RTL); `spec-tester`
≙ the **independent verification engineer / UVM env** (black-box); the accepted suite ≙ the
**regression list** run every change; the mutation score ≙ **functional-coverage closure**
(proof the stimulus actually exercised every specified behaviour); triage ≙ **design-bug vs
testbench-bug**. For HDL, prefer the `verification-engineer` agent + `new-uvm-testbench` /
`run-sim` skills — the roles map one-to-one.
