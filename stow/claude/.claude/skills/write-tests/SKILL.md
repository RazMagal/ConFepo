---
name: write-tests
description: Write or extend tests for a piece of code. Use for "add tests", "write a unit test", "cover this function" (software or HDL).
---

# write-tests

Add meaningful tests for the target code.

1. Read the code and find the existing framework/conventions (pytest, jest/vitest,
   go test, JUnit, cocotb/UVM for HDL…). Match them — don't introduce a new framework
   without a reason.
2. Cover the contract, not the implementation: the happy path, boundaries
   (empty/zero/max/overflow), error paths, and any branch the code clearly cares
   about. One behavior per test, named for what it asserts.
3. Make tests deterministic and fast — no network/time/random flakiness (seed RNGs).
   For HDL, prefer self-checking (scoreboard/assertions) over waveform inspection.
4. Run the suite; confirm the new tests pass AND actually exercise the code (they
   should fail if you break the behavior). Avoid asserting on internals that a
   harmless refactor would break.
