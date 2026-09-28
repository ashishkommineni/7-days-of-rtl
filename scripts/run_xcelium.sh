#!/usr/bin/env bash
set -euo pipefail

command -v xrun >/dev/null || {
    echo "xrun was not found. Load the Cadence Xcelium environment and license first."
    exit 127
}

days=(
  "01|day01_nyc_clock|tb_nyc_clock|nyc_clock.sv|tb_nyc_clock.sv"
  "02|day02_round_robin_arbiter|tb_round_robin_arbiter|round_robin_arbiter.sv|tb_round_robin_arbiter.sv"
  "03|day03_byte_enable_register_file|tb_byte_enable_register_file|byte_enable_register_file.sv|tb_byte_enable_register_file.sv"
  "04|day04_ready_valid_skid_buffer|tb_ready_valid_skid_buffer|ready_valid_skid_buffer.sv|tb_ready_valid_skid_buffer.sv"
  "05|day05_cdc_pulse_synchronizer|tb_cdc_pulse_synchronizer|cdc_pulse_synchronizer.sv|tb_cdc_pulse_synchronizer.sv"
  "06|day06_pipelined_mac|tb_pipelined_mac|pipelined_mac.sv|tb_pipelined_mac.sv"
  "07|day07_two_by_two_router|tb_two_by_two_router|two_by_two_router.sv|tb_two_by_two_router.sv"
)

mkdir -p logs xcelium.d
for entry in "${days[@]}"; do
    IFS='|' read -r number directory top rtl tb <<<"${entry}"
    echo "[XRUN] Day ${number}: ${directory}"
    xrun -64bit -sv -assert -access +rwc -top "${top}" \
        -xmlibdirname "xcelium.d/day${number}" \
        "${directory}/rtl/${rtl}" "${directory}/tb/${tb}" \
        -l "logs/day${number}_xcelium.log"
done
echo "[XCELIUM REGRESSION] PASS: all seven simulations completed"
