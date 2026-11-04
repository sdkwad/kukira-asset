import 'package:flutter/material.dart';

import '../data/db.dart';
import '../domain/lists.dart';
import '../l10n/strings.dart';
import '../services/links.dart';
import 'common.dart';

/// One suggestion in a [ComboField].
class ComboOption {
  const ComboOption(this.value, {this.detail, this.also = ''});

  /// What goes in the field when it is picked.
  final String value;

  /// A second line: the licensed name of an insurer, the state of a council.
  final String? detail;

  /// More text the search looks in, such as a short form ("MBSA").
  final String also;
}

String _plain(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// The suggestions that match what has been typed, best first: those that start with it, then
/// those with a word that starts with it, then any that contain it. Spaces and punctuation are
/// ignored ("cx5" finds "CX-5"). An option the field already says, as written, is left out,
/// since there is nothing left to pick.
List<ComboOption> comboMatches(List<ComboOption> options, String text) {
  final q = _plain(text);
  if (q.isEmpty) return options;
  final qc = q.replaceAll(' ', '');
  final typed = text.trim().toLowerCase();
  final ranked = <(int, int, ComboOption)>[];
  for (var i = 0; i < options.length; i++) {
    final o = options[i];
    if (o.value.toLowerCase() == typed) continue;
    final v = _plain(o.value);
    final vc = v.replaceAll(' ', '');
    final int? rank;
    if (v.startsWith(q) || vc.startsWith(qc)) {
      rank = 0;
    } else if (' $v'.contains(' $q')) {
      rank = 1;
    } else if (vc.contains(qc)) {
      rank = 2;
    } else if (_plain('${o.also} ${o.detail ?? ''}').replaceAll(' ', '').contains(qc)) {
      rank = 3;
    } else {
      rank = null;
    }
    if (rank != null) ranked.add((rank, i, o));
  }
  ranked.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [for (final r in ranked) r.$3];
}

/// [base] with the values the owner typed before that are not in it, those first: a make
/// they own, a council or area they used.
List<ComboOption> withTyped(List<ComboOption> base, Iterable<String?> typed) {
  final known = {for (final o in base) _plain(o.value)};
  final own = <ComboOption>[];
  for (final t in typed) {
    final v = t?.trim() ?? '';
    if (v.isEmpty || !known.add(_plain(v))) continue;
    own.add(ComboOption(v));
  }
  return [...own, ...base];
}

const _optionsMax = 264.0;

/// The list of suggestions under a field, for finding it in tests.
const comboOptionsKey = ValueKey('combo-options');

/// A text field with a list to pick from, that also takes anything typed. Typing shows the
/// matching suggestions under the field; the arrow opens the whole list. The text is saved
/// exactly as typed, so a model or a council that is not in the list is never an error.
class ComboField extends StatefulWidget {
  const ComboField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    this.hint,
    this.helper,
    this.source,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.onChanged,
    this.onSelected,
    this.trailing,
    this.listButton = true,
    this.dense = false,
  });

  final TextEditingController controller;
  final String? label;
  final List<ComboOption> options;
  final String? hint;
  final String? helper;

  /// Where the list comes from, shown under the whole list ("From KPKT, Nov 2026").
  final String? source;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  /// Every change of the text, typed or picked.
  final ValueChanged<String>? onChanged;
  final ValueChanged<ComboOption>? onSelected;

  /// A button before the arrow, such as a link to the council's website.
  final Widget? trailing;

  /// False for a narrow field, which shows only the suggestions under it while typing.
  final bool listButton;
  final bool dense;

  @override
  State<ComboField> createState() => _ComboFieldState();
}

class _ComboFieldState extends State<ComboField> {
  final _focus = FocusNode();
  double _width = 280;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _picked(ComboOption o) {
    widget.onSelected?.call(o);
    widget.onChanged?.call(o.value);
  }

  Future<void> _openList() async {
    _focus.unfocus();
    final o = await showModalBottomSheet<ComboOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ComboSheet(title: widget.label ?? '', options: widget.options, current: widget.controller.text, source: widget.source),
    );
    if (o == null || !mounted) return;
    widget.controller.value = TextEditingValue(text: o.value, selection: TextSelection.collapsed(offset: o.value.length));
    _picked(o);
  }

  Widget _optionsView(BuildContext overlay, AutocompleteOnSelected<ComboOption> select, Iterable<ComboOption> options) {
    final s = context.s;
    final k = context.tokens;
    final list = options.toList();
    final hi = AutocompleteHighlightedOption.of(overlay);
    // Keep the list above the keyboard: as tall as the room under the field allows.
    final mq = MediaQuery.of(overlay);
    var maxH = _optionsMax;
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached) {
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      maxH = (mq.size.height - mq.viewInsets.bottom - bottom - 12).clamp(120.0, _optionsMax);
    }
    final q = widget.controller.text.trim();
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          elevation: 4,
          color: k.surface,
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH, minWidth: _width, maxWidth: _width),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Flexible(
                child: ListView.builder(
                  key: comboOptionsKey,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (c, i) => InkWell(
                    onTap: () => select(list[i]),
                    child: Container(
                      color: i == hi ? k.divider : null,
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      alignment: Alignment.centerLeft,
                      child: _OptionText(list[i], q),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: k.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Text(s.comboNotListed, style: KText.meta.copyWith(color: k.textMuted)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth.isFinite) _width = box.maxWidth;
      final buttons = [
        if (widget.trailing != null) widget.trailing!,
        if (widget.listButton && widget.options.isNotEmpty)
          IconButton(icon: const Icon(Icons.expand_more), tooltip: s.showList, onPressed: _openList),
      ];
      return RawAutocomplete<ComboOption>(
        textEditingController: widget.controller,
        focusNode: _focus,
        displayStringForOption: (o) => o.value,
        optionsBuilder: (v) => comboMatches(widget.options, v.text),
        onSelected: _picked,
        optionsViewBuilder: _optionsView,
        // Enter keeps what was typed; only a tap picks a suggestion.
        fieldViewBuilder: (context, ctrl, focus, _) => TextField(
          controller: ctrl,
          focusNode: focus,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          // Scroll far enough that the suggestions fit between the field and the keyboard.
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20 + _optionsMax),
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 3,
            isDense: widget.dense,
            border: const OutlineInputBorder(),
            suffixIcon: buttons.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: buttons),
          ),
        ),
      );
    });
  }
}

/// A suggestion with the typed part in bold, and its second line.
class _OptionText extends StatelessWidget {
  const _OptionText(this.o, this.q);
  final ComboOption o;
  final String q;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final base = TextStyle(fontSize: 16, height: 22 / 16, color: k.text);
    final at = q.isEmpty ? -1 : o.value.toLowerCase().indexOf(q.toLowerCase());
    final title = at < 0
        ? Text(o.value, style: base)
        : Text.rich(TextSpan(style: base, children: [
            TextSpan(text: o.value.substring(0, at)),
            TextSpan(text: o.value.substring(at, at + q.length), style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: o.value.substring(at + q.length)),
          ]));
    if (o.detail == null) return title;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      title,
      Text(o.detail!, style: KText.meta.copyWith(color: k.textMuted)),
    ]);
  }
}

/// The whole list, with a search when it is long.
class _ComboSheet extends StatefulWidget {
  const _ComboSheet({required this.title, required this.options, required this.current, this.source});
  final String title;
  final List<ComboOption> options;
  final String current;
  final String? source;

  @override
  State<_ComboSheet> createState() => _ComboSheetState();
}

class _ComboSheetState extends State<_ComboSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final k = context.tokens;
    final list = _q.trim().isEmpty ? widget.options : comboMatches(widget.options, _q);
    final current = _plain(widget.current);
    // The field may hold the short form of a listed option ("MBSA").
    bool isCurrent(ComboOption o) => _plain(o.value) == current || (o.also.isNotEmpty && _plain(o.also) == current);
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Semantics(header: true, child: Text(widget.title, style: KText.title.copyWith(color: k.text))),
          ),
          if (widget.options.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(hintText: s.searchList, prefixIcon: const Icon(Icons.search), isDense: true, border: const OutlineInputBorder()),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (c, i) {
                final o = list[i];
                final on = isCurrent(o);
                return ListTile(
                  title: Text(o.value),
                  subtitle: o.detail == null ? null : Text(o.detail!),
                  trailing: on ? Icon(Icons.check, color: k.primary) : null,
                  selected: on,
                  onTap: () => Navigator.pop(context, o),
                );
              },
            ),
          ),
          Divider(height: 1, color: k.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Text([s.typeYourOwn, if (widget.source != null) widget.source!].join(' '), style: KText.meta.copyWith(color: k.textMuted)),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- the lists, with the owner's own

List<ComboOption> makeOptions(World w, String category) => withTyped(
      [for (final m in makesFor(category)) ComboOption(m)],
      [for (final a in w.assets) if (a.category == category) w.vehicles[a.id]?.make],
    );

List<ComboOption> modelOptions(World w, String category, String make) => withTyped(
      [for (final m in modelsFor(category, make)) ComboOption(m)],
      [
        for (final a in w.assets)
          if (a.category == category && _plain(w.vehicles[a.id]?.make ?? '') == _plain(make)) w.vehicles[a.id]?.model,
      ],
    );

List<ComboOption> yearComboOptions() => [for (final y in yearOptions(DateTime.now())) ComboOption(y)];

List<ComboOption> insurerOptions(World w) => withTyped(
      [for (final i in insurers) ComboOption(i.name, detail: i.licensedName)],
      w.vehicles.values.map((v) => v.insuranceProvider),
    );

List<ComboOption> stateOptions() => [for (final s in malaysianStates) ComboOption(s)];

/// The councils of the chosen state, or of every state (each with its state) when none is.
/// A council typed before as its short form ("MBSA") is that listed council, not another one.
List<ComboOption> councilOptions(World w, String state) {
  final st = stateNamed(state);
  return withTyped(
    [for (final (c, cs) in councilsFor(state)) ComboOption(c.label, detail: st == null ? cs : null, also: c.abbr ?? '')],
    [
      for (final h in w.houses.values)
        if ((st == null || stateNamed(h.state) == st) && councilNamed(h.council, state: h.state) == null) h.council,
    ],
  );
}

List<ComboOption> areaOptions(Str s, World w) => withTyped([for (final a in s.houseAreas) ComboOption(a)], w.records.map((r) => r.area));

List<ComboOption> itemOptions(Str s, World w, {required bool vehicle}) {
  final ids = {
    for (final r in w.records)
      if ((w.asset(r.assetId)?.category == 'house') != vehicle) r.id,
  };
  return withTyped(
    [for (final i in s.itemSuggestions(vehicle)) ComboOption(i)],
    [for (final MapEntry(key: id, value: items) in w.costItems.entries) if (ids.contains(id)) ...items.map((i) => i.label)],
  );
}

// ---------------------------------------------------------------- council website

/// Opens a website in the phone's browser, or says there is none.
Future<void> openWebsite(BuildContext context, String url) async {
  final s = context.s;
  final ok = await Links.openWeb(url);
  if (!ok && context.mounted) snack(context, s.noBrowser);
}

/// A link button for the council a text names, when that council has a checked website.
Widget? councilLinkButton(BuildContext context, String? council, {String? state}) {
  final web = councilNamed(council, state: state)?.$1.web;
  if (web == null) return null;
  return IconButton(icon: const Icon(Icons.open_in_new), tooltip: context.s.openWebsite, onPressed: () => openWebsite(context, web));
}
