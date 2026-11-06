// House insurance and the check before the monsoon (0.3, F5): houseowner and householder
// policies apart, and a yearly monsoon check dated by state.

import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/domain/presets.dart';
import 'package:kukira_asset/l10n/strings.dart';

void main() {
  List<String> keys(String p, {String? state}) => templatesFor('house', p, state: state).map((x) => x.key).toList();

  test('every home is offered contents insurance and a monsoon check, a condo too', () {
    for (final p in ['landed', 'strata', 'strata_landed']) {
      expect(keys(p), containsAll(['householderInsurance', 'monsoonCheck']), reason: p);
    }
    expect(keys('strata'), isNot(contains('houseInsurance')), reason: 'the JMB or MC insures a condo building');
    expect(householderInsurance.category, isNot(houseInsurance.category), reason: 'adding one does not hide the other');
  });

  test('the northeast monsoon states check on 1 October, the others on 15 September', () {
    final today = DateTime(2026, 11, 7);
    for (final st in ['Kelantan', 'Terengganu', 'Pahang', 'Johor', 'Sabah', 'Sarawak']) {
      expect(monsoonCheckFor(st).key, 'monsoonCheckEast', reason: st);
    }
    expect(monsoonCheckFor('kelantan').key, 'monsoonCheckEast', reason: 'as typed');
    for (final st in ['Selangor', 'W.P. Kuala Lumpur', null, '']) {
      expect(monsoonCheckFor(st).key, 'monsoonCheck', reason: '$st');
    }
    expect(monsoonCheckEast.defaultDue!(today), DateTime(2027, 10, 1));
    expect(monsoonCheck.defaultDue!(today), DateTime(2027, 9, 15));
    expect(monsoonCheck.repeatMonths, 12);
    expect(monsoonCheck.repeatFrom, 'due', reason: 'the same time every year');
    expect(keys('landed', state: 'Terengganu'), contains('monsoonCheckEast'));
  });

  test('says what to check and that the date is an estimate, in both languages', () {
    for (final lang in ['ms', 'en']) {
      final s = strFor(lang);
      for (final p in [householderInsurance, monsoonCheck, monsoonCheckEast]) {
        expect(p.title(s), isNot(p.key), reason: '$lang ${p.key}');
        expect(p.hint(s), isNotEmpty, reason: '$lang ${p.key}');
        expect(presetByKey(p.key), isNotNull);
      }
      expect(monsoonCheck.note(s), isNotEmpty);
      expect(monsoonCheck.confirm(s), contains('MetMalaysia'));
      expect(s.catName('contents_insurance'), isNot('contents_insurance'));
      expect(s.catName('monsoon'), isNot('monsoon'));
      expect(houseInsurance.hint(s), contains('MRTA'));
    }
  });
}
