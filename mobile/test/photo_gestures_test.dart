import 'package:alcove/features/photos/photo_viewer.dart';
import 'package:alcove/features/photos/photos_screen.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screenshots/fake_server.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('double tap zooms; dragging down closes, but not while zoomed', (tester) async {
    var dismissed = 0;
    final zooms = <bool>[];
    await tester.pumpWidget(
      _app(
        ZoomablePage(
          onDismiss: () => dismissed++,
          onZoomChanged: zooms.add,
          child: Container(width: 300, height: 200, color: Colors.teal),
        ),
      ),
    );
    final page = find.byType(ZoomablePage);
    final state = tester.state<ZoomablePageState>(page);

    // A short drag snaps back; a long one closes.
    await tester.drag(page, const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    await tester.drag(page, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(dismissed, 1);

    await tester.tap(page);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(page);
    await tester.pumpAndSettle();
    expect(state.transform.value.getMaxScaleOnAxis(), greaterThan(2));
    expect(zooms.last, isTrue);

    await tester.drag(page, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(dismissed, 1, reason: 'dragging a zoomed photo pans it');

    await tester.tap(page);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(page);
    await tester.pumpAndSettle();
    expect(state.transform.value.getMaxScaleOnAxis(), closeTo(1, 0.01));
  });

  testWidgets('pinching the grid changes the number of columns', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final session = (await tester.runAsync(fakeSession))!;
    await tester.pumpWidget(_app(PhotosScreen(session: session)));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    int columns() =>
        (tester.widget<SliverGrid>(find.byType(SliverGrid).first).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
    expect(columns(), 3);

    Future<void> pinch(double from, double to) async {
      final center = tester.getCenter(find.byType(PhotosScreen));
      final a = await tester.startGesture(center - Offset(from, 0), pointer: 1);
      final b = await tester.startGesture(center + Offset(from, 0), pointer: 2);
      for (var d = from; (to > from) ? d <= to : d >= to; d += (to - from) / 10) {
        await a.moveTo(center - Offset(d, 0));
        await b.moveTo(center + Offset(d, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pump();
    }

    await pinch(40, 120); // fingers apart: bigger photos
    expect(columns(), lessThan(3));
    await pinch(150, 30); // together: more columns
    expect(columns(), greaterThan(2));
  });
}
