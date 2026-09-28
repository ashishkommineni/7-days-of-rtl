# 7 Days of RTL

[![RTL regression](https://github.com/ashishkommineni/7-days-of-rtl/actions/workflows/rtl-regression.yml/badge.svg)](https://github.com/ashishkommineni/7-days-of-rtl/actions/workflows/rtl-regression.yml)

Seven small RTL projects, each built around one design decision that regularly appears in real reviews and interviews. This is not a folder of isolated syntax examples. Every day starts with a behavior contract, implements synthesizable SystemVerilog, and proves the important cases with a self-checking testbench and assertions.

The designs deliberately grow from arithmetic and priority logic into flow control, clock-domain crossing, pipelining, and packet movement. A reader can run the entire repository with one command and then study one project at a time.

## The seven-day path

| Day | Project | Main design idea | Verification focus |
|---:|---|---|---|
| 1 | [New York clock](day01_nyc_clock) | Calendar arithmetic and US daylight-saving boundaries | Exact spring/fall transitions, leap year, date borrow, invalid input |
| 2 | [Round-robin arbiter](day02_round_robin_arbiter) | Parameterized fair priority | Rotation, sparse request sets, idle behavior, one-hot grant |
| 3 | [Byte-enable register file](day03_byte_enable_register_file) | Partial writes and same-cycle forwarding | Per-byte merge, two read ports, bypass, random reference model |
| 4 | [Ready/valid skid buffer](day04_ready_valid_skid_buffer) | Elastic flow control under backpressure | Stall stability, simultaneous pop/push, no loss or reordering |
| 5 | [CDC pulse synchronizer](day05_cdc_pulse_synchronizer) | Toggle-based event transfer | Unrelated clocks, one destination pulse per source event |
| 6 | [Pipelined signed MAC](day06_pipelined_mac) | Valid tracking and sign extension | Bubbles, signed corners, clear/flush, cycle-accurate accumulator model |
| 7 | [2×2 packet router](day07_two_by_two_router) | Buffered outputs and per-output arbitration | Contention fairness, backpressure, packet conservation and ordering |

## What every project contains

- A focused specification with explicit assumptions and corner cases.
- Synthesizable RTL; verification-only constructs stay in the testbench or assertions.
- Directed tests for boundary behavior and randomized traffic checked against a reference model.
- Assertions for invariants such as one-hot grants, stable data during stalls, and valid pipeline behavior.
- A verification matrix and the exact expected PASS line.
- An interview-ready explanation, follow-up questions, traps, and a short revision card.

## Run the complete regression

### Verilator (verified)

Requirements: Bash, GNU Make, a C++ compiler, and Verilator 5.x.

```bash
make regression
```

Run one day:

```bash
make day DAY=04
```

The scripts compile with `--timing --assert -Wall`, so timing controls and SVA are enabled. Build products and logs are written below `build/` and `logs/`; neither is committed.

### Cadence Xcelium

On a machine with Xcelium and a valid license:

```bash
make xcelium
```

The Xcelium script uses `xrun -64bit -sv -assert`. The checked-in regression record was produced with Verilator because Xcelium is not installed in this workspace; no unexecuted Xcelium result is presented as proof.

## Verification philosophy

A test only counts when it can fail by itself. The benches therefore do not rely on reading waveforms to decide whether the result is correct:

1. Inputs are driven away from the sampling edge to avoid races.
2. A small independent model predicts the result.
3. The testbench compares every accepted transaction or output item.
4. SVA checks continuous protocol invariants.
5. End-of-test conservation checks catch missing or duplicated work.

See [the recorded regression report](docs/verification_report.md) and [the coverage plan](docs/coverage_plan.md) for the exact evidence.

## Repository map

```text
7-days-of-rtl/
├── day01_nyc_clock/ ... day07_two_by_two_router/
│   ├── rtl/                 # synthesizable design
│   ├── tb/                  # self-checking SystemVerilog testbench
│   ├── README.md            # specification + explanation + interview prep
│   └── expected_output.md   # observable passing result
├── docs/                    # cross-project coverage and regression record
├── scripts/                 # Verilator, Xcelium, and structure checks
└── .github/workflows/       # automatic regression on every push/PR
```

## A good way to study this repository

For each day, read the contract before the RTL. Predict the behavior of the directed cases, run the test, and then change one line deliberately to make an assertion or scoreboard fail. That last step is valuable: it proves the checker is sensitive to the bug it claims to detect.

## Scope

These are compact educational blocks, not drop-in production IP. Reset strategy, implementation technology, timing constraints, CDC sign-off, and safety requirements must be adapted for a target chip. The README for each design calls out its operating assumptions rather than hiding them.

## License

Released under the [MIT License](LICENSE).
