import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/home_skin.dart';
import 'package:future_lift/gacha_hud.dart';

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
        // The amount remains accessible, without rendering a text label.
        expect(find.byKey(const ValueKey('kotohogi-bar-label')), findsNothing);
        expect(find.text('ことほぎ'), findsNothing);
        final bar = find.byType(KotohogiBar);
        expect(tester.getSize(bar).height, closeTo(width * 314 / 982, .01));

        final zoneRect = tester.getRect(zone);
        final numberRect = tester.getRect(number);
        expect(zoneRect.left, closeTo(width * .435, .01));
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

  testWidgets('hud shrinks only the balance bar and aligns it to the right',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 360, child: GachaHud(points: 190)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = find.byType(KotohogiBar);
    final nameplate = find.byType(PlayerNameplate);
    final rightSpace = (360 - GachaHud.horizontalGap) * GachaHud.balanceShare;
    final leftSpace = (360 - GachaHud.horizontalGap) * GachaHud.nameplateShare;
    expect(tester.getSize(bar).width,
        closeTo(rightSpace * GachaHud.kotohogiBarScale, .01));
    expect(tester.getSize(nameplate).width, closeTo(leftSpace, .01));
    expect(tester.getTopRight(bar).dx,
        closeTo(tester.getTopRight(find.byType(GachaHud)).dx, .01));
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-points'))).data,
        '190');
    expect(find.text('ことほぎ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mission balance frame is also 88 percent wide', (tester) async {
    tester.view.physicalSize = const Size(400, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 110,
            child: ContributionPanel(points: 120),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(KotohogiBar)).width,
        closeTo(360 * .88, .01));
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-points'))).data,
        '120');
    expect(find.byKey(const ValueKey('kotohogi-bar-label')), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
