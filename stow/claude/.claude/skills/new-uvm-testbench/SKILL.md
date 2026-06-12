---
name: new-uvm-testbench
description: Scaffold a UVM testbench/environment for a DUT (interface, agent, env, sequences, scoreboard, test, top). Use for "set up a UVM testbench" or "new verification environment".
---

# new-uvm-testbench

Scaffold a UVM environment around a DUT.

1. Read the DUT's ports and pin down its interface: clock(s), reset (polarity/sync),
   and the signals to drive/monitor. Define a `virtual interface` (with clocking
   blocks + a `modport`) for it.
2. Generate the standard pieces, each in its own file, all built through the factory
   (`type_id::create`) and connected via `uvm_config_db`:
   - `*_seq_item` (`rand` fields + `constraint`s), one or more `*_sequence`s
   - `*_driver`, `*_monitor`, `*_sequencer`, `*_agent`
   - `*_scoreboard` with a reference-model hook + analysis exports — use
     ``` `uvm_analysis_imp_decl ``` (or `uvm_tlm_analysis_fifo`s) when it takes
     more than one input stream, since one class can have only one `write()`
   - `*_env`, a base `*_test` and a smoke test, and a `tb_top` module that
     instantiates the DUT + interface, generates the clock, applies reset, sets the
     vif in the config DB, and calls `run_test()`.
3. Add a starter `covergroup` and a couple of SVA checks bound to the interface.
   If the DUT has a register/CSR bus, add a UVM RAL model (`uvm_reg_block` +
   adapter + predictor) rather than poking registers by hand.
4. Provide a `Makefile`/filelist to compile+run, then run the smoke test via the
   `run-sim` skill and confirm it elaborates, applies reset, and the run_phase
   objection drains cleanly.

If a testbench already exists in the repo, match its naming, base classes, and macros
rather than inventing a new style.
