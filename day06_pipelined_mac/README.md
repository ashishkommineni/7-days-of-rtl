# Day 6 — Pipelined signed multiply-accumulate

## What this block does

The MAC accepts signed operand pairs with `in_valid`, registers their product, adds valid products into a wider accumulator, and asserts `out_valid` when the updated accumulation is available. `clear_acc` flushes the pending operation and resets the sum.

## Why it matters

MACs sit at the heart of DSP, filters, neural-network accelerators, and address/metric calculations. The multiplication itself is straightforward; correctness depends on signed interpretation, product width, accumulator width, pipeline latency, and keeping valid aligned through bubbles.

## Datapath and control

- Two `OPERAND_WIDTH` signed operands produce a `2*OPERAND_WIDTH` signed product.
- The product is sign-extended to `ACC_WIDTH` before addition.
- `valid_s1` tracks whether the product register contains a real operation.
- On the following cycle, a valid product updates both the internal accumulator and visible `result`.
- A bubble propagates through valid without changing the sum.
- `clear_acc` has priority over new input and removes any pending product.

## Cycle example

Starting from zero:

| Input cycle | Input | Product | Output on next cycle |
|---:|---|---:|---:|
| 1 | `3 × 4` valid | 12 | 12 |
| 2 | `−2 × 5` valid | −10 | 2 |
| 3 | bubble | — | no valid output |
| 4 | `−128 × 127` valid | −16256 | −16254 |

The table describes the post-edge visible behavior used by the testbench.

## Verification

The reference model keeps a pending product and signed integer accumulator. After every edge it checks the exact valid latency and result. Directed cases include positive/negative products, bubbles, minimum/maximum 8-bit operands, clear/flush, followed by 50 randomized signed operations. Assertions require known valid results and verify that clear flushes the pipeline.

```bash
make day DAY=06
```

## Interview-ready answer

> My MAC has a registered signed product stage and an accumulation stage. The two W-bit signed operands create a 2W-bit product, which I explicitly sign-extend to the accumulator width before addition. A valid bit travels with the product so bubbles do not update the sum, and `out_valid` identifies the cycle containing the new accumulated result. Clear resets the accumulator and flushes the pending product. The bench models both the arithmetic and latency cycle by cycle, including signed corner values and random bubbles.

## Interview questions and concise answers

1. **Why is the product `2W` bits?** Multiplying two W-bit values can require up to 2W result bits, including signed range.
2. **Why explicitly sign-extend?** Zero extension would turn a negative product into a large positive addend.
3. **What happens on accumulator overflow?** This implementation wraps in two's-complement width. Saturation would require overflow detection and clamp logic.
4. **Why pipeline a MAC?** Registers shorten combinational paths and raise frequency, at the cost of latency and valid/control tracking.
5. **What does clear do to an in-flight product?** It flushes it by clearing `valid_s1`; the product is not accumulated later.

## Common traps

- Declaring only one operand signed or losing signedness through a cast.
- Choosing accumulator width without a bound on the number of terms.
- Comparing results without accounting for pipeline latency.
- Clearing the sum but leaving a valid product in flight.

## Revision card

**Width:** W×W → 2W product → sign-extend to accumulator. **Control:** valid travels with data. **Clear:** sum reset plus pipeline flush. **Proof:** signed, latency-aware reference model.
