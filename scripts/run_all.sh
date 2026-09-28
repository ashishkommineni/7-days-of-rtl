#!/usr/bin/env bash
set -euo pipefail

verilator_bin=${VERILATOR:-verilator}
selected_day=${1:-all}

days=(
  "01|day01_nyc_clock|tb_nyc_clock|nyc_clock.sv|tb_nyc_clock.sv"
  "02|day02_round_robin_arbiter|tb_round_robin_arbiter|round_robin_arbiter.sv|tb_round_robin_arbiter.sv"
  "03|day03_byte_enable_register_file|tb_byte_enable_register_file|byte_enable_register_file.sv|tb_byte_enable_register_file.sv"
  "04|day04_ready_valid_skid_buffer|tb_ready_valid_skid_buffer|ready_valid_skid_buffer.sv|tb_ready_valid_skid_buffer.sv"
  "05|day05_cdc_pulse_synchronizer|tb_cdc_pulse_synchronizer|cdc_pulse_synchronizer.sv|tb_cdc_pulse_synchronizer.sv"
  "06|day06_pipelined_mac|tb_pipelined_mac|pipelined_mac.sv|tb_pipelined_mac.sv"
  "07|day07_two_by_two_router|tb_two_by_two_router|two_by_two_router.sv|tb_two_by_two_router.sv"
)

mkdir -p build logs

run_day() {
    local number=$1 directory=$2 top=$3 rtl=$4 tb=$5
    local build_dir="build/day${number}"
    local compile_log="logs/day${number}_compile.log"
    local run_log="logs/day${number}_run.log"
    mkdir -p "${build_dir}"
    echo "[RUN] Day ${number}: ${directory}"
    if ! "${verilator_bin}" --binary --timing --assert -Wall -Wno-fatal \
        -Wno-SYNCASYNCNET \
        --top-module "${top}" --Mdir "${build_dir}" \
        "${directory}/rtl/${rtl}" "${directory}/tb/${tb}" >"${compile_log}" 2>&1; then
        cat "${compile_log}"
        return 1
    fi
    "${build_dir}/V${top}" | tee "${run_log}"
}

matched=0
for entry in "${days[@]}"; do
    IFS='|' read -r number directory top rtl tb <<<"${entry}"
    if [[ "${selected_day}" == "all" || "${selected_day}" == "${number}" ]]; then
        run_day "${number}" "${directory}" "${top}" "${rtl}" "${tb}"
        matched=1
    fi
done

[[ ${matched} -eq 1 ]] || { echo "Unknown day '${selected_day}'. Use 01 through 07."; exit 2; }
echo "[REGRESSION] PASS: selected RTL projects completed without assertion failures"
