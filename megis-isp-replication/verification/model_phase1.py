"""Cycle-accurate model of rtl/phase1_intersection (megis_top.sv + submodules + tb_megis.sv)."""
import sys
import os
from model_common import RTL, phase1_flash_rows, check_phase1_preload, ONES10

IDLE, INIT_FETCH, INIT_LATCH_NEXT, INIT_LATCH_CURR, FETCH_QUERY, COMPARE, WRITE_MATCH, UPDATE_POINTERS = range(8)
NAMES = "IDLE INIT_FETCH INIT_LATCH_NEXT INIT_LATCH_CURR FETCH_QUERY COMPARE WRITE_MATCH UPDATE_POINTERS".split()


def run(dram_init, sim_ns_after_start=2500, verbose=False, reversed_ports=False):
    # ---- flash (initial block) ----
    flash = [[ONES10] * 256 for _ in range(4)]
    for r, row in enumerate(phase1_flash_rows()):
        for c in range(4):
            flash[c][r] = row[c]

    # ---- registers after reset ----
    mem = list(dram_init) + [0] * (32 - len(dram_init))
    S = dict(state=IDLE, query_ptr=0, match_ptr=10, pipeline_ready=0, match_count=0,
             dram_out=0, dram_valid=0,
             flash_out=[0, 0, 0, 0],  # no reset in nand_flash_sim -> X; never consumed before written
             curr=[0] * 4, nxt=[0] * 4, faddr=[0] * 4)
    log = []

    # tb: rst_n=1 @20ns, start=1 during [30,40) ns, clock posedges at 5,15,25,...
    # posedge at 35 ns sees start=1. Simulation stops at 40+2500 = 2540 ns.
    t = 5
    end_t = 40 + sim_ns_after_start
    while t < end_t:
        start = 1 if 30 <= t < 40 else 0
        rst_active = t < 20
        if rst_active:
            t += 10
            continue
        st = S["state"]
        q = S["dram_out"]
        less = [int(S["curr"][i] < q) for i in range(4)]
        eq = [int(S["curr"][i] == q) for i in range(4)]
        gt = [int(S["curr"][i] > q) for i in range(4)]
        any_eq = any(eq)
        all_gt = all(gt)

        # ---- always_comb ----
        nst = st
        dram_re = dram_we = 0
        dram_wr_addr = S["match_ptr"]; dram_w_data = q
        dram_rd_addr = S["query_ptr"]
        fre = [0] * 4; sh = [0] * 4; ld = [0] * 4; inc = [0] * 4
        if st == IDLE:
            if start: nst = INIT_FETCH
        elif st == INIT_FETCH:
            fre = [1] * 4; nst = INIT_LATCH_NEXT
        elif st == INIT_LATCH_NEXT:
            fre = [1] * 4; ld = [1] * 4; inc = [1] * 4; nst = INIT_LATCH_CURR
        elif st == INIT_LATCH_CURR:
            sh = [1] * 4; ld = [1] * 4; fre = [1] * 4; inc = [1] * 4; nst = FETCH_QUERY
        elif st == FETCH_QUERY:
            dram_re = 1; nst = COMPARE
        elif st == COMPARE:
            if S["pipeline_ready"] and S["dram_valid"] and q != 0:
                nst = WRITE_MATCH if any_eq else UPDATE_POINTERS
            else:
                nst = FETCH_QUERY
        elif st == WRITE_MATCH:
            dram_we = 1; nst = UPDATE_POINTERS
        elif st == UPDATE_POINTERS:
            for j in range(4):
                if eq[j] or less[j]:
                    sh[j] = ld[j] = fre[j] = inc[j] = 1
            if all_gt or any_eq:
                dram_we = 1; dram_wr_addr = S["query_ptr"]; dram_w_data = 0
            nst = FETCH_QUERY

        # ---- always_ff (all sample old values) ----
        N = {k: (list(v) if isinstance(v, list) else v) for k, v in S.items()}
        # dram_module
        if dram_re:
            N["dram_out"] = mem[dram_rd_addr]; N["dram_valid"] = 1
        else:
            N["dram_valid"] = 0
        if dram_we:
            log.append((t, "DRAM write", dram_wr_addr, dram_w_data))
            mem_write = (dram_wr_addr, dram_w_data)
        else:
            mem_write = None
        # nand_flash_sim
        for i in range(4):
            if reversed_ports:   # port index p = 3 - top index (descending vs ascending unpacked ranges)
                p = 3 - i
                if fre[p]:
                    N["flash_out"][i] = flash[p][S["faddr"][i]]
            elif fre[i]:
                N["flash_out"][i] = flash[i][S["faddr"][i]]
        # channel regs
        for i in range(4):
            if sh[i]: N["curr"][i] = S["nxt"][i]
            if ld[i]: N["nxt"][i] = S["flash_out"][i]
            if inc[i]: N["faddr"][i] = (S["faddr"][i] + 1) & 0xFF
        # top sequential
        N["state"] = nst
        if st == INIT_LATCH_CURR: N["pipeline_ready"] = 1
        if st == WRITE_MATCH:
            N["match_ptr"] = (S["match_ptr"] + 1) & 31
            N["match_count"] = (S["match_count"] + 1) & 31
        if st == UPDATE_POINTERS:
            if (all_gt or any_eq) and S["query_ptr"] < 9:
                N["query_ptr"] = S["query_ptr"] + 1
        if mem_write:
            mem[mem_write[0]] = mem_write[1]
        if verbose:
            print(t, NAMES[st], "q=", q, "curr=", S["curr"], "next=", S["nxt"], "qp=", S["query_ptr"])
        S = N
        t += 10
    return mem, S, log


if __name__ == "__main__":
    base = RTL + "/"
    n = check_phase1_preload(base + "phase1_intersection/nand_flash_sim.sv")
    print(f"flash preload parsed: {n} rows match formula 3+4*row+ch")

    datasets = {
        "A (phase1_intersection/dram_module.sv)": [12, 13, 14, 15, 29, 30, 31, 48, 53, 58],
        "B (test_vectors/dram_module_dataset_b.sv)": [23, 28, 33, 46, 65, 768, 770, 772, 774, 777],
    }
    for name, d in datasets.items():
        mem, S, log = run(d)
        print(f"\n=== Dataset {name}")
        print("match_count =", S["match_count"])
        print("DRAM[10..19] =", mem[10:20])
        print("DRAM[0..9]   =", mem[0:10])
        print("final state  =", NAMES[S["state"]], " query_ptr =", S["query_ptr"])
        if name.startswith("A"):
            print("TB check mem[10]==12:", "SUCCESS" if mem[10] == 12 else "FAIL")
            print("TB check mem[11]==13:", "SUCCESS" if mem[11] == 13 else "FAIL")
            print("TB check mem[0]==0  :", "SUCCESS" if mem[0] == 0 else "FAIL")
            print("TB check mem[1]==0  :", "SUCCESS" if mem[1] == 0 else "FAIL")
        expected = sorted(set(d) & {v for row in phase1_flash_rows() for v in row})
        got = [x for x in mem[10:32] if x]
        print("expected intersection =", expected)
        print("ALL MATCHES CORRECT" if got == expected else f"MISMATCH: got {got}")
