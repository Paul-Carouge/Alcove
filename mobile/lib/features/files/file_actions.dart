import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/drive.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';

/// The message of a refused request, for a snackbar.
String errorMessage(BuildContext context, Object error) {
  if (error is ClientException) {
    final data = error.response['data'];
    if (data is Map && data.isNotEmpty) {
      final first = data.values.first;
      if (first is Map && first['message'] is String) return first['message'] as String;
    }
    final m = error.response['message'];
    if (m is String && m.isNotEmpty && error.statusCode >= 400 && error.statusCode < 500) return m;
  }
  return AppLocalizations.of(context).errorUnexpected;
}

/// Asks for a file or folder name; returns it, or null when cancelled.
Future<String?> askName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, action: action, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.action, required this.initial});
  final String title;
  final String action;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void initState() {
    super.initState();
    // Select the name without its extension, like desktop file managers.
    final dot = widget.initial.lastIndexOf('.');
    _name.selection = TextSelection(
      baseOffset: 0,
      extentOffset: dot > 0 ? dot : widget.initial.length,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    final why = invalidName(_name.text);
    if (why != null) {
      setState(
        () => _error = switch (why) {
          'empty' => l.errorRequired,
          'long' => l.nameTooLong,
          _ => l.nameInvalid,
        },
      );
      return;
    }
    Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('nameField'),
        controller: _name,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: l.nameLabel, errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

/// What the "+" button offers.
enum AddAction { folder, upload, scan }

Future<AddAction?> showAddSheet(BuildContext context, {required bool canScan}) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<AddAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AlcoveSpace.s2),
        child: InsetGroup(
          children: [
            GroupTile(
              icon: Icons.create_new_folder_outlined,
              title: l.newFolder,
              onTap: () => Navigator.pop(context, AddAction.folder),
            ),
            GroupTile(
              icon: Icons.upload_file_outlined,
              title: l.uploadFiles,
              subtitle: l.uploadFilesHint,
              onTap: () => Navigator.pop(context, AddAction.upload),
            ),
            if (canScan)
              GroupTile(
                icon: Icons.document_scanner_outlined,
                title: l.scanDocument,
                subtitle: l.scanDocumentHint,
                onTap: () => Navigator.pop(context, AddAction.scan),
              ),
          ],
        ),
      ),
    ),
  );
}

/// What can be done with one file or folder.
enum NodeAction { rename, move, trash }

Future<NodeAction?> showNodeSheet(BuildContext context, RecordModel node) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<NodeAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AlcoveSpace.s2),
        child: InsetGroup(
          title: node.getStringValue('name'),
          children: [
            GroupTile(
              icon: Icons.drive_file_rename_outline,
              title: l.rename,
              onTap: () => Navigator.pop(context, NodeAction.rename),
            ),
            GroupTile(
              icon: Icons.drive_file_move_outline,
              title: l.move,
              onTap: () => Navigator.pop(context, NodeAction.move),
            ),
            GroupTile(
              icon: Icons.delete_outline,
              title: l.trashConfirm,
              danger: true,
              onTap: () => Navigator.pop(context, NodeAction.trash),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Picks a destination folder; returns its id ('' for the root) or null when cancelled.
/// [moving] cannot be chosen, nor entered (a folder cannot go inside itself).
Future<String?> pickFolder(BuildContext context, Drive drive, RecordModel moving) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FolderPicker(drive: drive, moving: moving, folder: null),
    ),
  );
}

class _FolderPicker extends StatefulWidget {
  const _FolderPicker({required this.drive, required this.moving, required this.folder});
  final Drive drive;
  final RecordModel moving;
  final RecordModel? folder;

  @override
  State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  List<RecordModel>? _folders;
  bool _failed = false;

  String get _here => widget.folder?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.drive.folders(_here);
      if (mounted) setState(() => _folders = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final folders = _folders;
    final already = widget.moving.getStringValue('parent') == _here;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(widget.folder?.getStringValue('name') ?? l.myFiles),
        leading: widget.folder == null
            ? IconButton(
                tooltip: l.cancel,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: _failed
          ? EmptyState(icon: Icons.cloud_off_outlined, title: l.loadFailed)
          : folders == null
          ? const Center(child: CircularProgressIndicator())
          : folders.isEmpty
          ? EmptyState(icon: Icons.folder_open_outlined, title: l.noSubfolders)
          : ListView(
              padding: const EdgeInsets.only(top: AlcoveSpace.s3),
              children: [
                InsetGroup(
                  children: [
                    for (final f in folders)
                      GroupTile(
                        icon: Icons.folder_rounded,
                        tint: c.accent,
                        title: f.getStringValue('name'),
                        onTap: f.id == widget.moving.id
                            ? null
                            : () async {
                                final picked = await Navigator.of(context).push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => _FolderPicker(
                                      drive: widget.drive,
                                      moving: widget.moving,
                                      folder: f,
                                    ),
                                  ),
                                );
                                if (picked != null && context.mounted) {
                                  Navigator.pop(context, picked);
                                }
                              },
                      ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AlcoveSpace.s4),
          child: FilledButton.icon(
            key: const Key('moveHere'),
            onPressed: already ? null : () => Navigator.pop(context, _here),
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text(already ? l.alreadyHere : l.moveHere),
          ),
        ),
      ),
    );
  }
}

/// Files chosen in the system picker, ready for the upload queue.
Future<List<UploadItem>> pickUploads(String parent) async {
  final picked = await FilePicker.pickFiles();
  return [
    for (final f in picked)
      UploadItem(
        name: f.name,
        parent: parent,
        open: () async => f.path != null ? File(f.path!) : spool(f.readAsByteStream(), f.name),
      ),
  ];
}

/// Scans pages with the system document scanner (Android, Google Play services) into one PDF.
/// Returns null when the user cancels.
Future<UploadItem?> scanDocument(String parent, String locale) async {
  final scanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormats: const {DocumentFormat.pdf},
      pageLimit: 50,
      isGalleryImport: true,
    ),
  );
  try {
    final result = await scanner.scanDocument();
    final pdf = result.pdf;
    if (pdf == null) return null;
    final uri = Uri.parse(pdf.uri);
    final path = uri.scheme == 'file' ? uri.toFilePath() : pdf.uri;
    final stamp = DateFormat('yyyy-MM-dd HH.mm', locale).format(DateTime.now());
    return UploadItem(name: 'Scan $stamp.pdf', parent: parent, open: () async => File(path));
  } finally {
    await scanner.close();
  }
}

/// Progress of the files being sent, shown at the bottom of Files.
class UploadBanner extends StatelessWidget {
  const UploadBanner({super.key, required this.queue});
  final UploadQueue queue;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        if (queue.items.isEmpty) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        final c = context.colors;
        final items = queue.items;
        final current = items.where((i) => i.status == UploadStatus.uploading).firstOrNull;
        final total = items.length;
        final done = queue.finished;
        final failed = queue.failedCount;
        final active = queue.active;
        final progress = total == 0 ? 0.0 : (done + failed + (current?.fraction ?? 0)) / total;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(AlcoveSpace.s3, 0, AlcoveSpace.s3, AlcoveSpace.s3),
            padding: const EdgeInsets.fromLTRB(
              AlcoveSpace.s4,
              AlcoveSpace.s3,
              AlcoveSpace.s2,
              AlcoveSpace.s3,
            ),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(AlcoveRadius.lg),
              border: Border.all(color: c.border),
              boxShadow: c.shadowMD,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: active ? progress : 1,
                        strokeWidth: 3,
                        color: failed > 0 && !active ? c.danger : c.accent,
                        backgroundColor: c.surfaceSunken,
                      ),
                      Icon(
                        active
                            ? Icons.arrow_upward
                            : failed > 0
                            ? Icons.priority_high
                            : Icons.check,
                        size: 18,
                        color: failed > 0 && !active ? c.danger : c.accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AlcoveSpace.s3),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          active ? l.uploading(done + failed + 1, total) : l.uploaded(done),
                          style: const TextStyle(fontWeight: AlcoveFont.semibold),
                        ),
                        Text(
                          current?.name ??
                              (failed > 0 ? l.uploadsFailed(failed) : l.uploadsDoneHint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeSm),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!active && failed > 0)
                  TextButton(onPressed: queue.retryFailed, child: Text(l.retry)),
                if (!active)
                  IconButton(
                    tooltip: l.searchClear,
                    icon: const Icon(Icons.close),
                    onPressed: queue.clear,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
