# Council list (PBT)

`lib/domain/councils.dart` is generated from the official list of local authorities kept by
Jabatan Kerajaan Tempatan, KPKT. Do not edit it by hand.

1. Download the data behind <https://jkt.kpkt.gov.my/data-pbt-senarai_pbt/> into a folder of
   its own (it is downloaded data, so keep it apart from these scripts):

   ```
   curl -sSfL -o /path/to/download/pbt.json https://ejkt.kpkt.gov.my/eprofil/api/jkt-portal-senarai-maklumat
   ```

2. Check every website. A website is kept only if it opens and the page names the council.
   `FIX` in `verify.py` maps a KPKT address that no longer opens to the address the council
   uses now, and `MISSING` gives councils that have no address in the KPKT data. Add an entry
   there only after opening the new address and seeing the council's name on it.

   ```
   python -I verify.py /path/to/download/pbt.json
   ```

3. Write the Dart file and review the diff:

   ```
   python -I gen_dart.py verified.json ../../lib/domain/councils.dart
   ```

Kuala Lumpur (DBKL) is under the Federal Territories rather than KPKT, so `verify.py` adds it.
The insurer and takaful list in `lib/domain/lists.dart` comes from the Bank Negara Malaysia
FSP directory (General Insurance Business and General Takaful Business licences).
