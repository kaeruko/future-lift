import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/consultation_scene.dart';
import 'package:future_lift/gacha_reveal.dart';
import 'package:future_lift/gacha_screen.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/resident_collection.dart';

import 'progress_test.dart' show MemoryStore;
import 'resident_collection_test.dart' show funded, FixedRandom;

void main() {
  Future<ProgressController> open(
    WidgetTester tester,
    MemoryStore store, {
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ProgressController(
      store,
      clock: () => DateTime(2026, 10, 11),
      random: FixedRandom(2),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: GachaScreen(controller: controller),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('hall shows animated walkers and the new two art buttons',
      (tester) async {
    final controller = await open(
      tester,
      MemoryStore()..raw = funded(points: 60).encode(),
    );
    expect(find.byKey(const ValueKey('gacha-shrine-bg')), findsOneWidget);
    expect(find.byType(ConsultationBackground), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      expect(find.byKey(ValueKey('consultation-walker-$index')),
          findsOneWidget);
    }
    expect(find.byKey(const ValueKey('gacha-draw-one')), findsOneWidget);
    expect(find.byKey(const ValueKey('resident-list-button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('gacha-draw-ten')), findsNothing);
    expect(find.text('開催費：30ことほぎ'), findsOneWidget);
    expect(controller.progress!.residents.availableKotohogi(60), 60);

    final first = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('consultation-walker-0')),
        matching: find.byType(Image),
      ),
    );
    final firstAsset = (first.image as AssetImage).assetName;
    await tester.pump(const Duration(milliseconds: 170));
    final second = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('consultation-walker-0')),
        matching: find.byType(Image),
      ),
    );
    expect((second.image as AssetImage).assetName, isNot(firstAsset));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resident steps onto stage, arrival banner, repeat, list',
      (tester) async {
    final store = MemoryStore()..raw = funded(points: 60).encode();
    final controller = await open(tester, store);
    await tester.tap(find.byKey(const ValueKey('gacha-draw-one')));
    await tester.pumpAndSettle();

    expect(find.byType(GachaReveal), findsOneWidget);
    expect(find.byKey(const ValueKey('gacha-reveal-glow')), findsOneWidget);
    expect(find.byKey(const ValueKey('gacha-stage-resident')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('resident-arrival-banner')),
        findsOneWidget);
    expect(find.text('ペンギンが、まちにやってきました！'),
        findsOneWidget);
    expect(store.writes, 1);
    expect(controller.progress!.residents.availableKotohogi(60), 30);

    await tester.tap(find.byKey(const ValueKey('resident-list-button')));
    await tester.pumpAndSettle();
    expect(find.text('住民一覧'), findsOneWidget);
    expect(find.text('ペンギン'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('button_again')));
    await tester.pumpAndSettle();
    expect(find.text('ペンギンとまた出会いました！'), findsOneWidget);
    expect(find.byKey(const ValueKey('gacha-reunion-badge')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('resident-arrival-banner')),
        findsNothing);
    expect(controller.progress!.residents.counts['03_penguin'], 2);
    expect(controller.progress!.residents.availableKotohogi(60), 0);
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('button_again')))
          .onPressed,
      isNull,
    );
    expect(store.writes, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('saving blocks another draw until the first finishes',
      (tester) async {
    final store = MemoryStore()..raw = funded(points: 60).encode();
    await open(tester, store);
    store.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('gacha-draw-one')));
    await tester.pump();
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('gacha-draw-one')))
          .onPressed,
      isNull,
    );
    expect(store.writes, 1);
    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(GachaReveal), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion shows the completed result immediately',
      (tester) async {
    await open(
      tester,
      MemoryStore()..raw = funded().encode(),
      reduced: true,
    );
    await tester.tap(find.byKey(const ValueKey('gacha-draw-one')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gacha-result')), findsOneWidget);
    expect(find.byKey(const ValueKey('resident-arrival-banner')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
