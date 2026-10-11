import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/brand.dart';
import 'core/secure_store.dart';
import 'core/server_checker.dart';
import 'features/connect/connect_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'theme/theme.dart';

class AlcoveApp extends StatelessWidget {
  const AlcoveApp({super.key, required this.checker, required this.store});

  final ServerChecker checker;
  final SecureStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: ConnectScreen(checker: checker, store: store),
    );
  }
}
