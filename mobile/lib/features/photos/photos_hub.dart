import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/tokens.g.dart';
import '../../ui/shell.dart';
import '../backup/backup_controller.dart';
import 'albums_screen.dart';
import 'photos_screen.dart';

/// The Photos destination: the timeline and the albums, one switch apart. Albums are only
/// loaded the first time they are shown.
class PhotosHub extends StatefulWidget {
  const PhotosHub({super.key, required this.session, this.backup, this.onOpenBackup});

  final Session session;
  final BackupController? backup;
  final VoidCallback? onOpenBackup;

  @override
  State<PhotosHub> createState() => _PhotosHubState();
}

enum PhotosView { library, albums }

class _PhotosHubState extends State<PhotosHub> {
  PhotosView _view = PhotosView.library;
  bool _albumsBuilt = false;

  Widget _switch(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AlcoveSpace.s4,
        AlcoveSpace.s1,
        AlcoveSpace.s4,
        AlcoveSpace.s2,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SegmentedSwitch<PhotosView>(
          value: _view,
          onChanged: (v) => setState(() {
            _view = v;
            if (v == PhotosView.albums) _albumsBuilt = true;
          }),
          segments: [
            (PhotosView.library, l.photosLibrary, const Key('photosLibrary')),
            (PhotosView.albums, l.albumsTitle, const Key('photosAlbums')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = _switch(context);
    // Android back on Albums returns to the library before leaving the app.
    return PopScope(
      canPop: _view == PhotosView.library,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _view = PhotosView.library);
      },
      child: IndexedStack(
        index: _view.index,
        children: [
          PhotosScreen(
            session: widget.session,
            backup: widget.backup,
            onOpenBackup: widget.onOpenBackup,
            header: header,
          ),
          if (_albumsBuilt)
            AlbumsScreen(session: widget.session, header: header)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
