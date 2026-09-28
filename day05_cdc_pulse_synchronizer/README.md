# Day 5 — CDC pulse synchronizer

## What this block does

This module transfers a one-cycle event from a source clock domain into an unrelated destination clock domain. The source converts the event into a persistent toggle, the destination synchronizes that level through two flops, and an XOR edge detector recreates a one-cycle destination pulse.

## Why a pulse needs special treatment

A conventional two-flop synchronizer is suitable for a slowly changing level, not an arbitrarily narrow pulse. A destination clock can sample before and after the pulse without ever seeing it. Toggling a bit turns the short event into a state change that remains visible until the destination captures it.

## Internal sequence

1. A source event flips `src_toggle`.
2. `dst_sync_ff1` samples the asynchronous level and is the metastability containment stage.
3. `dst_sync_ff2` provides the clean synchronized level used by logic.
4. `dst_sync_ff2_d` holds the prior synchronized value.
5. `dst_sync_ff2 ^ dst_sync_ff2_d` is high for one destination cycle when a change arrives.

The `ASYNC_REG` attributes mark the destination synchronizer flops for implementation tools. Actual library mapping, placement, and timing exceptions still belong in the chip constraints.

## Usage assumptions

- Source and destination resets are coordinated in this educational design.
- A new source event is not sent until the destination has enough time to observe the previous toggle.
- This transports an event, not a multi-bit payload.
- If events can arrive faster than the destination can resolve toggles, use a handshake, counter, or asynchronous FIFO.

## Verification

The clocks run at 8 ns and 14 ns periods so their edges continually change phase. Six events are sent with different gaps. Independent source/destination monitors count accepted source pulses and reconstructed destination pulses. The final check requires exact equality. Assertions require source spacing and prevent a destination pulse from lasting more than one cycle.

```bash
make day DAY=05
```

## Interview-ready answer

> A single-cycle pulse can be missed when crossing to an unrelated clock, so I encode the event as a toggle in the source domain. The toggle persists, crosses a two-flop synchronizer, and is compared with a delayed copy in the destination; their XOR creates one destination-cycle pulse. The first synchronizer flop may go metastable, while downstream logic only uses the second stage. This method has a rate limit: the source must not toggle twice before the destination observes the first change. For higher rates or payload transfer I would use a request/acknowledge handshake or async FIFO.

## Interview questions and concise answers

1. **Does a two-flop synchronizer eliminate metastability?** No. It reduces the probability that metastability propagates by giving the first stage time to resolve.
2. **Why not synchronize the pulse directly?** A narrow pulse may occur entirely between destination edges.
3. **Can back-to-back source events be lost?** Yes. Two toggles before observation can cancel and appear as no change.
4. **Why should only the second stage feed logic?** Using the first stage exposes functional logic to metastability risk and routing variation.
5. **How do you cross a multi-bit bus?** Use a coherent protocol: handshake-held data, Gray-coded pointers for FIFOs, or another reviewed CDC structure—not independent bit synchronizers.

## Common traps

- Calling simulation proof a metastability sign-off; digital simulation does not model analog resolution.
- Adding combinational logic between synchronizer stages.
- Ignoring reset release as a CDC event.
- Forgetting the maximum event-rate assumption.

## Revision card

**Encode:** pulse to toggle. **Cross:** two destination flops. **Decode:** XOR current and delayed synchronized toggle. **Limitation:** source event spacing. **Physical proof:** CDC analysis plus synchronizer constraints.
