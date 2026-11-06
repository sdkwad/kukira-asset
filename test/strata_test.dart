// Strata (0.3, F6): the yearly general meeting of the JMB or MC, offered to strata homes only,
// and the sinking fund named in the maintenance charge.

import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/domain/presets.dart';
import 'package:kukira_asset/l10n/strings.dart';

void main() {
  List<String> keys(String p) => templatesFor('house', p).map((x) => x.key).toList();

  test('the AGM is offered to strata homes, not to a landed house', () {
    expect(keys('strata'), contains('agm'));
    expect(keys('strata_landed'), contains('agm'));
    expect(keys('landed'), isNot(contains('agm')));
    expect(agm.repeatMonths, 12);
    expect(presetByKey('agm'), agm);
  });

  test('the maintenance charge names the sinking fund, to confirm with the JMB or MC', () {
    for (final lang in ['ms', 'en']) {
      final s = strFor(lang);
      expect(maintenanceCharge.hint(s), contains('10%'));
      expect(agm.title(s), isNot('agm'));
      expect(agm.hint(s), isNotEmpty);
    }
  });
}
