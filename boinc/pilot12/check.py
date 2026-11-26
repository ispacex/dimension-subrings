"""check.py RESULT REF_STAT CAND_SHA256 — a run_piece.sh result.txt against a reference run: the stat
counters (JSON, ms_* left out on both sides, key order ignored) and the sha256 of the candidate lines
(the bytes between "# candidates N" and "# dump"). Exit 0 iff both agree (boinc/README.md, "2^12")."""
import hashlib, json, sys

res, ref, want = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(res, encoding="utf-8").read().split("\n")
stat = json.loads(next(l[len("# stat "):] for l in lines if l.startswith("# stat ")))
i = next(k for k, l in enumerate(lines) if l.startswith("# candidates "))
j = next(k for k, l in enumerate(lines) if l.startswith("# dump "))
cand = "".join(l + "\n" for l in lines[i + 1:j])
got = hashlib.sha256(cand.encode()).hexdigest()
strip = lambda d: {k: v for k, v in d.items() if not k.startswith("ms_")}
ok_stat = strip(stat) == strip(json.load(open(ref)))
print(f"candidates {j - i - 1}, sha256 {got} ({'=' if got == want else '!='} reference), stat {'=' if ok_stat else '!='} reference")
if not ok_stat:
    print("result:   ", json.dumps(strip(stat), sort_keys=True))
    print("reference:", json.dumps(strip(json.load(open(ref))), sort_keys=True))
sys.exit(0 if ok_stat and got == want else 1)
