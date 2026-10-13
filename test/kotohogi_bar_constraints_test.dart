import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/home_skin.dart';

void main() {
  testWidgets('kotohogi bar tolerates zero width then paints at full width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget screen(double width) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const KotohogiBar(points: 170),
              ),
            ),
          ),
        );

    await tester.pumpWidget(screen(0));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('kotohogi-bar-art')), findsNothing);

    await tester.pumpWidget(screen(130));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final art = find.byKey(const ValueKey('kotohogi-bar-art'));
    expect(art, findsOneWidget);
    expect(tester.getSize(art).width, 130);
    expect(tester.getSize(art).height, closeTo(130 * 314 / 982, .001));

    await tester.pumpWidget(screen(180));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(art).width, 180);
  });
}
