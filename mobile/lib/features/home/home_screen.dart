import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/app_update.dart';
import '../../core/drive.dart';
import '../../core/file_cache.dart';
import '../../core/session.dart';
import '../../core/share_inbox.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/shell.dart';
import '../account/account_screen.dart';
import '../backup/backup_controller.dart';
import '../backup/backup_screen.dart';
import '../calendar/calendar_screen.dart';
import '../documents/documents_screen.dart';
import '../files/files_screen.dart';
import '../notes/notes_screen.dart';
import '../photos/photos_hub.dart';
import '../search/search_screen.dart';
import '../share/share_screen.dart';

typedef BackupFactory = Future<BackupController> Function(Session session);

/// The destinations of the floating navigation bar, in order.
enum HomeTab { photos, files, documents, notes, calendar }

/// The signed-in app: Photos (with albums), Files, Documents, Notes and Calendar in a floating
/// navigation bar; search and the account page from the top bar of each screen. Photo backup runs
/// when the app opens or comes back to the foreground (and in the background on Android).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.version,
    this.backupFactory = BackupController.create,
    this.shareInbox,
  });

  final Session session;
  final String version;
  final BackupFactory backupFactory;

  /// Files shared to the app from other apps (Android); a default one when null.
  final ShareInbox? shareInbox;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  HomeTab _tab = HomeTab.photos;

  /// Tabs are built on their first visit: fewer requests at start-up, and Notes / Calendar only
  /// hold their realtime streams once opened.
  final Set<HomeTab> _visited = {HomeTab.photos};
  bool _barVisible = true;
  BackupController? _backup;
  late final AppUpdater _updater = AppUpdater(session: widget.session);
  late final UploadQueue _uploads = UploadQueue(widget.session);
  late final ShareInbox _inbox = widget.shareInbox ?? ShareInbox();
  StreamSubscription<List<SharedFile>>? _shares;
  bool _uploadsWereActive = false;

  final _navigators = {for (final t in HomeTab.values) t: GlobalKey<NavigatorState>()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_updater.check());
    // Files left unsent when the app was closed.
    unawaited(_uploads.restore());
    _uploads.addListener(_uploadsChanged);
    // Files opened in the viewers are cached for a while; old ones go.
    unawaited(FileCache.instance.prune());
    widget
        .backupFactory(widget.session)
        .then((c) {
          if (!mounted) return;
          setState(() => _backup = c);
          _autoBackup();
        })
        .catchError((Object _) {});
    _shares = _inbox.incoming.listen(_received);
    unawaited(_inbox.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.session.refreshIfStale());
      _autoBackup();
      unawaited(_updater.check());
    }
  }

  void _autoBackup() {
    final c = _backup;
    if (c != null && c.state.enabled && !c.running) unawaited(c.runNow());
  }

  /// A light tap when every file sent from the phone has arrived.
  void _uploadsChanged() {
    final active = _uploads.active;
    if (_uploadsWereActive && !active && _uploads.failedCount == 0 && _uploads.finished > 0) {
      HapticFeedback.lightImpact();
    }
    _uploadsWereActive = active;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_shares?.cancel());
    _inbox.dispose();
    _backup?.cancel();
    _updater.dispose();
    _uploads
      ..removeListener(_uploadsChanged)
      ..dispose();
    super.dispose();
  }

  NavigatorState get _root => Navigator.of(context, rootNavigator: true);

  void _openBackup() {
    final c = _backup;
    if (c == null) return;
    _root.push(MaterialPageRoute<void>(builder: (_) => BackupScreen(controller: c)));
  }

  void _openAccount() {
    _root.push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: context.colors.bg,
          body: AccountScreen(
            session: widget.session,
            version: widget.version,
            backup: _backup,
            onOpenBackup: _openBackup,
            updater: _updater,
          ),
        ),
      ),
    );
  }

  void _openSearch() {
    _root.push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(session: widget.session, uploads: _uploads),
      ),
    );
  }

  /// Files shared from another app: choose a folder, then they join the upload queue.
  Future<void> _received(List<SharedFile> files) async {
    if (files.isEmpty || !mounted) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await _root.push<ShareDestination>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ShareScreen(session: widget.session, files: files),
      ),
    );
    if (!mounted) return;
    if (picked == null) {
      unawaited(_inbox.discard(files));
      return;
    }
    _uploads.add(sharedUploads(files, picked.folderId));
    _select(HomeTab.files);
    messenger.showSnackBar(SnackBar(content: Text(l.shareQueued(files.length, picked.name))));
  }

  void _select(HomeTab tab) {
    if (tab == _tab) {
      // Tapping the current destination again goes back to its first screen.
      _navigators[tab]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _tab = tab;
      _visited.add(tab);
      _barVisible = true;
    });
  }

  /// Brings the bar back (after a push or pop, or on a screen too short to scroll). Deferred to
  /// after the frame: navigators report pushes while they build.
  void _showBar() {
    if (_barVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_barVisible) setState(() => _barVisible = true);
    });
  }

  // One per navigator (an observer can only watch one).
  late final _tabObservers = {for (final t in HomeTab.values) t: _TabObserver(_showBar)};

  /// The bar steps aside while reading down a list and comes back when scrolling up, or when the
  /// screen has nothing to scroll (it could never be brought back otherwise).
  bool _onNotification(Notification n) {
    if (n is ScrollMetricsNotification &&
        n.depth == 0 &&
        n.metrics.axis == Axis.vertical &&
        n.metrics.maxScrollExtent <= 0) {
      _showBar();
      return false;
    }
    return n is ScrollNotification ? _onScroll(n) : false;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    bool? show;
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) show = false;
      if (n.direction == ScrollDirection.forward) show = true;
    }
    if (n is ScrollUpdateNotification && n.metrics.pixels <= n.metrics.minScrollExtent) {
      show = true;
    }
    if (show != null && show != _barVisible) setState(() => _barVisible = show!);
    return false;
  }

  /// A tab with its own navigation stack. The system back button goes back inside the visible
  /// tab first (and through the screens' own back handling, e.g. the note editor saving).
  Widget _tabNavigator(HomeTab tab, WidgetBuilder root) => NavigatorPopHandler<Object?>(
    enabled: _tab == tab,
    onPopWithResult: (_) => _navigators[tab]!.currentState?.maybePop(),
    child: Navigator(
      key: _navigators[tab],
      observers: [_tabObservers[tab]!],
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: root),
    ),
  );

  Widget _build(HomeTab tab) {
    if (!_visited.contains(tab)) return const SizedBox.shrink();
    return switch (tab) {
      HomeTab.photos => _tabNavigator(
        tab,
        (_) => PhotosHub(session: widget.session, backup: _backup, onOpenBackup: _openBackup),
      ),
      HomeTab.files => _tabNavigator(
        tab,
        (_) => FilesScreen(session: widget.session, uploads: _uploads),
      ),
      HomeTab.documents => _tabNavigator(
        tab,
        (_) => DocumentsScreen(session: widget.session, uploads: _uploads),
      ),
      HomeTab.notes => _tabNavigator(tab, (_) => NotesScreen(session: widget.session)),
      HomeTab.calendar => _tabNavigator(tab, (_) => CalendarScreen(session: widget.session)),
    };
  }

  List<NavItem> _items(AppLocalizations l) => [
    NavItem(
      key: const Key('tabPhotos'),
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      label: l.tabPhotos,
    ),
    NavItem(
      key: const Key('tabFiles'),
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: l.tabFiles,
    ),
    NavItem(
      key: const Key('tabDocuments'),
      icon: Icons.article_outlined,
      selectedIcon: Icons.article,
      label: l.tabDocuments,
    ),
    NavItem(
      key: const Key('tabNotes'),
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
      label: l.tabNotes,
    ),
    NavItem(
      key: const Key('tabCalendar'),
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: l.tabCalendar,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 0;
    final barBottom = media.padding.bottom + AlcoveSpace.s2;
    // The content scrolls under the bar; this much room at the end keeps its last item reachable
    // and lifts the FABs above the bar.
    final inset = keyboard ? 0.0 : barBottom + FloatingNavBar.height + AlcoveSpace.s3;
    final visible = _barVisible && !keyboard;
    final duration = AlcoveSprings.of(context, AlcoveSprings.medium);
    return AppShell(
      session: widget.session,
      onSearch: _openSearch,
      onAccount: _openAccount,
      updater: _updater,
      child: Scaffold(
        backgroundColor: context.colors.bg,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(bottom: inset),
                  viewPadding: media.viewPadding.copyWith(
                    bottom: keyboard ? media.viewPadding.bottom : inset,
                  ),
                ),
                child: NotificationListener<Notification>(
                  onNotification: _onNotification,
                  child: IndexedStack(
                    index: _tab.index,
                    children: [for (final t in HomeTab.values) _build(t)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AlcoveSpace.s3,
              right: AlcoveSpace.s3,
              bottom: barBottom,
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(0, 1.6),
                  duration: duration,
                  curve: AlcoveSprings.spatial,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: duration,
                    child: Center(
                      child: FloatingNavBar(
                        key: const Key('floatingNav'),
                        items: _items(l),
                        selected: _tab.index,
                        onSelected: (i) => _select(HomeTab.values[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells the shell about every push and pop inside a tab (the new screen may not scroll).
class _TabObserver extends NavigatorObserver {
  _TabObserver(this.onChange);
  final VoidCallback onChange;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => onChange();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => onChange();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => onChange();
}
