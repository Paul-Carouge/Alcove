import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../account/account_screen.dart';
import '../backup/backup_controller.dart';
import '../backup/backup_screen.dart';
import '../files/files_screen.dart';
import '../photos/photos_screen.dart';

typedef BackupFactory = Future<BackupController> Function(Session session);

/// The signed-in app: Photos, Files and Account tabs. Photo backup runs when the app opens or comes
/// back to the foreground (and in the background on Android).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.version,
    this.backupFactory = BackupController.create,
  });

  final Session session;
  final String version;
  final BackupFactory backupFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  BackupController? _backup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget
        .backupFactory(widget.session)
        .then((c) {
          if (!mounted) return;
          setState(() => _backup = c);
          _autoBackup();
        })
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoBackup();
  }

  void _autoBackup() {
    final c = _backup;
    if (c != null && c.state.enabled && !c.running) unawaited(c.runNow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backup?.cancel();
    super.dispose();
  }

  void _openBackup() {
    final c = _backup;
    if (c == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => BackupScreen(controller: c)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          SafeArea(
            bottom: false,
            child: PhotosScreen(
              session: widget.session,
              backup: _backup,
              onOpenBackup: _openBackup,
            ),
          ),
          // Each tab keeps its own navigation stack (folders).
          Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => FilesScreen(session: widget.session)),
          ),
          AccountScreen(
            session: widget.session,
            version: widget.version,
            backup: _backup,
            onOpenBackup: _openBackup,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library),
            label: l.tabPhotos,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: l.tabFiles,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l.tabAccount,
          ),
        ],
      ),
    );
  }
}
