import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/game_home.dart';
import 'package:future_lift/home_skin.dart';
import 'package:future_lift/progress.dart';

void main() {
  for (final size in <Size>[const Size(360, 720), const Size(680, 950)]) {
    testWidgets('home shows matching nameplate beside points at ${size.width}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final progress = Progress.empty(DateTime(2026, 10, 12));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHome(
              progress: progress,
              onMissions: () {},
              onTown: () {},
              onResident: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final profile = find.byKey(const ValueKey('gacha-player-nameplate'));
      final points = find.byKey(const ValueKey('kotohogi-bar-art'));
      expect(profile, findsOneWidget);
      expect(points, findsOneWidget);

      final image = tester.widget<Image>(profile);
      expect((image.image as AssetImage).assetName,
          'assets/kotohogi_hud/player_nameplate.png');
      expect(image.fit, BoxFit.contain);
      expect(find.text('今日も一歩ずつ'), findsOneWidget);
      expect(find.text('自分を言祝ごう'), findsOneWidget);
      expect(tester.widget<KotohogiBar>(find.byType(KotohogiBar)).points,
          progress.points);

      final nameRect = tester.getRect(profile);
      final pointRect = tester.getRect(points);
      expect(nameRect.right, lessThan(pointRect.left));
      expect((nameRect.width / nameRect.height), closeTo(788 / 209, .01));
      final title = find.text('FutureLift').first;
      expect(tester.getRect(title).top, greaterThan(nameRect.bottom));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });
  }
}
