import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/gacha_hud.dart';
import 'package:future_lift/home_skin.dart';

void main() {
  for (final width in <double>[296, 340, 550]) {
    testWidgets('HUD has no ticket counter and gives balance room at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width + 20, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: const GachaHud(points: 999)),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final bar = find.byType(KotohogiBar);
      final art = find.byKey(const ValueKey('kotohogi-bar-art'));
      final name = find.byKey(const ValueKey('gacha-player-nameplate'));
      final value = find.byKey(const ValueKey('total-points'));

      expect(bar, findsOneWidget);
      expect(art, findsOneWidget);
      expect(name, findsOneWidget);
      expect(tester.widget<Text>(value).data, '999');
      expect(find.byKey(const ValueKey('kotohogi-bar-label')), findsOneWidget);
      expect(find.byTooltip('ガチャ券'), findsNothing);
      expect(find.textContaining('ガチャ券'), findsNothing);
      final available = width - GachaHud.horizontalGap;
      expect(tester.getSize(name).width,
          closeTo(available * GachaHud.nameplateShare, .02));
      expect(tester.getSize(bar).width,
          closeTo(available * GachaHud.balanceShare, .02));
      expect(tester.getSize(bar).width, greaterThan(tester.getSize(name).width));
      expect(tester.getRect(name).right, lessThan(tester.getRect(bar).left));
      expect(tester.getSize(bar).height,
          closeTo(tester.getSize(bar).width * 314 / 982, .01));
      expect(tester.getRect(value).right,
          lessThanOrEqualTo(tester.getRect(bar).right + 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the kotohogi amount updates without a ticket badge',
      (tester) async {
    Widget hud(int amount) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: GachaHud(points: amount),
        ),
      ),
    );
    await tester.pumpWidget(hud(60));
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('total-points')),
    ).data, '60');
    await tester.pumpWidget(hud(30));
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('total-points')),
    ).data, '30');
    expect(find.textContaining('ガチャ券'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
