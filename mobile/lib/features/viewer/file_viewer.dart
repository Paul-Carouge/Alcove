import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/file_cache.dart';
import '../../core/file_names.dart';
import '../../core/native_files.dart';
import '../../core/previews.dart';
import '../../core/recent_files.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';
import '../photos/media.dart';
import '../photos/photo_viewer.dart';
import 'pdf_view.dart';
import 'text_view.dart';

/// Opens a drive file in the app, above the navigation bar: photos and videos in the photo viewer
/// (when the server has them in the library), PDFs page by page, text and code as text, anything
/// else on a page offering "Open with…", "Share" and "Download".
Future<void> openFileNode(BuildContext context, Session session, RecordModel node) async {
  final root = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final l = AppLocalizations.of(context);
  final mime = node.getStringValue('mime');
  final kind = previewKind(mime, node.getStringValue('name'));
  if (session.user?.id case final id?) {
    unawaited(RecentFiles(id).remember(node).catchError((Object _) {}));
  }

  if (kind == PreviewKind.image || kind == PreviewKind.video) {
    final item = await _mediaOf(session, node);
    if (item != null) {
      await root.push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoViewer(session: session, items: [item], initial: 0),
        ),
      );
      return;
    }
  }
  if (kind == PreviewKind.pdf && !NativeFiles.instance.rendersPdf) {
    // shortcut: iOS has no in-app PDF view yet (PDFKit would need its own channel); the system
    // browser shows it, as before.
    try {
      final url = session.pb.buildURL('/api/v1/nodes/${Uri.encodeComponent(node.id)}/download', {
        'token': await session.fileToken(),
        'inline': '1',
      });
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw StateError('launch');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.fileCannotOpen)));
    }
    return;
  }
  await root.push(
    MaterialPageRoute<void>(
      builder: (_) => FileViewerScreen(session: session, node: node, kind: kind),
    ),
  );
}

/// The library item of a photo or video file, if the server made one.
Future<MediaItem?> _mediaOf(Session session, RecordModel node) async {
  try {
    final res = await session.pb
        .collection('media')
        .getList(
          perPage: 1,
          filter: session.pb.filter('node = {:n}', {'n': node.id}),
          expand: 'node',
        );
    return res.items.isEmpty ? null : MediaItem(res.items.first);
  } catch (_) {
    return null;
  }
}

/// A file shown in the app with its actions: Share, Open with… and Download in a floating
/// toolbar. The file is downloaded once into the app cache (with progress) when the preview or
/// an action needs it.
class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({
    super.key,
    required this.session,
    required this.node,
    required this.kind,
    this.cache,
    this.native,
  });

  final Session session;
  final RecordModel node;
  final PreviewKind kind;
  final FileCache? cache;
  final NativeFiles? native;

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  FileCache get _cache => widget.cache ?? FileCache.instance;
  NativeFiles get _native => widget.native ?? NativeFiles.instance;
  final _pdf = PdfController();
  File? _file;
  Future<File>? _fetching;
  double? _progress; // 0..1 while downloading, null when the size is unknown
  bool _downloading = false;
  bool _failed = false;
  bool _busy = false;
  Uri? _streamUrl;

  String get _name => widget.node.getStringValue('name');

  /// The type other apps are told (never an installable package).
  String get _mime => handOutMime(_name, widget.node.getStringValue('mime'));

  /// Photos and videos stream from the server; the others are read from the downloaded file.
  bool get _streams => widget.kind == PreviewKind.image || widget.kind == PreviewKind.video;

  @override
  void initState() {
    super.initState();
    if (_streams) {
      _loadStream();
    } else if (widget.kind != PreviewKind.none) {
      unawaited(_ensureFile().catchError((Object _) => File('')));
    }
  }

  void _loadStream() {
    FileCache.nodeUrl(widget.session, widget.node).then((u) {
      if (mounted) setState(() => _streamUrl = u);
    }, onError: (Object _) => mounted ? setState(() => _failed = true) : null);
  }

  @override
  void dispose() {
    _pdf.dispose();
    super.dispose();
  }

  Future<File> _ensureFile() {
    if (_file != null) return Future.value(_file);
    return _fetching ??= () async {
      setState(() {
        _downloading = true;
        _failed = false;
        _progress = null;
      });
      try {
        final f = await _cache.node(
          widget.session,
          widget.node,
          onProgress: (got, total) {
            if (mounted && total > 0) setState(() => _progress = got / total);
          },
        );
        if (mounted) setState(() => _file = f);
        return f;
      } catch (e) {
        if (mounted) setState(() => _failed = true);
        rethrow;
      } finally {
        _fetching = null;
        if (mounted) setState(() => _downloading = false);
      }
    }();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Runs an action that needs the file; on platforms without the channel, the browser takes it.
  Future<void> _withFile(Future<void> Function(File file) action) async {
    final l = AppLocalizations.of(context);
    if (_busy) return;
    if (!_native.available) {
      // shortcut: iOS hands every action to the system browser for now (no share sheet channel).
      try {
        final url = await FileCache.nodeUrl(widget.session, widget.node);
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw StateError('x');
      } catch (_) {
        if (mounted) _snack(l.fileCannotOpen);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await action(await _ensureFile());
    } catch (_) {
      if (mounted) _snack(l.loadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _withFile((f) async {
    await _native.share([f.path], _mime, _name);
  });

  Future<void> _openWith() => _withFile((f) async {
    final l = AppLocalizations.of(context);
    if (!await _native.openWith(f.path, _mime, l.viewerOpenWith) && mounted) {
      _snack(l.viewerNoApp);
    }
  });

  Future<void> _download() => _withFile((f) async {
    final l = AppLocalizations.of(context);
    if (await _native.saveToDownloads(f.path, _name, _mime)) {
      unawaited(HapticFeedback.lightImpact());
      if (mounted) _snack(l.savedToDownloads);
    } else {
      // Android 9 and older: the share sheet saves it ("Save to…", Files).
      await _native.share([f.path], _mime, _name);
    }
  });

  Future<void> _jump() async {
    final total = _pdf.count;
    if (total < 2) return;
    final page = await showDialog<int>(
      context: context,
      builder: (_) => _PageJumpDialog(current: _pdf.page, total: total),
    );
    if (page != null) _pdf.jumpTo(page);
  }

  Widget _body(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    if (_failed && _file == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.loadFailed,
        action: OutlinedButton(
          onPressed: () {
            if (_streams) {
              setState(() => _failed = false);
              _loadStream();
            } else {
              unawaited(_ensureFile().catchError((Object _) => File('')));
            }
          },
          child: Text(l.retry),
        ),
      );
    }
    switch (widget.kind) {
      case PreviewKind.image:
        final url = _streamUrl;
        if (url == null) return Center(child: LoadingIndicator(color: c.onStage));
        return ZoomablePage(
          onDismiss: () => Navigator.of(context).maybePop(),
          child: RemoteImage(url: url, fit: BoxFit.contain, semanticLabel: _name),
        );
      case PreviewKind.video:
        final url = _streamUrl;
        if (url == null) return Center(child: LoadingIndicator(color: c.onStage));
        return VideoPage(url: url, active: true);
      case PreviewKind.none:
        return _NoPreview(node: widget.node, onOpenWith: _openWith);
      case PreviewKind.pdf:
      case PreviewKind.text:
      case PreviewKind.code:
        final file = _file;
        if (file == null) return _Downloading(progress: _progress);
        return widget.kind == PreviewKind.pdf
            ? PdfView(file: file, controller: _pdf, native: widget.native)
            : TextPreview(file: file, kind: widget.kind, name: _name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final stage = _streams;
    final fg = stage ? c.onStage : c.text;
    final muted = stage ? c.onStageMuted : c.textMuted;
    final size = widget.node.getIntValue('size');
    final updated = modifiedAt(widget.node);
    final meta = [
      if (size > 0) _formatSize(size, locale),
      if (updated != null) DateFormat.yMMMd(locale).format(updated.toLocal()),
    ].join(' · ');
    final bottom = MediaQuery.paddingOf(context).bottom;
    // The toolbar floats over the content, which keeps room for it at its end.
    const toolbarRoom = 52 + AlcoveSpace.s2 + AlcoveSpace.s4 * 2;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: stage || Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: stage
            ? c.stage
            : (widget.kind == PreviewKind.pdf ? c.surfaceSunken : c.bg),
        appBar: AppBar(
          backgroundColor: stage ? c.stage : c.bg,
          foregroundColor: fg,
          titleSpacing: 0,
          leading: BackButton(color: fg),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sansStyle(AlcoveFont.sizeMd, fg, AlcoveFont.semibold),
                ),
              ),
              if (meta.isNotEmpty) Text(meta, style: sansStyle(AlcoveFont.sizeXs, muted)),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: stage ? c.stageBorder : c.border),
          ),
        ),
        body: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: MediaQuery.paddingOf(context).copyWith(bottom: bottom + toolbarRoom),
          ),
          child: _body(context),
        ),
        // The toolbar takes the FAB's place, so snackbars appear above it instead of over it.
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
          child: Center(
            heightFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: FloatingToolbar(
                color: stage ? c.stagePanel.withValues(alpha: 0.94) : null,
                foreground: stage ? c.onStage : null,
                border: stage ? c.stageBorder : null,
                children: [
                  if (widget.kind == PreviewKind.pdf)
                    ListenableBuilder(
                      listenable: _pdf,
                      builder: (context, _) => _pdf.count == 0
                          ? const SizedBox.shrink()
                          : _PageChip(
                              page: _pdf.page,
                              count: _pdf.count,
                              onTap: _pdf.count > 1 ? _jump : null,
                            ),
                    ),
                  IconButton(
                    key: const Key('viewerShare'),
                    tooltip: l.viewerShare,
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.share_outlined),
                  ),
                  IconButton(
                    key: const Key('viewerOpenWith'),
                    tooltip: l.viewerOpenWith,
                    onPressed: _busy ? null : _openWith,
                    icon: const Icon(Icons.open_in_new),
                  ),
                  IconButton(
                    key: const Key('viewerDownload'),
                    tooltip: l.viewerDownload,
                    onPressed: _busy ? null : _download,
                    icon: _busy && !_downloading
                        ? LoadingIndicator(size: 24, color: fg)
                        : const Icon(Icons.download_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatSize(int bytes, String locale) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var u = 0;
  while (v >= 1000 && u < units.length - 1) {
    v /= 1000;
    u++;
  }
  return '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: u == 0 ? 0 : 1).format(v)} ${units[u]}';
}

/// Asks for a page number (1 to [total]); returns it 0-based.
class _PageJumpDialog extends StatefulWidget {
  const _PageJumpDialog({required this.current, required this.total});
  final int current;
  final int total;

  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  late final _field = TextEditingController(text: '${widget.current + 1}')
    ..selection = TextSelection(baseOffset: 0, extentOffset: '${widget.current + 1}'.length);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_field.text.trim());
    if (n != null && n >= 1 && n <= widget.total) Navigator.pop(context, n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.pdfJumpTitle),
      content: TextField(
        key: const Key('pageField'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: l.pdfJumpLabel(widget.total)),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _submit, child: Text(l.pdfJump)),
      ],
    );
  }
}

/// "3 / 12" in the toolbar; tapping it asks for a page.
class _PageChip extends StatelessWidget {
  const _PageChip({required this.page, required this.count, this.onTap});

  final int page;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: l.pdfPage(page + 1, count),
      hint: onTap == null ? null : l.pdfJumpTitle,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: AlcoveSpace.s1),
        child: Material(
          color: c.accentSubtle,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('pageChip'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    l.pdfPageShort(page + 1, count),
                    semanticsLabel: '',
                    style: sansStyle(AlcoveFont.sizeSm, c.text, AlcoveFont.semibold).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The download of a file about to be shown.
class _Downloading extends StatelessWidget {
  const _Downloading({required this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final p = progress;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: p == null ? l.viewerDownloading : l.viewerDownloadingPercent((p * 100).round()),
        excludeSemantics: true,
        child: ProgressRing(
          value: p,
          size: 88,
          child: p == null
              ? const SizedBox.shrink()
              : Text(
                  '${(p * 100).round()} %',
                  style: sansStyle(AlcoveFont.sizeSm, c.textMuted, AlcoveFont.medium),
                ),
        ),
      ),
    );
  }
}

/// Files the app cannot show: a calm card and the way out (another app).
class _NoPreview extends StatelessWidget {
  const _NoPreview({required this.node, required this.onOpenWith});
  final RecordModel node;
  final VoidCallback onOpenWith;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.insert_drive_file_outlined,
      title: l.viewerNoPreview,
      body: l.viewerNoPreviewBody,
      action: FilledButton.icon(
        onPressed: onOpenWith,
        icon: const Icon(Icons.open_in_new),
        label: Text(l.viewerOpenWith),
      ),
    );
  }
}
