"""Prints line coverage per file from an lcov file, lowest first (CI log only, not a gate)."""
import sys

files, cur = {}, None
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.strip()
    if line.startswith('SF:'):
        cur = line[3:]
        files[cur] = [0, 0]
    elif line.startswith('DA:') and cur:
        hits = int(line.split(',')[1])
        files[cur][1] += 1
        files[cur][0] += 1 if hits > 0 else 0
rows = [(f, h, n) for f, (h, n) in files.items() if f.startswith('lib/') and not f.endswith('.g.dart') and n]
rows.sort(key=lambda r: r[1] / r[2])
th, tn = sum(r[1] for r in rows), sum(r[2] for r in rows)
print(f'Line coverage of lib/ (without generated code): {100 * th / tn:.1f}% of {tn} lines')
for f, h, n in rows:
    print(f'{100 * h / n:5.1f}%  {h:4}/{n:<4}  {f}')
