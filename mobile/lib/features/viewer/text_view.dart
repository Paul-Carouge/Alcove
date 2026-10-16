import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/previews.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';

/// Decodes a file into chunks of lines (in a background isolate), or null when it is not text.
List<String>? _prepare((Uint8List, PreviewKind, String) a) {
  final text = previewText(a.$1, a.$2, name: a.$3);
  return text == null ? null : textChunks(text);
}

/// A text file, read in the app: prose in the text face with a comfortable measure, code and data
/// in monospace. Files above [maxTextPreviewBytes] are not loaded (a message says why).
class TextPreview extends StatefulWidget {
  const TextPreview({super.key, required this.file, required this.kind, required this.name});

  final File file;
  final PreviewKind kind;
  final String name;

  @override
  State<TextPreview> createState() => _TextPreviewState();
}

sealed class _TextState {}

class _Loading extends _TextState {}

class _TooLarge extends _TextState {}

class _NotText extends _TextState {}

class _Ready extends _TextState {
  _Ready(this.chunks);
  final List<String> chunks;
}

class _TextPreviewState extends State<TextPreview> {
  _TextState _state = _Loading();

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final _TextState next;
    try {
      if (await widget.file.length() > maxTextPreviewBytes) {
        next = _TooLarge();
      } else {
        final bytes = await widget.file.readAsBytes();
        // Decoding and indenting a large file would stall the page transition.
        final chunks = await compute(_prepare, (bytes, widget.kind, widget.name));
        next = chunks == null ? _NotText() : _Ready(chunks);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _NotText());
      return;
    }
    if (mounted) setState(() => _state = next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final code = widget.kind == PreviewKind.code;
    return switch (_state) {
      _Loading() => const Center(child: LoadingIndicator()),
      _TooLarge() => EmptyState(
        icon: Icons.description_outlined,
        title: l.viewerTooLarge,
        body: l.viewerNoPreviewBody,
      ),
      _NotText() => EmptyState(
        icon: Icons.description_outlined,
        title: l.viewerNotText,
        body: l.viewerNoPreviewBody,
      ),
      _Ready(:final chunks) => SelectionArea(
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            AlcoveSpace.s5,
            AlcoveSpace.s4,
            AlcoveSpace.s5,
            AlcoveSpace.s6 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: chunks.length,
          itemBuilder: (_, i) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              // About 70 characters per line for prose; every chunk starts at the same edge.
              constraints: BoxConstraints(
                maxWidth: code ? double.infinity : 640,
                minWidth: code ? double.infinity : 640,
              ),
              child: Text(
                chunks[i],
                style: code
                    ? TextStyle(
                        fontFamily: AlcoveFont.mono,
                        fontFamilyFallback: const ['monospace', 'Menlo', 'Courier'],
                        fontSize: AlcoveFont.sizeSm - 1,
                        height: 1.55,
                        color: c.text,
                      )
                    : sansStyle(AlcoveFont.sizeMd, c.text).copyWith(height: 1.6),
              ),
            ),
          ),
        ),
      ),
    };
  }
}
