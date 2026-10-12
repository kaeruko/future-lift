import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/home_skin.dart';

void main() {
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
