---
name: lint-rtl
description: Lint SystemVerilog/Verilog (or VHDL) and fix the findings. Use for "lint this RTL", "check my SystemVerilog", or before committing HDL.
---

# lint-rtl

Lint HDL with whatever linter is installed and fix the real issues.

1. Pick a linter that's present (`command -v`):
   - `verible-verilog-lint <files>`
   - `verilator --lint-only -Wall -Wno-fatal --top-module <top> <files>`
   - `slang <files>`
   - VHDL: `ghdl -a` (analyze) or a Verible/vendor equivalent.
2. Run it on the target file(s) and collect warnings.
3. Fix the substantive ones — inferred latches, blocking/nonblocking misuse,
   incomplete case/sensitivity, width mismatches, undriven/unused signals,
   implicit nets — and explain any non-obvious fix. Don't chase purely cosmetic
   style unless asked.
4. Re-run the linter until it's clean, or until the remaining warnings are
   justified and noted (e.g. a documented waiver). For deeper structural/CDC
   review, hand off to the `rtl-reviewer` agent.
