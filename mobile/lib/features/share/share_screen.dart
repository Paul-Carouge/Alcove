import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/drive.dart';
import '../../core/session.dart';
import '../../core/share_inbox.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';
import '../files/files_screen.dart';

/// Where shared files go: a folder id ('' = My files) and its name.
typedef ShareDestination = ({String folderId, String name});

/// "Share to Alcove": the files another app sent, and a folder to put them in. Folders open in
/// place (back goes up); the button sends the files to the folder shown.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.session, required this.files, this.drive});

  final Session session;
  final List<SharedFile> files;
  final Drive? drive;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  late final Drive _drive = widget.drive ?? Drive(widget.session);

  /// The folders entered, from the root.
  final List<RecordModel> _path = [];
  List<RecordModel>? _folders;
  bool _failed = false;

  String get _here => _path.isEmpty ? '' : _path.last.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final here = _here;
    setState(() {
      _folders = null;
      _failed = false;
    });
    try {
      final list = await _drive.folders(here);
      if (mounted && here == _here) setState(() => _folders = list);
    } catch (_) {
      if (mounted && here == _here) setState(() => _failed = true);
    }
  }

  void _enter(RecordModel folder) {
    _path.add(folder);
    _load();
  }

  void _up() {
    _path.removeLast();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final files = widget.files;
    final here = _path.isEmpty ? l.myFiles : _path.last.getStringValue('name');
    final folders = _folders;
    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: _path.isEmpty
              ? IconButton(
                  tooltip: l.cancel,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              : BackButton(onPressed: _up),
          title: Text(l.shareTitle),
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: AlcoveSpace.s2, bottom: AlcoveSpace.s4),
          children: [
            InsetGroup(
              title: l.shareFiles(files.length),
              children: [
                for (final f in files.take(4)) _SharedRow(file: f, locale: locale),
                if (files.length > 4)
                  Padding(
                    padding: const EdgeInsets.all(AlcoveSpace.s4),
                    child: Text(
                      l.shareMore(files.length - 4),
                      style: sansStyle(AlcoveFont.sizeSm, c.textMuted),
                    ),
                  ),
              ],
            ),
            SectionHeader(
              title: l.shareDestination,
              padding: const EdgeInsetsDirectional.fromSTEB(
                AlcoveSpace.s5,
                0,
                AlcoveSpace.s5,
                AlcoveSpace.s1,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AlcoveSpace.s5,
                0,
                AlcoveSpace.s5,
                AlcoveSpace.s3,
              ),
              child: Text(
                [l.myFiles, for (final p in _path) p.getStringValue('name')].join('  ›  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sansStyle(AlcoveFont.sizeSm, c.textMuted),
              ),
            ),
            if (_failed)
              EmptyState(
                icon: Icons.cloud_off_outlined,
                title: l.loadFailed,
                action: OutlinedButton(onPressed: _load, child: Text(l.retry)),
              )
            else if (folders == null)
              const Padding(
                padding: EdgeInsets.all(AlcoveSpace.s6),
                child: Center(child: LoadingIndicator()),
              )
            else if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s5),
                child: Text(l.noSubfolders, style: sansStyle(AlcoveFont.sizeSm, c.textMuted)),
              )
            else
              InsetGroup(
                children: [
                  for (final f in folders)
                    GroupTile(
                      icon: Icons.folder_rounded,
                      tint: c.accent,
                      title: f.getStringValue('name'),
                      onTap: () => _enter(f),
                    ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AlcoveSpace.s4),
            child: FilledButton.icon(
              key: const Key('shareHere'),
              onPressed: () => Navigator.pop<ShareDestination>(context, (
                folderId: _here,
                name: here,
              )),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(l.shareSendTo(here), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedRow extends StatelessWidget {
  const _SharedRow({required this.file, required this.locale});
  final SharedFile file;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, tint) = fileIcon(c, file.mime);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s3),
      child: Row(
        children: [
          TintedIcon(icon: icon, color: tint),
          const SizedBox(width: AlcoveSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sansStyle(AlcoveFont.sizeMd, c.text, AlcoveFont.medium),
                ),
                if (file.size > 0)
                  Text(
                    formatSize(file.size, locale),
                    style: sansStyle(AlcoveFont.sizeSm, c.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
