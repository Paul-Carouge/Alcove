// Renders app screens to PNG files for design review (not part of the regular test run):
//   SCREENSHOTS=/tmp/shots flutter test test/screenshots
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:alcove/ui/remote_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final shotsDir = Platform.environment['SCREENSHOTS'];
final skipShots = shotsDir == null ? 'SCREENSHOTS not set' : false;

const _fixtures = '../web/e2e/fixtures';
final _pictures = [
  for (final f in ['harbor.jpg', 'lyon.jpg', 'winter.jpg', 'scan.jpg'])
    File('$_fixtures/$f').readAsBytesSync(),
];

Future<void> loadFonts() async {
  final inter = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
  await inter.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
  // Every server image becomes one of the test pictures (stable per URL).
  alcoveImageProvider = (url) =>
      MemoryImage(_pictures[url.toString().hashCode.abs() % _pictures.length]);
}

final _boundary = GlobalKey();

Widget phone(
  Widget home, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('fr'),
}) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Future<void> setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> shoot(WidgetTester tester, String name) async {
  // Let images decode and animations finish.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.runAsync(() async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
