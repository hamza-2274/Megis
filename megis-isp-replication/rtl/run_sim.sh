#!/usr/bin/env bash
# Simulate the MegIS in-storage accelerator with Icarus Verilog (11+, SystemVerilog mode).
# Usage:
#   bash rtl/run_sim.sh phase1   # Step 2: k-mer intersection only
#   bash rtl/run_sim.sh phase2   # Step 2 + Step 3: intersection followed by TaxID retrieval
set -euo pipefail
PHASE="${1:-phase2}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HERE/build"

case "$PHASE" in
  phase1)
    cd "$HERE/phase1_intersection"
    iverilog -g2012 -o "$HERE/build/phase1.vvp" \
        intersector.sv dram_module.sv nand_flash_sim.sv megis_top.sv tb_megis.sv
    vvp "$HERE/build/phase1.vvp" ;;
  phase2)
    cd "$HERE/phase2_taxid"
    iverilog -g2012 -o "$HERE/build/phase2.vvp" \
        intersector.sv index_generator.sv dram_module.sv host_memory.sv nand_flash_sim.sv megis_top.sv tb_megis.sv
    vvp "$HERE/build/phase2.vvp" ;;
  *)
    echo "usage: bash rtl/run_sim.sh [phase1|phase2]" >&2; exit 1 ;;
esac
