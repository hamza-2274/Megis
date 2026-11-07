"""Cycle-accurate model of rtl/phase2_taxid (megis_top.sv + submodules + tb_megis.sv)."""
import os
from model_common import RTL, parse_preload
SV = os.path.join(RTL, 'phase2_taxid', 'nand_flash_sim.sv')

W42 = (1 << 42) - 1
(IDLE, P1_INIT_FETCH, P1_INIT_LATCH_NEXT, P1_INIT_LATCH_CURR, P1_FETCH_QUERY, P1_COMPARE, P1_WRITE_MATCH,
 P1_UPDATE_POINTERS, TRANSITION_TO_P2, P2_INIT_FETCH, P2_INIT_LATCH_NEXT, P2_INIT_LATCH_CURR, P2_FETCH_QUERY,
 P2_COMPARE, P2_WRITE_MATCH, P2_UPDATE_POINTERS, DONE) = range(17)
NAMES = ("IDLE P1_INIT_FETCH P1_INIT_LATCH_NEXT P1_INIT_LATCH_CURR P1_FETCH_QUERY P1_COMPARE P1_WRITE_MATCH "
         "P1_UPDATE_POINTERS TRANSITION_TO_P2 P2_INIT_FETCH P2_INIT_LATCH_NEXT P2_INIT_LATCH_CURR P2_FETCH_QUERY "
         "P2_COMPARE P2_WRITE_MATCH P2_UPDATE_POINTERS DONE").split()

P2_CH0 = [(100, 20), (101, 23), (102, 26), (103, 28), (104, 31), (105, 33), (106, 40), (107, 46), (108, 60), (109, 65)]
P2_CH1 = [4005, 4006, 4007, 4008, 4010, 4011, 4015, 4016]


def run(sim_ns_after_start=3000, trace=False):
    flash = [[W42] * 256 for _ in range(4)]
    for r, row in enumerate(parse_preload(SV)):
        for c in range(4):
            flash[c][r] = row[c]                       # {32'd0, kmer}
    for r, (tax, k) in enumerate(P2_CH0):
        flash[0][64 + r] = (tax << 10) | k            # {TaxID, 5-mer}
    for r, tax in enumerate(P2_CH1):
        flash[1][64 + r] = tax                        # {10'd0, 4-mer TaxID}

    mem = [23, 28, 33, 46, 65, 768, 770, 772, 774, 777] + [0] * 22
    host = [0] * 32
    S = dict(state=IDLE, query_ptr=0, match_ptr=10, p2_query_ptr=10, p2_match_ptr=0,
             pipeline_ready=0, match_count=0, dram_out=0, dram_valid=0,
             flash_out=[0] * 4, curr=[0] * 4, nxt=[0] * 4, faddr=[0] * 4)
    events, done_t, p1_end_t = [], None, None
    t, end_t = 5, 40 + sim_ns_after_start
    while t < end_t:
        start = 1 if 30 <= t < 40 else 0
        if t < 20:
            t += 10; continue
        st = S["state"]; q = S["dram_out"]
        k = [S["curr"][i] & 0x3FF for i in range(4)]
        less = [int(k[i] < q) for i in range(4)]
        eq = [int(k[i] == q) for i in range(4)]
        gt = [int(k[i] > q) for i in range(4)]
        any_eq, all_gt = any(eq), all(gt)
        prefix_change = ((S["curr"][0] & 0x3FF) >> 2) != ((S["nxt"][0] & 0x3FF) >> 2)
        valid_chk = S["pipeline_ready"] and S["dram_valid"] and q != 0

        nst = st
        dram_re = dram_we = 0
        dram_wr_addr, dram_w_data, dram_rd_addr = S["match_ptr"], q, S["query_ptr"]
        host_we, host_wr_addr, host_w_data = 0, S["p2_match_ptr"], 0
        fre, sh, ld, inc = [0] * 4, [0] * 4, [0] * 4, [0] * 4
        reset_p2 = 0
        if st == IDLE:
            if start: nst = P1_INIT_FETCH
        elif st == P1_INIT_FETCH:
            fre = [1] * 4; inc = [1] * 4; nst = P1_INIT_LATCH_NEXT
        elif st == P1_INIT_LATCH_NEXT:
            fre = [1] * 4; ld = [1] * 4; inc = [1] * 4; nst = P1_INIT_LATCH_CURR
        elif st == P1_INIT_LATCH_CURR:
            sh = [1] * 4; ld = [1] * 4; fre = [1] * 4; inc = [1] * 4; nst = P1_FETCH_QUERY
        elif st == P1_FETCH_QUERY:
            dram_re = 1; nst = P1_COMPARE
        elif st == P1_COMPARE:
            nst = (P1_WRITE_MATCH if any_eq else P1_UPDATE_POINTERS) if valid_chk else P1_FETCH_QUERY
        elif st == P1_WRITE_MATCH:
            dram_we = 1; nst = P1_UPDATE_POINTERS
        elif st == P1_UPDATE_POINTERS:
            for j in range(4):
                if eq[j] or less[j]: sh[j] = ld[j] = fre[j] = inc[j] = 1
            if all_gt or any_eq:
                dram_we = 1; dram_wr_addr = S["query_ptr"]; dram_w_data = 0
                nst = TRANSITION_TO_P2 if S["query_ptr"] == 9 else P1_FETCH_QUERY
            else:
                nst = P1_FETCH_QUERY
        elif st == TRANSITION_TO_P2:
            reset_p2 = 1; nst = P2_INIT_FETCH
        elif st == P2_INIT_FETCH:
            fre[0] = fre[1] = inc[0] = inc[1] = 1; nst = P2_INIT_LATCH_NEXT
        elif st == P2_INIT_LATCH_NEXT:
            for j in (0, 1): fre[j] = ld[j] = inc[j] = 1
            nst = P2_INIT_LATCH_CURR
        elif st == P2_INIT_LATCH_CURR:
            for j in (0, 1): sh[j] = ld[j] = fre[j] = inc[j] = 1
            nst = P2_FETCH_QUERY
        elif st == P2_FETCH_QUERY:
            dram_rd_addr = S["p2_query_ptr"]; dram_re = 1; nst = P2_COMPARE
        elif st == P2_COMPARE:
            nst = (P2_WRITE_MATCH if eq[0] else P2_UPDATE_POINTERS) if valid_chk else P2_FETCH_QUERY
        elif st == P2_WRITE_MATCH:
            host_we = 1
            host_w_data = ((S["curr"][0] >> 10) << 32) | (S["curr"][1] & 0xFFFFFFFF)
            nst = P2_UPDATE_POINTERS
        elif st == P2_UPDATE_POINTERS:
            if eq[0] or less[0]:
                sh[0] = ld[0] = fre[0] = inc[0] = 1
                if prefix_change: sh[1] = ld[1] = fre[1] = inc[1] = 1
            if eq[0] or gt[0]:
                nst = DONE if S["p2_query_ptr"] == ((S["match_ptr"] - 1) & 31) else P2_FETCH_QUERY
            else:
                nst = P2_FETCH_QUERY

        N = {kk: (list(v) if isinstance(v, list) else v) for kk, v in S.items()}
        if dram_re:
            N["dram_out"] = mem[dram_rd_addr]; N["dram_valid"] = 1
        else:
            N["dram_valid"] = 0
        for i in range(4):
            if fre[i]: N["flash_out"][i] = flash[i][S["faddr"][i]]
            if sh[i]: N["curr"][i] = S["nxt"][i]
            if ld[i]: N["nxt"][i] = S["flash_out"][i]
            if inc[i]: N["faddr"][i] = (S["faddr"][i] + 1) & 0xFF
            if reset_p2 and i in (0, 1): N["faddr"][i] = 64
        N["state"] = nst
        if st in (P1_INIT_LATCH_CURR, P2_INIT_LATCH_CURR): N["pipeline_ready"] = 1
        if st == TRANSITION_TO_P2: N["pipeline_ready"] = 0
        if st == P1_WRITE_MATCH:
            N["match_ptr"] = (S["match_ptr"] + 1) & 31; N["match_count"] = (S["match_count"] + 1) & 31
        if st == P1_UPDATE_POINTERS and (all_gt or any_eq) and S["query_ptr"] < 10:
            N["query_ptr"] = S["query_ptr"] + 1
        if st == TRANSITION_TO_P2:
            N["p2_query_ptr"] = 10; N["p2_match_ptr"] = 0; p1_end_t = t
        if st == P2_WRITE_MATCH: N["p2_match_ptr"] = (S["p2_match_ptr"] + 1) & 31
        if st == P2_UPDATE_POINTERS and (eq[0] or gt[0]): N["p2_query_ptr"] = (S["p2_query_ptr"] + 1) & 31
        if dram_we: mem[dram_wr_addr] = dram_w_data & 0x3FF
        if host_we:
            host[host_wr_addr] = host_w_data
            events.append((t, host_wr_addr, host_w_data >> 32, host_w_data & 0xFFFFFFFF))
        if nst == DONE and done_t is None: done_t = t
        if trace and st >= TRANSITION_TO_P2 and st != DONE:
            print(f"{t:5d} {NAMES[st]:20s} q={q:4d} ch0=({S['curr'][0]>>10},{S['curr'][0]&0x3FF}) "
                  f"next0_k={S['nxt'][0]&0x3FF} ch1={S['curr'][1]&0xFFFFFFFF} pc={int(prefix_change)} p2q={S['p2_query_ptr']}")
        S = N; t += 10
    return mem, host, S, events, p1_end_t, done_t


if __name__ == "__main__":
    import sys
    base = os.path.join(RTL, "phase2_taxid") + "/"
    mem, host, S, events, p1t, dt = run(trace="-t" in sys.argv)
    print("Phase 1 finished at", p1t, "ns; DONE reached at", dt, "ns (testbench checks at 3040 ns)")
    print("match_count =", S["match_count"], " DRAM[10..14] =", mem[10:15], " final state =", NAMES[S["state"]])
    for i, v in enumerate([23, 28, 33, 46, 65]):
        print(f"TB DRAM[{10+i}]=={v}:", "SUCCESS" if mem[10 + i] == v else "FAIL")
    exp = [(101, 4005), (103, 4007), (105, 4008), (107, 4011), (109, 4016)]
    for i, (a, b) in enumerate(exp):
        got = (host[i] >> 32, host[i] & 0xFFFFFFFF)
        print(f"TB HOST[{i}]=={{{a},{b}}}:", "SUCCESS" if got == (a, b) else f"FAIL got {got}")
    print("host writes:", events)
