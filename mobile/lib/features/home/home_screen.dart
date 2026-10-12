import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../account/account_screen.dart';
import '../files/files_screen.dart';
import '../photos/photos_screen.dart';

/// The signed-in app: Photos, Files and Account tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session, required this.version});

  final Session session;
  final String version;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          SafeArea(bottom: false, child: PhotosScreen(session: widget.session)),
          // Each tab keeps its own navigation stack (folders).
          Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => FilesScreen(session: widget.session)),
          ),
          AccountScreen(session: widget.session, version: widget.version),
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
