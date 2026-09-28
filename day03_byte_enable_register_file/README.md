# Day 3 — Byte-enable register file with forwarding

## What this block does

This is an eight-entry, parameterized-width register file with one write port, two asynchronous read ports, per-byte write enables, and write-through forwarding. The default configuration stores eight 32-bit words.

## Why it matters

Partial writes occur in CPU register files, CSRs, packet metadata, memory-mapped peripherals, and cache structures. A second design issue appears when a read and write target the same word in one cycle: relying on inferred memory behavior can make the result technology-dependent. Explicit bypass logic gives the interface a deterministic contract.

## Behavioral contract

- Reset clears every word.
- On a write edge, only bytes with `byte_en[lane] == 1` change.
- Both read ports are asynchronous.
- During a same-address read/write cycle, each enabled byte immediately shows `wr_data`; disabled bytes retain the stored value.
- The two read ports operate independently and may select the same address.

## How the byte merge works

For each lane:

```systemverilog
if (byte_en[lane])
    mem[wr_addr][lane*8 +: 8] <= wr_data[lane*8 +: 8];
```

The same loop is repeated in combinational forwarding logic for each read port. This matters when only some bytes are enabled: forwarding the entire `wr_data` word would corrupt the disabled lanes at the interface.

## Worked example

Stored word at address 3: `32'h1122_3344`

Write data: `32'hAABB_CCDD`, enable mask `4'b0101`

| Byte lane | Enable | Result byte |
|---:|---:|---|
| 3 | 0 | `11` |
| 2 | 1 | `BB` |
| 1 | 0 | `33` |
| 0 | 1 | `DD` |

Final word: `32'h11BB_33DD`. A same-cycle read sees that merged value before the clock commits it.

## Verification

The testbench contains a reference-memory model with the same byte-level contract but separate implementation. It checks full writes, alternating byte masks, simultaneous reads, write-through behavior, and 60 randomized transactions. Generated assertions independently check forwarding for every byte lane on both read ports.

```bash
make day DAY=03
```

## Interview-ready answer

> I implemented a one-write/two-read register file with byte enables and explicit write-through forwarding. At the active edge, each enabled byte slice is updated independently. Reads are asynchronous. If a read address matches the current write address, I overlay only the enabled write-data bytes onto the stored word; disabled lanes still come from memory. That makes read-during-write behavior deterministic rather than depending on an inferred RAM primitive. The testbench mirrors the memory in a reference model, generates partial and random writes, and assertions check every forwarded byte on both ports.

## Interview questions and concise answers

1. **Why not forward the whole word?** Disabled byte lanes must retain the old stored value.
2. **What are common read-during-write policies?** Read-first returns old data, write-first returns new data, and no-change holds the previous read output.
3. **Will this always infer a block RAM?** No. Asynchronous dual reads, reset clearing, and byte-level bypass may map to flops or distributed RAM depending on the technology.
4. **Why is reset-clearing a large memory expensive?** It creates reset logic for every stored bit unless the target memory primitive supports it.
5. **How would you add ECC?** Store/check code bits per word, define how partial writes perform read-modify-write, and verify correctable/uncorrectable error behavior.

## Common traps

- Reversing the byte-enable-to-bit-slice mapping.
- Forwarding enabled data to only one of the read ports.
- Updating the reference model before checking the pre-edge bypass value.
- Assuming inferred-memory collision behavior is identical across FPGA/ASIC libraries.

## Revision card

**Partial write:** merge by byte lane. **Collision rule:** explicit write-through forwarding. **Proof:** reference memory plus per-lane bypass assertions.
