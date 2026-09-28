#!/usr/bin/env bash
set -euo pipefail

for number in 01 02 03 04 05 06 07; do
    day_dir=$(find . -maxdepth 1 -type d -name "day${number}_*" -print -quit)
    [[ -n "${day_dir}" ]] || { echo "Missing day ${number}"; exit 1; }
    [[ -f "${day_dir}/README.md" ]] || { echo "Missing ${day_dir}/README.md"; exit 1; }
    [[ -f "${day_dir}/expected_output.md" ]] || { echo "Missing ${day_dir}/expected_output.md"; exit 1; }
    compgen -G "${day_dir}/rtl/*.sv" >/dev/null || { echo "Missing RTL for ${day_dir}"; exit 1; }
    compgen -G "${day_dir}/tb/*.sv" >/dev/null || { echo "Missing testbench for ${day_dir}"; exit 1; }
done

echo "[STRUCTURE] PASS: seven days contain RTL, testbench, explanation, and expected output"
