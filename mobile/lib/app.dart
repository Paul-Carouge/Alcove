import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/brand.dart';
import 'core/secure_store.dart';
import 'core/server_checker.dart';
import 'core/session.dart';
import 'core/version.dart';
import 'features/connect/connect_screen.dart';
import 'features/backup/backup_controller.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'theme/theme.dart';

class AlcoveApp extends StatefulWidget {
  const AlcoveApp({
    super.key,
    required this.checker,
    required this.store,
    this.session,
    this.backupFactory = BackupController.create,
  });

  final ServerChecker checker;
  final SecureStore store;

  /// Injected in tests.
  final Session? session;
  final BackupFactory backupFactory;

  @override
  State<AlcoveApp> createState() => _AlcoveAppState();
}

class _AlcoveAppState extends State<AlcoveApp> {
  late final Session _session = widget.session ?? Session(store: widget.store);
  bool _restored = false;
  bool _changingServer = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
    _session.restore().whenComplete(() {
      _wasSignedIn = _session.isSignedIn;
      if (mounted) setState(() => _restored = true);
    });
  }

  final _navigator = GlobalKey<NavigatorState>();
  bool _wasSignedIn = false;

  void _changed() {
    // Signed out (or the server changed): close what was opened above the home screen (account,
    // viewers, search), so the sign-in screen shows.
    final signedIn = _session.isSignedIn;
    if (_wasSignedIn && !signedIn) _navigator.currentState?.popUntil((r) => r.isFirst);
    _wasSignedIn = signedIn;
    setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    super.dispose();
  }

  Widget _home() {
    if (!_restored) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_session.hasServer || _changingServer) {
      return ConnectScreen(
        checker: widget.checker,
        store: widget.store,
        onConnected: (url) async {
          await _session.useServer(url);
          if (mounted) setState(() => _changingServer = false);
        },
      );
    }
    if (!_session.isSignedIn) {
      return LoginScreen(
        session: _session,
        onChangeServer: () => setState(() => _changingServer = true),
      );
    }
    return HomeScreen(session: _session, version: kAppVersion, backupFactory: widget.backupFactory);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: kProductName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _home(),
    );
  }
}
