# Requirements and portability

## Verified toolchain

- SystemVerilog simulator: Verilator 5.49
- Compiler: a C++20-capable GNU C++ toolchain used by Verilator
- Build front end: GNU Make and Bash
- Operating system: Linux

## Cadence Xcelium path

The source uses standard SystemVerilog RTL, unpacked arrays, concurrent assertions, and timing controls. `scripts/run_xcelium.sh` provides an Xcelium command line using `xrun -64bit -sv -assert`. Run it in an environment with a valid Cadence installation and license.

## Language boundary

- RTL: `always_ff`, `always_comb`, parameterized widths, packed/unpacked arrays, functions, and SVA.
- Testbench: tasks, random stimulus, procedural assertions, scoreboards, and delays.
- No UVM package is required for this repository; the intent is to keep the design behavior visible before introducing a class-based environment.

## Design assumptions

- Reset assertions are asynchronous; release is driven away from an active clock edge in the supplied tests.
- Day 5 assumes coordinated reset and source events spaced far enough apart for the destination to observe each toggle.
- Day 6 requires `ACC_WIDTH >= 2 * OPERAND_WIDTH`.
- Day 7 expects a ready/valid source to hold a packet until `ready` is observed; its randomized driver follows that rule.
