// The lists behind fields that can be picked from or typed into (ComboField). Every list is a
// suggestion only: whatever the owner types is kept exactly as typed.

import 'councils.dart';

// ---------------------------------------------------------------- states and councils

/// The 13 states and 3 federal territories, in the order people expect.
const malaysianStates = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Perak',
  'Perlis',
  'Pulau Pinang',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
  'W.P. Kuala Lumpur',
  'W.P. Labuan',
  'W.P. Putrajaya',
];

/// A local authority (PBT). The list is generated from KPKT's; see tool/councils/README.md.
class Council {
  const Council(this.name, {this.abbr, this.web});
  final String name;

  /// The short form people use (MBSA), only where it is the council's own.
  final String? abbr;

  /// The official website, checked to open and to name the council when the list was made.
  final String? web;

  /// What goes in the field: "Majlis Bandaraya Shah Alam (MBSA)".
  String get label => abbr == null ? name : '$name ($abbr)';
}

String _plain(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// The state a typed text means ("selangor", "Kuala Lumpur", "KL"), or null.
String? stateNamed(String? text) {
  final t = _plain(text ?? '');
  if (t.isEmpty) return null;
  for (final s in malaysianStates) {
    final p = _plain(s);
    if (p == t || p.replaceFirst('w p ', '') == t) return s;
  }
  return switch (t) {
    'kl' || 'wp kl' || 'wilayah persekutuan kuala lumpur' => 'W.P. Kuala Lumpur',
    'penang' => 'Pulau Pinang',
    'malacca' => 'Melaka',
    'wilayah persekutuan labuan' => 'W.P. Labuan',
    'wilayah persekutuan putrajaya' => 'W.P. Putrajaya',
    _ => null,
  };
}

/// The councils of a state with the state they belong to, or every council when the state
/// is empty or not recognised.
List<(Council, String)> councilsFor(String? state) {
  final s = stateNamed(state);
  return [
    for (final MapEntry(key: st, value: list) in councilsByState.entries)
      if (s == null || st == s)
        for (final c in list) (c, st),
  ];
}

/// The council a saved text refers to, with its state: its label or name, or its short form.
/// Some short forms belong to more than one council (MPS is Sandakan and Selayang), so a short
/// form counts only when [state] leaves just one. Null when the text is the owner's own, or
/// when it is not clear which council it means.
(Council, String)? councilNamed(String? text, {String? state}) {
  final t = _plain(text ?? '');
  if (t.isEmpty) return null;
  final all = councilsFor(null);
  for (final m in all) {
    if (_plain(m.$1.label) == t || _plain(m.$1.name) == t) return m;
  }
  final st = stateNamed(state);
  final byAbbr = [
    for (final m in all)
      if (m.$1.abbr != null && _plain(m.$1.abbr!) == t && (st == null || m.$2 == st)) m,
  ];
  return byAbbr.length == 1 ? byAbbr.single : null;
}

// ---------------------------------------------------------------- insurers

/// A company licensed by Bank Negara Malaysia for general insurance or general takaful, the
/// licences that cover motor and house policies.
class Insurer {
  const Insurer(this.name, this.licensedName);

  /// The name people use, which goes in the field.
  final String name;

  /// The name on the BNM licence.
  final String licensedName;
}

/// From the BNM Financial Sector Participants directory, read 4 Nov 2026: every company with
/// a General Insurance Business or General Takaful Business licence. Life and family takaful
/// companies and reinsurers are left out.
const insurers = [
  Insurer('AIA General', 'AIA General Berhad'),
  Insurer('AIG', 'AIG Malaysia Insurance Berhad'),
  Insurer('Allianz', 'Allianz General Insurance Company (Malaysia) Berhad'),
  Insurer('Berjaya Sompo', 'Berjaya Sompo Insurance Berhad'),
  Insurer('Chubb', 'Chubb Insurance Malaysia Berhad'),
  Insurer('Etiqa General Insurance', 'Etiqa General Insurance Berhad'),
  Insurer('Etiqa General Takaful', 'Etiqa General Takaful Berhad'),
  Insurer('Generali', 'Generali Insurance Malaysia Berhad'),
  Insurer('Great Eastern General', 'Great Eastern General Insurance (Malaysia) Berhad'),
  Insurer('Liberty', 'Liberty General Insurance Berhad'),
  Insurer('Lonpac', 'Lonpac Insurance Berhad'),
  Insurer('MSIG', 'MSIG Insurance (Malaysia) Bhd'),
  Insurer('Pacific & Orient', 'Pacific & Orient Insurance Co. Berhad'),
  Insurer('Pacific Insurance', 'Pacific Insurance Berhad'),
  Insurer('Progressive', 'Progressive Insurance Berhad'),
  Insurer('QBE', 'QBE Insurance (Malaysia) Berhad'),
  Insurer('RHB Insurance', 'RHB Insurance Berhad'),
  Insurer('Takaful Ikhlas', 'Takaful Ikhlas General Berhad'),
  Insurer('Takaful Malaysia', 'Syarikat Takaful Malaysia Am Berhad'),
  Insurer('Tokio Marine', 'Tokio Marine Insurance (Malaysia) Berhad'),
  Insurer('Tune Protect', 'Tune Insurance Malaysia Berhad'),
  Insurer('Zurich General Insurance', 'Zurich General Insurance Malaysia Berhad'),
  Insurer('Zurich General Takaful', 'Zurich General Takaful Malaysia Berhad'),
];

// ---------------------------------------------------------------- makes and models

/// Makes and models commonly on Malaysian roads, current and older. Not complete, and does
/// not need to be: any other make or model can be typed.
const carModels = <String, List<String>>{
  'Perodua': ['Alza', 'Aruz', 'Ativa', 'Axia', 'Bezza', 'Kancil', 'Kelisa', 'Kembara', 'Kenari', 'Myvi', 'Rusa', 'Viva'],
  'Proton': [
    'e.MAS 7', 'Ertiga', 'Exora', 'Gen-2', 'Inspira', 'Iriz', 'Iswara', 'Perdana', 'Persona', 'Preve', 'Saga', 'Satria',
    'Satria Neo', 'Savvy', 'S70', 'Suprima S', 'Waja', 'Wira', 'X50', 'X70', 'X90',
  ],
  'Toyota': [
    'Alphard', 'Avanza', 'Camry', 'C-HR', 'Corolla Altis', 'Corolla Cross', 'Estima', 'Fortuner', 'Harrier', 'Hiace',
    'Hilux', 'Innova', 'Prius', 'Rush', 'Vellfire', 'Veloz', 'Vios', 'Wish', 'Yaris', 'Yaris Cross',
  ],
  'Honda': ['Accord', 'BR-V', 'City', 'City Hatchback', 'Civic', 'CR-V', 'HR-V', 'Jazz', 'Odyssey', 'Stream', 'WR-V'],
  'Nissan': ['Almera', 'Grand Livina', 'Kicks', 'Latio', 'Leaf', 'Livina', 'Navara', 'Note', 'Serena', 'Sylphy', 'Teana', 'Urvan', 'X-Trail'],
  'Mazda': ['BT-50', 'CX-3', 'CX-30', 'CX-5', 'CX-8', 'CX-60', 'Mazda2', 'Mazda3', 'Mazda6', 'MX-5'],
  'Mitsubishi': ['ASX', 'Attrage', 'Lancer', 'Mirage', 'Outlander', 'Pajero Sport', 'Triton', 'Xpander'],
  'Hyundai': ['Elantra', 'Ioniq 5', 'Ioniq 6', 'Kona', 'Santa Fe', 'Sonata', 'Starex', 'Staria', 'Tucson'],
  'Kia': ['Carnival', 'Cerato', 'EV6', 'EV9', 'Niro', 'Picanto', 'Seltos', 'Sorento', 'Sportage'],
  'Suzuki': ['Ertiga', 'Jimny', 'Swift', 'Vitara'],
  'Isuzu': ['D-Max', 'MU-X'],
  'Ford': ['Everest', 'Fiesta', 'Focus', 'Ranger'],
  'Subaru': ['Crosstrek', 'Forester', 'Impreza', 'Outback', 'WRX', 'XV'],
  'Volkswagen': ['Arteon', 'Golf', 'Jetta', 'Passat', 'Polo', 'Tiguan', 'Vento'],
  'BMW': ['1 Series', '2 Series', '3 Series', '5 Series', '7 Series', 'i4', 'iX', 'iX1', 'iX3', 'X1', 'X3', 'X5', 'X7'],
  'Mercedes-Benz': ['A-Class', 'C-Class', 'E-Class', 'S-Class', 'EQA', 'EQB', 'EQE', 'EQS', 'GLA', 'GLB', 'GLC', 'GLE'],
  'Audi': ['A3', 'A4', 'A6', 'Q3', 'Q5', 'Q7', 'Q8 e-tron'],
  'Lexus': ['ES', 'IS', 'LM', 'NX', 'RX', 'UX'],
  'Volvo': ['C40', 'EX30', 'S60', 'S90', 'XC40', 'XC60', 'XC90'],
  'Peugeot': ['208', '308', '408', '2008', '3008', '5008'],
  'BYD': ['Atto 3', 'Dolphin', 'M6', 'Seal', 'Sealion 7'],
  'Chery': ['Omoda 5', 'Tiggo 4 Pro', 'Tiggo 7 Pro', 'Tiggo 8 Pro'],
  'Haval': ['H6', 'Jolion'],
  'Tesla': ['Model 3', 'Model Y'],
  'Mini': ['Cooper', 'Countryman'],
  'Land Rover': ['Defender', 'Discovery', 'Range Rover'],
  'Porsche': ['911', 'Cayenne', 'Macan', 'Taycan'],
};

const motorcycleModels = <String, List<String>>{
  'Honda': [
    'ADV 160', 'Beat', 'CB150R', 'CBR150R', 'CBR250RR', 'Dash 125', 'EX5', 'PCX 160', 'RS-X', 'RS150R', 'Scoopy', 'Vario 125',
    'Vario 160', 'Wave 125', 'Wave Alpha',
  ],
  'Yamaha': [
    '125ZR', 'Ego Avantiz', 'Ego Solariz', 'FZ150', 'Lagenda 115Z', 'LC135', 'MT-15', 'MT-25', 'NMAX', 'NVX 155', 'R15', 'R25',
    'RXZ', 'XMAX', 'Y15ZR', 'Y16ZR',
  ],
  'Modenas': ['CT115S', 'Dinamik 120', 'Elegan 250', 'Kriss 110', 'Kriss MR3', 'Pulsar NS200'],
  'Suzuki': ['Address', 'Belang R150', 'Burgman 200', 'GSX-R150', 'GSX-S150', 'Raider R150', 'Smash'],
  'SYM': ['E-Bonus', 'Husky 150', 'Jet 14', 'Sport Bonus', 'VF3i'],
  'Kawasaki': ['Ninja 250', 'Ninja 400', 'Ninja ZX-25R', 'Versys 650', 'Z250', 'Z400'],
  'Benelli': ['Leoncino 250', 'RFS150i', 'TNT 135', 'TRK 251'],
  'KTM': ['Duke 200', 'Duke 390', 'RC 390'],
  'Vespa': ['GTS', 'Primavera', 'Sprint'],
  'BMW Motorrad': ['G 310 GS', 'G 310 R', 'R 1250 GS'],
  'Ducati': ['Monster', 'Panigale V2', 'Scrambler'],
};

Map<String, List<String>> _modelsOf(String category) => category == 'motorcycle' ? motorcycleModels : carModels;

List<String> makesFor(String category) => _modelsOf(category).keys.toList();

/// The models of a make, matched however it was typed ("perodua"), or none.
List<String> modelsFor(String category, String? make) {
  final m = _plain(make ?? '');
  if (m.isEmpty) return const [];
  for (final MapEntry(key: k, value: v) in _modelsOf(category).entries) {
    if (_plain(k) == m) return v;
  }
  return const [];
}

/// Model years, newest first.
List<String> yearOptions(DateTime now) => [for (var y = now.year + 1; y >= 1970; y--) '$y'];
