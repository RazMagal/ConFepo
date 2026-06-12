---
name: run-sim
description: Compile and run an HDL simulation and triage failures. Use for "run the sim", "compile and simulate", or "why is my test failing".
---

# run-sim

Build + run a simulation with whatever simulator is present, then triage.

1. Prefer the project's existing flow if there is one — a `Makefile`, a `*.f`
   filelist, or a cocotb `Makefile` (`make SIM=<sim>`). Otherwise detect the
   simulator (`command -v`) and use the matching commands:
   - **Verilator** (v5+): `verilator --binary -j 0 -Wall --top-module <top> <files>`
     then run `obj_dir/V<top>`. (Older Verilator: `--cc --exe` + a C++ harness.)
   - **Icarus**: `iverilog -g2012 -o sim.out <files>` then `vvp sim.out`.
   - **VCS**: `vcs -full64 -sverilog <files> -o simv` then `./simv`.
   - **Questa/ModelSim**: `vlib work` (once), `vlog <files>`, then
     `vsim -c work.<top> -do "run -all; quit -f"`.
   - **Xcelium**: `xrun -sv <files>`.
2. On failure, read the log top-down: the FIRST compile error, or the first failing
   assertion / `UVM_ERROR` / scoreboard mismatch. Record the seed so it reproduces.
   If the clock never toggles or delays look wrong, suspect a missing/mismatched
   `` `timescale `` (set one consistently, or pass the simulator's timescale flag).
3. Decide **RTL bug vs testbench/constraint bug** before changing anything. If a
   dump exists (VCD/FST/FSDB), point to the exact signal and time to inspect (open
   with GTKWave for VCD/FST, Verdi for FSDB).
4. Keep the iteration loop tight — don't rewrite the bench to chase one failure.
   For test architecture or new checks, use the `verification-engineer` agent.
