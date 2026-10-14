import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';

const tagColors = ['gray', 'red', 'orange', 'yellow', 'green', 'teal', 'blue', 'violet', 'pink'];

/// Text and background colours of a tag colour name (design tokens, WCAG AA).
(Color, Color) tagPalette(AlcoveColors c, String color) => switch (color) {
  'red' => (c.tagRed, c.tagRedBg),
  'orange' => (c.tagOrange, c.tagOrangeBg),
  'yellow' => (c.tagYellow, c.tagYellowBg),
  'green' => (c.tagGreen, c.tagGreenBg),
  'teal' => (c.tagTeal, c.tagTealBg),
  'blue' => (c.tagBlue, c.tagBlueBg),
  'violet' => (c.tagViolet, c.tagVioletBg),
  'pink' => (c.tagPink, c.tagPinkBg),
  _ => (c.tagGray, c.tagGrayBg),
};

/// The user's tags, loaded once per screen that needs them.
class TagBook {
  TagBook(this.session);
  final Session session;
  List<RecordModel> items = [];

  Map<String, RecordModel> get byId => {for (final t in items) t.id: t};

  Future<void> load() async {
    items = await session.pb.collection('tags').getFullList(sort: 'name');
  }

  Future<RecordModel> create(String name, String color) async {
    final t = await session.pb
        .collection('tags')
        .create(body: {'owner': session.user?.id, 'name': name.trim(), 'color': color});
    items = [...items, t]
      ..sort(
        (a, b) => a
            .getStringValue('name')
            .toLowerCase()
            .compareTo(b.getStringValue('name').toLowerCase()),
      );
    return t;
  }

  List<RecordModel> of(RecordModel node) {
    final tags = byId;
    return [for (final id in node.getListValue<String>('tags')) ?tags[id]];
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.tag});
  final RecordModel tag;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tagPalette(context.colors, tag.getStringValue('color'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s2, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AlcoveRadius.full)),
      child: Text(
        tag.getStringValue('name'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontSize: AlcoveFont.sizeXs, fontWeight: AlcoveFont.medium),
      ),
    );
  }
}

/// Picks the tags of a node (and creates new ones); returns the chosen ids, or null when cancelled.
Future<List<String>?> pickTags(BuildContext context, TagBook book, RecordModel node) {
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TagPicker(book: book, node: node),
  );
}

class _TagPicker extends StatefulWidget {
  const _TagPicker({required this.book, required this.node});
  final TagBook book;
  final RecordModel node;

  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  late final Set<String> _selected = {...widget.node.getListValue<String>('tags')};
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 40) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final color = tagColors[(widget.book.items.length + 6) % tagColors.length];
      final t = await widget.book.create(name, color);
      _name.clear();
      setState(() => _selected.add(t.id));
    } catch (_) {
      setState(() => _error = l.tagNameTaken);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final tags = widget.book.items;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: l.tagsOf(widget.node.getStringValue('name'))),
              if (tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s5),
                  child: Text(
                    l.tagsEmpty,
                    style: TextStyle(color: c.textMuted, height: AlcoveFont.leadingNormal),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                  child: SingleChildScrollView(
                    child: InsetGroup(
                      children: [
                        for (final t in tags)
                          CheckboxListTile(
                            value: _selected.contains(t.id),
                            onChanged: (on) => setState(
                              () => on == true ? _selected.add(t.id) : _selected.remove(t.id),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Align(
                              alignment: Alignment.centerLeft,
                              child: TagChip(tag: t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AlcoveSpace.s4,
                  AlcoveSpace.s3,
                  AlcoveSpace.s4,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('newTag'),
                        controller: _name,
                        maxLength: 40,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                        decoration: InputDecoration(
                          labelText: l.tagNew,
                          errorText: _error,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: AlcoveSpace.s2),
                    IconButton.filledTonal(
                      tooltip: l.tagAdd,
                      onPressed: _busy ? null : _add,
                      style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AlcoveSpace.s4),
                child: FilledButton(
                  key: const Key('saveTags'),
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: Text(l.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
