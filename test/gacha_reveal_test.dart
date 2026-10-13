import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/consultation_scene.dart';
import 'package:future_lift/gacha_reveal.dart';
import 'package:future_lift/gacha_screen.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/resident_gacha.dart';

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
    final backSprite = (second.image as AssetImage).assetName;
    expect(backSprite, isNot(firstAsset));
    expect(backSprite, contains('/walk_back_'));
    final walker = tester.getRect(
      find.byKey(const ValueKey('consultation-walker-0')),
    );
    expect(walker.height, greaterThan(60));
    expect(walker.top, lessThan(320));
    expect(walker.bottom, lessThan(400));
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
    final stageResident = tester.getRect(
      find.byKey(const ValueKey('gacha-stage-resident')),
    );
    expect(stageResident.height, greaterThan(120));
    // Feet remain on the blue stage instead of dropping below its front edge.
    expect(stageResident.bottom, inInclusiveRange(360, 420));
    expect(find.byKey(const ValueKey('resident-arrival-banner')),
        findsOneWidget);
    final arrival = tester.widget<Image>(
      find.byKey(const ValueKey('resident-arrival-banner')),
    );
    expect(
      (arrival.image as AssetImage).assetName,
      'assets/gacya/resident_arrival_banner.png',
    );
    expect(find.text('ペンギンが、まちにやってきました！'),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('gacha-banner-resident-name')),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('resident-arrival-banner')))
          .width,
      greaterThan(200),
    );
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
    // A returning resident still gets the arrival panel, with the reunion
    // badge added separately. Repeated draws must not silently omit it.
    expect(find.byKey(const ValueKey('resident-arrival-banner')),
        findsOneWidget);
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('gacha-banner-resident-name')),
      ).data,
      'ペンギン',
    );
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

  testWidgets('welcome button draws exactly once and starts the reveal',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore()..raw = funded(points: 60).encode();
    final controller = ProgressController(
      store,
      clock: () => DateTime(2026, 10, 11),
      random: FixedRandom(2),
    );
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResidentGacha(controller: controller),
        ),
      ),
    ));
    await tester.ensureVisible(find.byKey(const ValueKey('draw-resident')));
    await tester.tap(find.byKey(const ValueKey('draw-resident')));
    await tester.pumpAndSettle();
    expect(find.byType(GachaReveal), findsOneWidget);
    expect(find.byKey(const ValueKey('resident-arrival-banner')),
        findsOneWidget);
    expect(controller.progress!.residents.counts['03_penguin'], 1);
    expect(store.writes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('welcome requires enough kotohogi before starting a draw',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final controller = ProgressController(
      store,
      clock: () => DateTime(2026, 10, 11),
      random: FixedRandom(2),
    );
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResidentGacha(controller: controller),
        ),
      ),
    ));
    final welcome = tester.widget<TextButton>(
      find.byKey(const ValueKey('draw-resident')),
    );
    expect(welcome.onPressed, isNull);
    expect(store.writes, 0);
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
