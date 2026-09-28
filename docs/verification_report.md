# Verification report

## Recorded result

- Date: 2026-09-28
- Local simulator: Verilator 5.49
- Hosted CI: Ubuntu 24.04 with Verilator 5.020
- Compile mode: SystemVerilog, timing enabled, assertions enabled, `-Wall`
- Result: seven passes in both environments, zero assertion failures, zero simulation fatals
- GitHub Actions evidence: RTL regression run #2, commit `9385d590`, completed successfully in 1m 2s

| Day | Recorded PASS evidence |
|---:|---|
| 1 | `10 NYC clock checks, including both DST boundaries` |
| 2 | `52 arbitration checks; one-hot and fairness assertions active` |
| 3 | `64 register-file transactions with byte bypass` |
| 4 | `85 cycles, accepted=26 delivered=26, no loss/reorder` |
| 5 | `6 source events crossed unrelated clocks exactly once` |
| 6 | `59 pipeline cycles, final signed accumulator=36551` |
| 7 | `112 cycles, 74 packets routed without loss/reorder` |

Random-value totals are deterministic for the recorded simulator build but may change when another simulator uses a different random-number stream. Correctness does not depend on a particular random total; every run recomputes its reference result.

## Defect found during verification

The first Day-7 directed run reported that input zero did not win a supposed “first contention.” RTL inspection showed the arbiter history had already been updated by an earlier independent transfer. The fault was in test ordering, not arbitration. The reset-priority contention was moved before any transfer, and the next cycle explicitly proved rotation to input one. The repaired test then passed all directed and randomized traffic.

The first hosted CI run also found a portability issue rather than a design failure. Verilator 5.49 accepted a temporal `cover property` sequence using `##1`, while Ubuntu's Verilator 5.020 reported that cover-sequence syntax as unsupported. The cover point was reduced to the portable `out_valid` event; the existing cycle-accurate scoreboard still proves the input-to-output latency. After that correction, the full hosted seven-project regression passed.

Two earlier Day-1 design risks are guarded explicitly:

- Sunday indexing uses the Gregorian/Sakamoto convention (`Sunday = 0`), avoiding a one-day DST boundary shift.
- UTC offset arithmetic uses a signed integer intermediate, avoiding overflow in a 5-bit hour value.

## Reproduce

```bash
make clean
make regression
```

Expected final line:

```text
[REGRESSION] PASS: selected RTL projects completed without assertion failures
```

## Sign-off boundary

This is simulation sign-off for the stated educational specifications. It is not physical-design sign-off. Day 5 still needs target-library synchronizer constraints and CDC analysis; all designs need project-specific lint, synthesis, STA, reset, and low-power review before silicon use.
