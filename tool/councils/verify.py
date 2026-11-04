# Builds the council list from the KPKT data, applies address corrections, and checks that
# each website loads and names the council. Run with: python -I verify.py <pbt.json>
# Writes verified.json in the current folder; gen_dart.py turns that into lib/domain/councils.dart.
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

src = json.load(open(sys.argv[1], encoding='utf-8'))

# KPKT address -> the address the council uses now (found by trying the council's own name).
FIX = {
    'mps.sabah.gov.my/portal/': 'mps.sabah.gov.my',
    'www.mpt.sabah.gov.my': 'mpt.sabah.gov.my',
    'www.mdrompin.gov.my': 'mdrompin.gov.my',
    'www.mpkangar.gov.my': 'www.mpperlis.gov.my',
    # These two answer only over plain HTTP.
    'www.mdtampin.gov.my': 'http://www.mdtampin.gov.my',
    'www.mppengerang.gov.my': 'http://www.mppengerang.gov.my',
    'www.mpkbbri.gov.my': 'mpkbbri.kelantan.gov.my',
    'mdtumpat.gov.my': 'mdtumpat.kelantan.gov.my',
    'www.dbku.gov.my': 'dbku.sarawak.gov.my',
    'www.lawasdc.gov.my/': 'lawasdc.sarawak.gov.my',
    'www.maradong-julaudc.sarawak.gov.': 'maradong-julaudc.sarawak.gov.my',
    'www.samarahandc.sarawak.gov.my/': 'mpks.sarawak.gov.my',
    'www.sabah.gov.my/mpbeluran/': 'mdbeluran.sabah.gov.my',
    'www.sabah.gov.my/md.kgu': 'mdkeningau.sabah.gov.my',
    'www.sabah.gov.my/md.kinabatangan': 'mdkinabatangan.sabah.gov.my',
    'www.sabah.gov.my/md.kbd/': 'mdkotabelud.sabah.gov.my',
    'www.sabah.gov.my/md.kmu/': 'mdkotamarudu.sabah.gov.my',
    'www.sabah.gov.my/pd.ld': 'mdlahaddatu.sabah.gov.my',
    'www.sabah.gov.my/md.ppg': 'mppenampang.sabah.gov.my',
    'www.sabah.gov.my/pd.sprn': 'mdsemporna.sabah.gov.my',
    'www.sabah.gov.my/md.tbn': 'mdtambunan.sabah.gov.my',
    'www.sabah.gov.my/md.tnm': 'mdtenom.sabah.gov.my',
}
for h in ['baudc', 'betongdc', 'kanowitdc', 'kapitdc', 'limbangdc', 'lubokantudc', 'lundudc', 'marudidc', 'matu-darodc',
          'mukah-dalatdc', 'mdsubis', 'saratokdc', 'sarikeidc', 'simunjandc', 'sriamandc']:
    FIX[f'www.{h}.sarawak.gov.my/'] = f'{h}.sarawak.gov.my'
    FIX[f'www.{h}.sarawak.gov.my'] = f'{h}.sarawak.gov.my'
# No address in the KPKT data; found under the council's own name.
MISSING = {
    'Majlis Daerah Beaufort': 'mdbeaufort.sabah.gov.my',
    'Majlis Daerah Kuala Penyu': 'mdkualapenyu.sabah.gov.my',
    'Majlis Daerah Kunak': 'mdkunak.sabah.gov.my',
    'Majlis Daerah Pitas': 'mdpitas.sabah.gov.my',
    'Majlis Daerah Serian': 'seriandc.sarawak.gov.my',
}

STATE = {
    'Kedah Darul Aman': 'Kedah', 'Pahang Darul Makmur': 'Pahang',
    'Wilayah Persekutuan Labuan': 'W.P. Labuan', 'Wilayah Persekutuan Putrajaya': 'W.P. Putrajaya',
}

rows = []
for st, v in src['senarai_pbts'].items():
    for p in v['pbts']:
        rows.append({'state': st, 'name': p['name'].strip(), 'short': (p['name_short'] or '').strip(), 'kpkt': (p['web_url'] or '').strip(), 'from': 'KPKT senarai PBT'})
for a in src['senarai_agensi']:
    rows.append({'state': STATE[a['pbt_name']], 'name': a['pbt_profil_name'].strip(), 'short': '', 'kpkt': (a['website'] or '').strip(), 'from': 'KPKT agensi diberi peranan PBT'})
# Kuala Lumpur is run by DBKL under the Federal Territories, so it is not in the KPKT list.
rows.append({'state': 'W.P. Kuala Lumpur', 'name': 'Dewan Bandaraya Kuala Lumpur', 'short': 'DBKL', 'kpkt': '', 'url': 'www.dbkl.gov.my', 'from': 'DBKL (Wilayah Persekutuan)'})

for r in rows:
    if 'url' in r:
        continue
    u = re.sub(r'^https?://', '', r['kpkt'])
    u = FIX.get(u, u)
    if not u:
        u = MISSING.get(r['name'], '')
    r['url'] = u.rstrip('/')

GENERIC = r'^(majlis (bandaraya|perbandaran|daerah)( diraja)?|dewan bandaraya|lembaga (bandaran|kemajuan|pembangunan)|perbadanan|pbt)\s+'


def place(name):
    n = name.lower()
    n = re.sub(GENERIC, '', n)
    n = re.split(r' - | bandar (raya|pelancongan|diraja)| perbandaran islam| bersejarah| \(', n)[0]
    return n.strip()


def check(r):
    if not r['url']:
        return r | {'ok': False, 'why': 'tiada alamat'}
    try:
        out = subprocess.run(
            ['curl', '-s', '-L', '--max-time', '25', '-A', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120 Safari/537.36',
             '-w', '\n__CODE__%{http_code} %{url_effective}', (r['url'] if r['url'].startswith('http') else 'https://' + r['url']) + '/'],
            capture_output=True, timeout=40)
        body = out.stdout.decode('utf-8', 'replace')
    except Exception as e:  # noqa
        return r | {'ok': False, 'why': f'error {e}'}
    code, eff = (body.rsplit('__CODE__', 1)[-1].split(' ', 1) + [''])[:2]
    text = re.sub(r'\s+', ' ', body.rsplit('__CODE__', 1)[0]).lower()
    words = [w for w in re.split(r'[ &]+', place(r['name'])) if len(w) > 2]
    named = all(w in text for w in words) if words else False
    short = r['short'].lower()
    if not named and short and len(short) >= 3 and short in text:
        named = True
    ok = code.startswith('2') and named
    return r | {'ok': ok, 'code': code, 'final': eff.strip(), 'named': named, 'why': '' if ok else f'code {code} named={named} words={words}'}


with ThreadPoolExecutor(16) as ex:
    res = list(ex.map(check, rows))
json.dump(res, open('verified.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
good = sum(r['ok'] for r in res)
print(f'{len(res)} councils, {good} verified')
for r in res:
    if not r['ok']:
        print('NOT VERIFIED', r['state'], '|', r['name'], '|', r['url'], '|', r['why'])
