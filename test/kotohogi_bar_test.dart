import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/home_skin.dart';

void main() {
  for (final width in <double>[105, 120, 160, 290]) {
    testWidgets('number is legible in the red right-hand area at $width dp',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> pumpWith(int amount) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: KotohogiBar(points: amount)),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }

      for (final balance in <int>[0, 30, 270, 1250, 100000]) {
        await pumpWith(balance);
        final number = find.byKey(const ValueKey('total-points'));
        final zone = find.byKey(const ValueKey('kotohogi-number-zone'));
        expect(number, findsOneWidget);
        expect(zone, findsOneWidget);
        final numericText = tester.widget<Text>(number);
        expect(numericText.data, '$balance');
        expect(numericText.style!.fontSize, 41);
        expect(numericText.style!.fontWeight, FontWeight.w900);
        expect(numericText.style!.color, const Color(0xFFFFF0C9));
        expect(find.bySemanticsLabel('ことほぎ $balance'), findsOneWidget);
        expect(find.byKey(const ValueKey('kotohogi-bar-label')), findsOneWidget);
        expect(tester.widget<Text>(
          find.byKey(const ValueKey('kotohogi-bar-label')),
        ).data, 'ことほぎ');
        final bar = find.byType(KotohogiBar);
        expect(tester.getSize(bar).height, closeTo(width * 314 / 982, .01));

        final zoneRect = tester.getRect(zone);
        final numberRect = tester.getRect(number);
        expect(zoneRect.left, greaterThan(width * .59));
        expect(zoneRect.top, closeTo(width * 314 / 982 * .28, .01));
        expect(zoneRect.right, lessThan(width * .90));
        expect(numberRect.width, greaterThan(0));
        expect(numberRect.height, greaterThan(0));
        expect(numberRect.left, greaterThanOrEqualTo(zoneRect.left - .5));
        expect(numberRect.right, lessThanOrEqualTo(zoneRect.right + .5));
        expect(numberRect.top, greaterThanOrEqualTo(zoneRect.top - .5));
        expect(numberRect.bottom, lessThanOrEqualTo(zoneRect.bottom + .5));
        expect(tester.takeException(), isNull);
      }

      // The old + icon masking circle must not be drawn over the asset.
      expect(find.descendant(
        of: find.byType(KotohogiBar),
        matching: find.byType(DecoratedBox),
      ), findsNothing);
    });
  }

  testWidgets('kotohogi bar displays actual balance on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> show(int amount) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 290, child: KotohogiBar(points: amount)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(0);
    final art = tester.widget<Image>(find.byKey(const ValueKey('kotohogi-bar-art')));
    expect((art.image as AssetImage).assetName, 'assets/kotohogi_hud/kotohogi_bar.png');
    expect(find.bySemanticsLabel('ことほぎ 0'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-points'))).data, '0');
    expect(tester.takeException(), isNull);

    await show(120);
    expect(find.bySemanticsLabel('ことほぎ 120'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-points'))).data, '120');
    expect(tester.takeException(), isNull);
  });
}
