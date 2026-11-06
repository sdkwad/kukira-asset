// A room-by-room check of a house (0.3, F4): at vacant possession, or before the defects
// liability period ends. Pure Dart: which rooms and things to check, and the report sent to
// the developer.

/// The rooms of a house with [bedrooms] and [bathrooms]: a condo has a balcony, a landed
/// house its outside (porch, gate, roof).
List<String> inspectionRooms({required int bedrooms, required int bathrooms, required String? propertyType}) => [
      'living',
      'kitchen',
      for (var i = 1; i <= bedrooms; i++) 'bed$i',
      for (var i = 1; i <= bathrooms; i++) 'bath$i',
      if (propertyType == 'strata') 'balcony' else 'outside',
    ];

/// What to check in [room].
List<String> roomItems(String room) {
  if (room.startsWith('bath')) return const ['ceiling', 'walls', 'floor', 'door', 'window', 'sink', 'toilet', 'shower', 'paint'];
  return switch (room) {
    'kitchen' => const ['ceiling', 'walls', 'floor', 'door', 'window', 'sink', 'switches', 'paint'],
    'balcony' => const ['floor', 'walls', 'railing', 'drain', 'door'],
    'outside' => const ['gate', 'porch', 'roof', 'drain', 'walls', 'paint'],
    _ => const ['ceiling', 'walls', 'floor', 'door', 'window', 'switches', 'paint'],
  };
}

/// The defect category (Records.category) a defect in [item] is filed under.
String defectCategory(String item) => switch (item) {
      'walls' => 'wall_crack',
      'floor' || 'porch' => 'floor_tiles',
      'door' || 'window' || 'gate' || 'railing' => 'door_window',
      'sink' || 'toilet' || 'shower' || 'drain' => 'plumbing',
      'switches' => 'electrical',
      'roof' || 'ceiling' => 'roof',
      _ => 'other',
    };

/// Room [key] for the room name: bed2 is ('bed', 2).
(String, int?) roomParts(String key) {
  final m = RegExp(r'^([a-z]+)(\d+)$').firstMatch(key);
  return m == null ? (key, null) : (m.group(1)!, int.parse(m.group(2)!));
}

class InspectionProgress {
  const InspectionProgress(this.checked, this.total, this.defects);
  final int checked;
  final int total;
  final int defects;
  bool get finished => total > 0 && checked >= total;
}

/// How far a check has gone: [results] maps "room|item" to ok, defect or na.
InspectionProgress progressOf(List<String> rooms, Map<String, String> results) {
  var total = 0;
  var checked = 0;
  var defects = 0;
  for (final r in rooms) {
    for (final i in roomItems(r)) {
      total++;
      final v = results['$r|$i'];
      if (v != null) checked++;
      if (v == 'defect') defects++;
    }
  }
  return InspectionProgress(checked, total, defects);
}

/// One defect in the report.
class ReportedDefect {
  const ReportedDefect({required this.title, required this.area, this.notes});
  final String title;
  final String? area;
  final String? notes;
}

/// The report sent to the developer: numbered, grouped by area in the order first seen.
String defectReport({
  required String heading,
  required String? address,
  required String dateLine,
  required List<ReportedDefect> defects,
  required String otherArea,
  required String footer,
}) {
  final b = StringBuffer(heading);
  if (address != null && address.trim().isNotEmpty) b.write('\n${address.trim()}');
  b.write('\n$dateLine\n');
  final areas = <String, List<ReportedDefect>>{};
  for (final d in defects) {
    (areas[(d.area == null || d.area!.trim().isEmpty) ? otherArea : d.area!.trim()] ??= []).add(d);
  }
  var n = 0;
  for (final e in areas.entries) {
    b.write('\n${e.key}\n');
    for (final d in e.value) {
      n++;
      b.write('$n. ${d.title}');
      if (d.notes != null && d.notes!.trim().isNotEmpty) b.write(' (${d.notes!.trim()})');
      b.write('\n');
    }
  }
  b.write('\n$footer');
  return b.toString();
}
