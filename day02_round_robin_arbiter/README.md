# Day 2 — Parameterized round-robin arbiter

## What this block does

The arbiter accepts `NUM_REQUESTERS` request bits and produces a one-hot-or-zero grant. Priority starts immediately after the most recently granted requester, so continuously active requesters take turns instead of allowing a fixed-priority winner to dominate.

## Why it matters

Arbiters appear at shared memories, buses, NoC links, DMA engines, and interrupt controllers. A fixed-priority arbiter is small but can starve a low-priority client. Round-robin adds fairness with one piece of state: the last winner.

## Behavioral contract

- At most one grant is asserted.
- A grant is never produced without the matching request.
- No request means no grant.
- With continuous full contention, grants rotate `0, 1, ... N−1, 0`.
- The history pointer updates only when a grant occurs; idle cycles do not move priority.
- After reset, requester zero has first priority.

## How it works

The combinational loop scans `last_grant + 1` through all requesters, wrapping once at `NUM_REQUESTERS`. A `found` flag keeps the first active request and suppresses later candidates. The sequential block records the winner for use on the next cycle.

For `N=4` and `last_grant=1`, request mask `1011` is examined in the order `2,3,0,1`. Requester 3 is the first asserted candidate, so the grant is `1000`.

## Cycle example under full contention

| Cycle after reset | Request | Grant | New last winner |
|---:|---|---|---:|
| 1 | `1111` | `0001` | 0 |
| 2 | `1111` | `0010` | 1 |
| 3 | `1111` | `0100` | 2 |
| 4 | `1111` | `1000` | 3 |

## Verification

The testbench maintains an independent software-style rotating-priority model. It checks two complete full-contention rotations, idle, sparse masks, a single requester, and 40 random request masks. SVA continuously proves one-hot-or-idle behavior, grant/request correspondence, and no grant while idle.

```bash
make day DAY=02
```

## Interview-ready answer

> A round-robin arbiter prevents starvation by making the priority order depend on the previous winner. My combinational logic scans all requesters starting just after `last_grant`, selects the first active request, and emits a one-hot grant. On the clock edge, I update `last_grant` only when someone wins, so idle cycles do not change fairness. Reset initializes the pointer so requester zero wins first. I verify it with an independent rotating-priority model plus assertions that the grant is one-hot-or-zero and always a subset of the request vector.

## Interview questions and concise answers

1. **Can round-robin guarantee a fixed latency?** With `N` continuously requesting clients and one grant per cycle, a client waits at most `N−1` grants, assuming service never stalls.
2. **Why not update the pointer every cycle?** Idle cycles would change priority without service and make behavior harder to reason about.
3. **What if `N` is not a power of two?** The explicit comparison/subtraction wraps at `N`; unused binary pointer values are never intentionally loaded.
4. **Is a grant the same as a completed transfer?** Not always. In a ready/valid system, fairness state normally advances on an accepted transfer, not merely arbitration.
5. **How would weighted round-robin differ?** Each client receives a programmable number of service credits before priority advances.

## Common traps

- Producing a binary index when downstream logic expects a one-hot grant.
- Updating fairness state on a stalled or unaccepted grant.
- Using modulo carelessly with non-power-of-two parameters.
- Checking rotation only with all requesters active; sparse masks reveal wrap bugs.

## Revision card

**State:** last successful winner. **Search:** start at the next requester and wrap. **Assertions:** `$onehot0(grant)` and `grant & ~req == 0`. **Fairness proof:** persistent request plus continuing service eventually wins.
