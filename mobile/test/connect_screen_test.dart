import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/server_checker.dart';
import 'package:alcove/features/connect/connect_screen.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget app(ServerChecker checker, {Locale locale = const Locale('en')}) {
  FlutterSecureStorage.setMockInitialValues({});
  return MaterialApp(
    theme: buildTheme(Brightness.light),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ConnectScreen(checker: checker, store: SecureStore(), allowInsecure: false),
  );
}

final okChecker = ServerChecker(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'status': 'ok',
        'name': 'Alcove',
        'version': '0.1.0',
        'api': {'min': 1, 'max': 1},
        'modules': ['core'],
        'setupRequired': false,
      }),
      200,
    ),
  ),
);

void main() {
  testWidgets('shows a validation error for http URLs', (tester) async {
    await tester.pumpWidget(app(okChecker));
    await tester.enterText(find.byKey(const Key('serverUrl')), 'http://cloud.example.com');
    await tester.tap(find.byKey(const Key('checkButton')));
    await tester.pumpAndSettle();
    expect(find.text('Only HTTPS addresses are allowed.'), findsOneWidget);
  });

  testWidgets('connects to a compatible server', (tester) async {
    await tester.pumpWidget(app(okChecker));
    await tester.enterText(find.byKey(const Key('serverUrl')), 'cloud.example.com');
    await tester.tap(find.byKey(const Key('checkButton')));
    await tester.pumpAndSettle();
    expect(find.text('Connected to Alcove 0.1.0'), findsOneWidget);
  });

  testWidgets('is translated to French', (tester) async {
    await tester.pumpWidget(app(okChecker, locale: const Locale('fr')));
    await tester.pumpAndSettle();
    expect(find.text('Connexion au serveur'), findsOneWidget);
  });

  testWidgets('meets tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(okChecker));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
