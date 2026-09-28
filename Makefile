SHELL := /bin/bash
VERILATOR ?= verilator
DAY ?= 01

.PHONY: regression day structure xcelium clean

regression: structure
	VERILATOR="$(VERILATOR)" ./scripts/run_all.sh

day:
	VERILATOR="$(VERILATOR)" ./scripts/run_all.sh "$(DAY)"

structure:
	./scripts/check_structure.sh

xcelium: structure
	./scripts/run_xcelium.sh

clean:
	rm -rf build logs xcelium.d
