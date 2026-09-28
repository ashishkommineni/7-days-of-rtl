# Day 4 — Ready/valid skid buffer

## What this block does

This one-entry elastic buffer sits between a ready/valid producer and consumer. It accepts data when space is available, holds data stable while the consumer applies backpressure, and sustains one transfer per cycle when dequeue and enqueue happen together.

## Why it matters

Ready/valid is simple only when both sides are always ready. Real pipelines stall. A buffer breaks a long combinational path, absorbs one item when readiness changes, and makes the “hold valid and data until accepted” rule explicit.

## Handshake contract

A transfer occurs on a rising edge when both signals are high:

- Input acceptance: `in_valid && in_ready`
- Output delivery: `out_valid && out_ready`

The producer owns `in_valid/in_data`; the consumer owns `out_ready`. Once `out_valid` is asserted, this buffer holds both `out_valid` and `out_data` until delivery.

## Internal behavior

`full` represents the single occupied slot.

```systemverilog
in_ready = !full || out_ready;
```

That expression has three important cases:

| Current state | `out_ready` | `in_ready` | Next action |
|---|---:|---:|---|
| Empty | X | 1 | Accept a new item if valid |
| Full | 0 | 0 | Hold current item and backpressure input |
| Full | 1 | 1 | Deliver current item and optionally replace it |

When `in_ready` is true, the next occupancy becomes `in_valid`. Data is captured only when input valid is high.

## Verification

The scoreboard records every accepted input and compares every delivered output in FIFO order. Directed cases exercise empty load, full stall, simultaneous pop/push, stable hold, and drain. Eighty randomized ready/valid cycles follow, then the bench drains the buffer and proves `accepted == delivered`.

SVA checks that a stalled output remains valid with stable data and that a full, blocked buffer deasserts `in_ready`. A cover property identifies a full-throughput simultaneous dequeue/enqueue cycle.

```bash
make day DAY=04
```

## Interview-ready answer

> A ready/valid skid buffer stores one transfer and protects the interface during backpressure. I track one `full` bit and a data register. Input ready is high when the slot is empty or when the current output will be consumed, which allows a pop and push on the same edge. If the output is valid but the consumer is not ready, neither the valid bit nor data can change. My testbench uses a FIFO scoreboard and conservation counters, while SVA proves stable output under stall and correct input backpressure.

## Interview questions and concise answers

1. **Can valid depend combinationally on ready?** A source should generate valid independently; otherwise two endpoints can create a combinational loop or deadlock.
2. **Why is `in_ready = !full || out_ready` useful?** It allows replacement of a consumed item in the same cycle, maintaining one item per cycle throughput.
3. **What is the buffer latency?** An accepted item becomes registered output data after the active edge; delivery depends on downstream ready.
4. **How is this different from a two-entry FIFO?** It has one storage slot and simpler pointers, so its capacity is one even though throughput can be one per cycle.
5. **What must remain stable during a stall?** `out_valid` must stay asserted and `out_data` must not change until accepted.

## Common traps

- Clearing `full` on `out_ready` even when `out_valid` is low.
- Forgetting simultaneous dequeue/enqueue and inserting a bubble.
- Changing data while valid is high and ready is low.
- Counting attempted inputs instead of only accepted inputs in the scoreboard.

## Revision card

**Transfer:** valid and ready together at the clock edge. **Backpressure rule:** stable valid/data. **Throughput rule:** permit pop and push together. **Proof:** ordered scoreboard plus conservation counts.
