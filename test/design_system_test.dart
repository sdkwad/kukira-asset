// The 0.2.7 design tokens and the shared row and status components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukira_asset/domain/rules.dart';
import 'package:kukira_asset/l10n/strings.dart';
import 'package:kukira_asset/ui/app.dart';
import 'package:kukira_asset/ui/common.dart';

import 'helpers.dart';

double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  group('tokens', () {
    test('both themes carry the design tokens', () {
      expect(buildTheme(Brightness.light).extension<KukiraColors>(), KukiraColors.light);
      expect(buildTheme(Brightness.dark).extension<KukiraColors>(), KukiraColors.dark);
      expect(buildTheme(Brightness.light).colorScheme.primary, const Color(0xFF1E6A4E));
      expect(buildTheme(Brightness.light).scaffoldBackgroundColor, const Color(0xFFF6F7F5));
    });

    test('the Tambah button label keeps the theme font', () {
      // A label style without a font family drew the label in the fallback font.
      for (final b in Brightness.values) {
        final t = buildTheme(b);
        expect(t.floatingActionButtonTheme.extendedTextStyle?.fontFamily, isNotNull);
        expect(t.floatingActionButtonTheme.extendedTextStyle?.fontFamily, t.textTheme.labelLarge?.fontFamily);
      }
    });

    for (final (name, k) in [('light', KukiraColors.light), ('dark', KukiraColors.dark)]) {
      test('every text colour in $name mode has at least 4.5:1 contrast', () {
        final pairs = {
          'text on surface': (k.text, k.surface),
          'text on background': (k.text, k.background),
          'muted on surface': (k.textMuted, k.surface),
          'muted on background': (k.textMuted, k.background),
          'label on background': (k.label, k.background),
          'icon on its tile': (k.iconFg, k.iconBg),
          'primary on surface': (k.primary, k.surface),
          'on primary': (k.onPrimary, k.primary),
          'on tonal': (k.onTonal, k.tonal),
          'overdue on surface': (k.overdue, k.surface),
          'overdue on its tint': (k.overdue, k.overdueBg),
          'due soon on surface': (k.dueSoon, k.surface),
          'due soon on its tint': (k.dueSoon, k.dueSoonBg),
          'done on surface': (k.done, k.surface),
          'expired on surface': (k.expired, k.surface),
        };
        for (final MapEntry(key: what, value: (fg, bg)) in pairs.entries) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$name: $what is ${contrast(fg, bg).toStringAsFixed(2)}:1');
        }
      });
    }
  });

  group('components', () {
    final s = strFor('ms');

    testWidgets('a status always has a word and an icon, not colour alone', (tester) async {
      await tester.pumpWidget(harness(Scaffold(body: SizedBox(width: 300, child: StatusLabel.of(RStatus.overdue))), fakeWorld(), lang: 'ms'));
      expect(find.text(s.statusLabel(RStatus.overdue)), findsOneWidget);
      expect(find.descendant(of: find.byType(StatusLabel), matching: find.byType(Icon)), findsOneWidget);
    });

    testWidgets('a row with a long title and status fits a 360 dp phone at 130% text', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(harness(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: Scaffold(
            body: ListView(children: [
              CardList([
                AppRow(
                  leading: const AssetAvatar('house', size: 36),
                  title: 'Servis penghawa dingin bilik tidur utama dan ruang tamu',
                  metaTag: const EstTag(margin: EdgeInsets.zero),
                  status: StatusLabel(s.defectStatusName('in_progress'), Tone.upcoming),
                  meta: 'Rumah Setia Alam · Lewat 2 hari · tarikh 1 Nov · setiap 6 bulan',
                  action: FilledButton.tonal(onPressed: () {}, child: const Text('Perbaharui')),
                  onTap: () {},
                ),
              ]),
            ]),
          ),
        ),
        fakeWorld(),
        lang: 'ms',
      ));
      await tester.pumpAndSettle();
      // A RenderFlex overflow would be reported here.
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(AppRow));
      expect(row.width, lessThanOrEqualTo(phoneWidth));
    });

    testWidgets('fixed tabs share the width, and scroll instead of cutting labels at 130%', (tester) async {
      // Widget tests draw every letter 1 em wide, wider than Roboto, so the width is chosen
      // for that font: the longest label (10 letters at 14 px) fits a quarter of 720 px at
      // 100% and not at 130%. On the phone, with Roboto, the same rule applies at 360 dp.
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(720 * 3, 800 * 3);
      addTearDown(tester.view.reset);
      final tabs = [s.overviewTab, s.upkeepTab, s.remindersTab, s.documentsTab];
      Future<TabBar> bar(double scale) async {
        await tester.pumpWidget(harness(
          MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: DefaultTabController(length: 4, child: Scaffold(appBar: AppBar(bottom: FitTabBar(tabs: tabs)))),
          ),
          fakeWorld(),
          lang: 'ms',
        ));
        await tester.pumpAndSettle();
        return tester.widget<TabBar>(find.byType(TabBar));
      }

      expect((await bar(1.0)).isScrollable, isFalse);
      expect((await bar(1.3)).isScrollable, isTrue);
    });
  });
}
