# Day 7 — Buffered 2×2 packet router

## What this block does

Two ready/valid inputs each carry a destination bit and payload. The router sends destination 0 packets to output 0 and destination 1 packets to output 1. Each output has a one-entry elastic buffer and its own round-robin contention history.

## Why the buffers are important

A purely combinational arbiter can change its selected input while the destination is stalled, which can change `out_data` while `out_valid && !out_ready`. Registering one slot per output makes the external contract stable. It also allows an output to deliver one packet and accept its replacement on the same edge.

## Behavioral contract

- A packet is accepted only when its input sees `valid && ready`.
- Packets route only to their selected output.
- If both inputs request different outputs, both can be accepted together.
- If both request one available output, exactly one wins.
- Repeated contention alternates winners for that output.
- A stalled output holds valid and data stable.
- Each output preserves the acceptance order of packets routed to it.

## Internal flow

1. `slot_ready[o] = !full[o] || out_ready[o]` tells whether output `o` can accept a packet.
2. Each output independently builds requests from the two inputs whose destination matches it.
3. A single request wins directly; dual requests use the opposite of `last_winner[o]`.
4. Input ready is the matching grant. A granted payload is captured into that output buffer.
5. Fairness history updates only when a packet is accepted.

Because every input has one destination, one input cannot win both outputs in the same cycle.

## Contention example

With output 0 empty and reset history:

| Cycle | Input 0 packet | Input 1 packet | Accepted |
|---:|---|---|---|
| 1 | dest 0, `C010` | dest 0, `C020` | input 0 |
| 2 | dest 0, `C011` | dest 0, `C020` | input 1 |
| 3 | dest 0, `C011` | none | input 0 |

The blocked source holds its packet until accepted; the randomized driver follows the same rule.

## Verification

There are independent FIFO scoreboards for the two outputs. Directed traffic checks first-winner priority, alternating contention, simultaneous independent routes, and multiple stalled cycles. One hundred randomized cycles keep each source valid until accepted. The bench then accepts all pending sources, drains both outputs, and requires total accepted packets to equal total delivered packets.

SVA keeps stalled output data stable and prevents both contenders for one output from being accepted together.

```bash
make day DAY=07
```

## Interview-ready answer

> I designed a two-input, two-output ready/valid router. Each input provides a destination bit; each output arbitrates only the inputs targeting it. To preserve the interface during backpressure, every output has a one-entry elastic buffer. If the buffer is empty or being consumed, arbitration can accept a replacement. Dual requests use per-output round-robin history, updated only on acceptance. The testbench has separate output scoreboards, holds blocked source packets correctly, checks contention and stalls, and finishes with packet-conservation and ordering checks.

## Interview questions and concise answers

1. **Why is arbitration per output?** Inputs targeting different outputs should proceed simultaneously; a global arbiter would unnecessarily serialize them.
2. **Why update fairness on acceptance?** A selection that cannot enter the output buffer has not received service.
3. **How does the design keep output stable under stall?** Full output buffers disable replacement until the current item is consumed.
4. **Can head-of-line blocking occur?** With no input queues, a held packet blocks that source from presenting another destination. Deeper virtual/output queues address larger-router HOL effects.
5. **How would this scale to N×M?** Build an M-way arbitration decision per output plus logic ensuring each input is granted at most once; complexity and timing grow quickly.

## Common traps

- Changing arbitration winner while an output is stalled.
- Deasserting source valid before ready and silently dropping the packet in the testbench.
- Using one global fairness pointer for unrelated outputs.
- Checking packet count but not per-output order.
- Advancing priority when no packet was accepted.

## Revision card

**Route:** destination selects output request. **Arbitrate:** one round-robin decision per output. **Buffer:** hold stable through backpressure. **Proof:** two ordered scoreboards plus accepted/delivered conservation.
