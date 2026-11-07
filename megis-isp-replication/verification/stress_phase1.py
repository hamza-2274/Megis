"""Randomized check of the Phase 1 merge: 3000 random query sets vs. a set-intersection reference."""
import random
from model_phase1 import run, NAMES
from model_common import phase1_flash_rows
ref = {v for row in phase1_flash_rows() for v in row}
random.seed(1)
fails = 0; slow = 0
for trial in range(3000):
    q = sorted(random.sample(range(1, 1023), 10))
    mem, S, _ = run(q, sim_ns_after_start=20000)
    exp = sorted(set(q) & ref)
    got = [x for x in mem[10:32] if x]
    if got != exp:
        fails += 1
        if fails <= 5: print("FAIL", q, "exp", exp, "got", got)
    mem2, S2, _ = run(q)       # testbench time budget (2500 ns)
    if [x for x in mem2[10:32] if x] != exp: slow += 1
print(f"random trials: 3000, wrong results: {fails}, not finished within the 2500 ns testbench window: {slow}")
# edge cases
for q in ([3,4,5,6,7,8,9,10,11,12], [1,2,3,1020,1021,1022,1019,1018,1017,1016], [190,191,192,193,194,195,196,197,198,199]):
    q=sorted(q); mem,S,_=run(q,20000); print("edge", q, "->", [x for x in mem[10:32] if x], "expected", sorted(set(q)&ref))
