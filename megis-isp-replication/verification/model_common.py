"""Cycle-accurate Python model helpers for the MegIS RTL.

Semantics mirrored from the SystemVerilog:
  * always_comb blocks are evaluated from the current register values,
  * every always_ff block samples those same values and all registers
    update together at the rising edge (non-blocking assignment).
"""

import os
RTL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rtl")

ONES10 = (1 << 10) - 1


def phase1_flash_rows():
    """48 rows x 4 channels, value = 3 + 4*row + channel (as in nand_flash_sim.sv)."""
    return [[3 + 4 * r + c for c in range(4)] for r in range(48)]


def check_phase1_preload(sv_path):
    """Parse the preload table in nand_flash_sim.sv and confirm the formula above."""
    import re
    rows = parse_preload(sv_path)
    assert rows == phase1_flash_rows(), "preload table does not match formula"
    return len(rows)


def parse_preload(sv_path):
    """Return the 48x4 preload table exactly as written in the .sv file."""
    import re
    tab = {}
    for r, c, v in re.findall(r"preload_data\[(\d+)\]\[(\d)\]\s*=\s*10'b([01]{10})", open(sv_path).read()):
        tab[(int(r), int(c))] = int(v, 2)
    return [[tab[(r, c)] for c in range(4)] for r in range(48)]
