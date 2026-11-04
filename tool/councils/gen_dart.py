# Writes lib/domain/councils.dart from verified.json. Run with: python -I gen_dart.py <verified.json> <out.dart>
import json
import re
import sys

rows = json.load(open(sys.argv[1], encoding='utf-8'))

STATES = ['Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan', 'Pahang', 'Perak', 'Perlis', 'Pulau Pinang',
          'Sabah', 'Sarawak', 'Selangor', 'Terengganu', 'W.P. Kuala Lumpur', 'W.P. Labuan', 'W.P. Putrajaya']


def initials(name):
    words = [w for w in re.split(r'[\s\-&]+', name) if w and w.lower() not in ('dan',)]
    return ''.join(w[0] for w in words).upper()


def abbr(r):
    ini = initials(r['name'])
    short = re.sub(r'\s+', '', r['short']).upper()
    label = re.sub(r'^https?://', '', r['url']).split('/')[0]
    label = label[4:] if label.startswith('www.') else label
    label = label.split('.')[0].upper()
    for c in (short, label):
        if c and c == ini and len(c) >= 3:
            return c
    return ''


def url(r):
    if not r['ok']:
        return None
    u = r['url']
    u = u if u.startswith('http') else 'https://' + u
    # A page inside a site keeps the trailing slash it was checked with.
    return u + '/' if '/' in u.split('://', 1)[1] else u


def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'")


by = {s: [] for s in STATES}
for r in rows:
    if r['state'] not in by:
        raise SystemExit('unknown state ' + r['state'])
    by[r['state']].append(r)

out = []
out.append('// GENERATED from the official list. Do not edit by hand; see tool/councils/README.md.')
out.append('//')
out.append('// Source: Jabatan Kerajaan Tempatan, KPKT (jkt.kpkt.gov.my, "Senarai PBT" and "Senarai Agensi')
out.append('// Diberi Peranan Sebagai PBT"), read 4 Nov 2026. Kuala Lumpur (DBKL) is under the Federal')
out.append('// Territories, not KPKT, and is added from dbkl.gov.my.')
out.append('// A website is kept only if it opened on 4 Nov 2026 and the page names the council. Where the')
out.append('// KPKT address no longer opened, the address the council uses now was found and checked the')
out.append('// same way; councils with no address that could be checked have none.')
out.append('')
out.append("import 'lists.dart';")
out.append('')
out.append('const councilsByState = <String, List<Council>>{')
n = 0
linked = 0
for s in STATES:
    out.append(f"  '{esc(s)}': [")
    for r in sorted(by[s], key=lambda r: r['name']):
        a = abbr(r)
        u = url(r)
        n += 1
        linked += u is not None
        parts = [f"'{esc(r['name'])}'"]
        if a:
            parts.append(f"abbr: '{a}'")
        if u:
            parts.append(f"web: '{esc(u)}'")
        out.append(f"    Council({', '.join(parts)}),")
    out.append('  ],')
out.append('};')
out.append('')
open(sys.argv[2], 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print(f'{n} councils, {linked} with a website')
for s in STATES:
    print(s, len(by[s]))
