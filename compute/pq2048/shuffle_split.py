"""shuffle_split.py SEED CHUNK INFILE PREFIX — stage C's input shuffled and split (run_rank.sh CSEED).

The vertex lines of INFILE are ordered by sha256("SEED\\n" + line), which is the same on every
machine and Python version, then written CHUNK per file as PREFIX0000, PREFIX0001, ... (at least
four digits, more when there are more pieces).  The dump lists the children of one vertex
together, and neighbours cost about the same, so split in order a few pieces take most of the
time; shuffled, every piece is a sample of the whole.  Prints the manifest as JSON: the seed,
the chunk, the sha256 of INFILE, and for each piece its name, number of lines and sha256.
"""
import hashlib
import json
import os
import sys

seed, chunk, infile, prefix = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
data = open(infile, "rb").read()
lines = [l for l in data.split(b"\n") if l.strip()]
lines.sort(key=lambda l: hashlib.sha256(seed.encode() + b"\n" + l).digest())
n = (len(lines) + chunk - 1) // chunk
width = max(4, len(str(n - 1)))
pieces = []
for i in range(n):
    body = b"".join(l + b"\n" for l in lines[i * chunk:(i + 1) * chunk])
    name = os.path.basename(prefix) + str(i).zfill(width)
    with open(prefix + str(i).zfill(width), "wb") as f:
        f.write(body)
    pieces.append({"name": name, "lines": body.count(b"\n"), "sha256": hashlib.sha256(body).hexdigest()})
json.dump({"seed": seed, "chunk": chunk, "lines": len(lines),
           "input_sha256": hashlib.sha256(data).hexdigest(), "pieces": pieces}, sys.stdout)
print()
