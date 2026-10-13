import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/gacha_hud.dart';
import 'package:future_lift/home_skin.dart';

void main() {
  for (final width in <double>[320, 402, 570]) {
    testWidgets('pinned HUD has a single large currency bar at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colors.amber)),
                  PinnedGachaHud(
                    points: 999,
                    contentBuilder: (context, remaining) => ListView(
                      children: [
                        Text('Content ${remaining.toStringAsFixed(0)}px'),
                        const SizedBox(height: 1100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PinnedGachaHud)), Size(width, 720));
      final name = find.byKey(const ValueKey('gacha-player-nameplate'));
      final bar = find.byType(KotohogiBar);
      expect(name, findsOneWidget);
      expect(bar, findsOneWidget);
      expect(find.byKey(const ValueKey('total-points')), findsOneWidget);
      expect(find.textContaining('ガチャ券'), findsNothing);
      final contentWidth = width - PinnedGachaHud.edge * 2 -
          GachaHud.horizontalGap;
      expect(tester.getSize(bar).width,
          closeTo(contentWidth * GachaHud.balanceShare, .02));
      expect(tester.getSize(name).width,
          closeTo(contentWidth * GachaHud.nameplateShare, .02));
      expect(tester.getRect(name).right, lessThan(tester.getRect(bar).left));
      expect(tester.getSize(bar).height,
          closeTo(tester.getSize(bar).width * 314 / 982, .02));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('currency bar stays pinned while content scrolls at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> build(int amount) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PinnedGachaHud(
              points: amount,
              contentBuilder: (context, height) => ListView(
                key: const ValueKey('scene-scroll'),
                children: [
                  const SizedBox(height: 1200),
                  Text('Remaining height ${height.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
        ));
      }

      await build(80);
      final name = find.byKey(const ValueKey('gacha-player-nameplate'));
      final art = find.byKey(const ValueKey('kotohogi-bar-art'));
      final digit = find.byKey(const ValueKey('total-points'));
      final oldNameRect = tester.getRect(name);
      final oldArtRect = tester.getRect(art);
      expect(tester.widget<Text>(digit).data, '80');
      await tester.drag(find.byKey(const ValueKey('scene-scroll')),
          const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(tester.getRect(name), oldNameRect);
      expect(tester.getRect(art), oldArtRect);
      await build(999);
      expect(tester.getRect(art), oldArtRect);
      expect(tester.widget<Text>(digit).data, '999');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
