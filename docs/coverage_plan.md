# Coverage plan

This repository uses a compact, transparent coverage strategy: directed requirement cases, randomized model comparison, assertion coverage for important temporal events, and end-of-test conservation checks. The goal is traceability, not an inflated percentage with no link to behavior.

| Day | Requirement scenarios | Continuous assertions | End-to-end check |
|---:|---|---|---|
| 1 | EST, EDT, both transitions, year/leap borrow, invalid dates | Valid outputs remain inside calendar/time ranges | Ten exact date-time vectors |
| 2 | Full contention, sparse, single, idle, random request masks | Grant is one-hot-or-zero; every grant has a request; idle grants none | Independent rotating-priority model |
| 3 | Full/partial write, both bypass ports, random addresses/data/masks | Enabled bytes forward on both read ports | Byte-merge reference memory |
| 4 | Empty load, full stall, pop+push, drain, random ready/valid | Stalled output remains valid/stable; full stall blocks input | Accepted count equals delivered count; FIFO scoreboard |
| 5 | Six events at different phases of unrelated clocks | Source spacing and one-cycle destination pulse | Sent event count equals received count |
| 6 | Positive/negative products, bubbles, numeric corners, random signed operands | Valid result is known; clear flushes pipeline | Cycle-aligned arithmetic model |
| 7 | Independent paths, repeated contention, stall/release, held-valid random packets | Stalled outputs stable; at most one contender accepted | Per-output scoreboards and packet conservation |

## Why no single coverage percentage is quoted

Verilator assertion/functional coverage databases depend on build options and tool version. A percentage without a stable coverage model is easy to misread. Instead, each requirement has a named test and checker. The CI command enables assertions, and the test exits non-zero on the first violated requirement.

For an Xcelium coverage run, add the coverage options used by your team (for example, your approved code/assertion coverage configuration) to `scripts/run_xcelium.sh`, then merge and inspect the generated databases under your normal vManager/IMC flow.
