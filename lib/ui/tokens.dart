// Design tokens from the approved 0.2.7 design system: colours for light and dark,
// type sizes, spacing and radii. Screens read colours through `context.tokens`, so a
// colour is changed here once rather than in every screen.

import 'package:flutter/material.dart';

/// Colours. Every text pair was checked for at least 4.5:1 contrast (WCAG AA) in both modes.
@immutable
class KukiraColors extends ThemeExtension<KukiraColors> {
  const KukiraColors({
    required this.background,
    required this.surface,
    required this.line,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.label,
    required this.iconBg,
    required this.iconFg,
    required this.primary,
    required this.onPrimary,
    required this.tonal,
    required this.onTonal,
    required this.overdue,
    required this.overdueBg,
    required this.dueSoon,
    required this.dueSoonBg,
    required this.done,
    required this.expired,
  });

  /// Page background.
  final Color background;

  /// Groups of rows, cards and the navigation bar.
  final Color surface;

  /// Edge of a group (decorative: the rows inside identify it).
  final Color line;

  /// Between rows in a group.
  final Color divider;
  final Color text;
  final Color textMuted;

  /// Section titles and unselected navigation labels.
  final Color label;

  /// Asset and type icons stay neutral; only status has colour.
  final Color iconBg;
  final Color iconFg;

  /// The one main action on a screen, and the selected item.
  final Color primary;
  final Color onPrimary;

  /// Secondary actions shown only when needed (Renew, Update).
  final Color tonal;
  final Color onTonal;
  final Color overdue;
  final Color overdueBg;
  final Color dueSoon;
  final Color dueSoonBg;
  final Color done;

  /// A document or cover that has ended: history, not a warning.
  final Color expired;

  static const light = KukiraColors(
    background: Color(0xFFF6F7F5),
    surface: Color(0xFFFFFFFF),
    line: Color(0xFFE2E5E1),
    divider: Color(0xFFECEEEB),
    text: Color(0xFF17201B), // 16.7:1 on surface
    textMuted: Color(0xFF5A645E), // 6.1:1 on surface, 5.7:1 on background
    label: Color(0xFF4F5953), // 6.8:1 on background
    iconBg: Color(0xFFEEF1EE),
    iconFg: Color(0xFF4F5953),
    primary: Color(0xFF1E6A4E), // 6.5:1 with white
    onPrimary: Color(0xFFFFFFFF),
    tonal: Color(0xFFDCEDE4),
    onTonal: Color(0xFF14513A), // 7.6:1
    overdue: Color(0xFFB3261E), // 6.5:1 on surface, 5.8:1 on overdueBg
    overdueBg: Color(0xFFFCEFED),
    dueSoon: Color(0xFF8A5300), // 6.3:1 on surface, 5.7:1 on dueSoonBg
    dueSoonBg: Color(0xFFFDF1DC),
    done: Color(0xFF1E6A4E),
    expired: Color(0xFF69736D), // 4.9:1 on surface
  );

  static const dark = KukiraColors(
    background: Color(0xFF111613),
    surface: Color(0xFF1A201C),
    line: Color(0xFF2B332E),
    divider: Color(0xFF252C27),
    text: Color(0xFFE6EAE7), // 13.6:1 on surface
    textMuted: Color(0xFFA9B2AC), // 7.6:1
    label: Color(0xFFB8C0BA),
    iconBg: Color(0xFF252C27),
    iconFg: Color(0xFFB8C0BA),
    primary: Color(0xFF8AD5AE), // 9.6:1 on surface
    onPrimary: Color(0xFF0B3D27), // 7.1:1 on primary
    tonal: Color(0xFF23372C),
    onTonal: Color(0xFFC8E8D6), // 9.7:1
    overdue: Color(0xFFF2B8B5), // 9.7:1 on surface, 8.6:1 on overdueBg
    overdueBg: Color(0xFF3B2120),
    dueSoon: Color(0xFFF0B45B), // 9.0:1 on surface, 7.2:1 on dueSoonBg
    dueSoonBg: Color(0xFF3A2E16),
    done: Color(0xFF8AD5AE),
    expired: Color(0xFF8D978F), // 5.5:1
  );

  @override
  KukiraColors copyWith() => this;

  @override
  KukiraColors lerp(KukiraColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return KukiraColors(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      line: c(line, other.line),
      divider: c(divider, other.divider),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      label: c(label, other.label),
      iconBg: c(iconBg, other.iconBg),
      iconFg: c(iconFg, other.iconFg),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      tonal: c(tonal, other.tonal),
      onTonal: c(onTonal, other.onTonal),
      overdue: c(overdue, other.overdue),
      overdueBg: c(overdueBg, other.overdueBg),
      dueSoon: c(dueSoon, other.dueSoon),
      dueSoonBg: c(dueSoonBg, other.dueSoonBg),
      done: c(done, other.done),
      expired: c(expired, other.expired),
    );
  }
}

extension KukiraTokens on BuildContext {
  /// The colours of the current theme. Falls back by brightness for a theme built
  /// without them (some widget tests use a plain ThemeData).
  KukiraColors get tokens =>
      Theme.of(this).extension<KukiraColors>() ?? (Theme.of(this).brightness == Brightness.dark ? KukiraColors.dark : KukiraColors.light);
}

/// Type sizes (Roboto, the Android system font). Colours come from [KukiraColors].
abstract final class KText {
  static const screenTitle = TextStyle(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w500);
  static const title = TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w500);
  static const subtitle = TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w500);
  static const row = TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w500);
  static const meta = TextStyle(fontSize: 13, height: 18 / 13);
  static const section = TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500);

  /// Status words and amounts. Digits are equal width so RM and km line up.
  static const status = TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()]);
}

/// Spacing steps and radii.
abstract final class KSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;

  /// Rows are at least this tall; touch targets at least 48.
  static const rowMin = 64.0;

  /// Bottom padding of a list under a floating Tambah button, so its last item can
  /// scroll clear of the button.
  static const fabClearance = 88.0;

  static const groupRadius = 12.0;
  static const controlRadius = 10.0;
}
