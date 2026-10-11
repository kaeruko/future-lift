import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/main.dart';
import 'package:future_lift/gacha_reveal.dart';
import 'package:future_lift/progress.dart';

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
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(reduced ? 1.8 : 1),
          ),
          child: child!,
        ),
        home: FutureLiftHome(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('みんなのまち').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('draw-resident')),
      200,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('draw-resident'))),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    final draw = tester.widget<TextButton>(
      find.byKey(const ValueKey('draw-resident')),
    );
    expect(draw.onPressed, isNotNull);
    final art = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('draw-resident')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (art.image as AssetImage).assetName,
      'assets/gacya/button_resident.png',
    );
    await tester.tap(find.byKey(const ValueKey('draw-resident')));
    await tester.pump();
    await tester.pump();
    return controller;
  }

  testWidgets('closed scroll, reveal, duplicate repeat and empty tickets', (
    tester,
  ) async {
    final store = MemoryStore()..raw = funded(points: 60).encode();
    final controller = await open(tester, store);
    expect(find.byType(GachaReveal), findsOneWidget);
    expect(find.byKey(const ValueKey('gacha-result')), findsNothing);
    expect(store.writes, 1);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(const ValueKey('gacha-result')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('NEW'), findsOneWidget);
    expect(find.byKey(const ValueKey('resident-name')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('button_again')));
    await tester.tap(find.byKey(const ValueKey('button_again')));
    await tester.pump();
    expect(store.writes, 2);
    expect(find.byKey(const ValueKey('button_again')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('また会えた'), findsOneWidget);
    expect(controller.progress!.residents.counts['03_penguin'], 2);
    expect(controller.progress!.residents.owned.length, 3);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('button_again')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'repeat saving is locked and failure exposes original diagnostics',
    (tester) async {
      final store = MemoryStore()..raw = funded(points: 90).encode();
      final controller = await open(tester, store);
      await tester.pumpAndSettle();
      store.gate = Completer<void>();
      final error = StateError('gacha disk full');
      store.saveError = error;
      await tester.ensureVisible(find.byKey(const ValueKey('button_again')));
      await tester.tap(find.byKey(const ValueKey('button_again')));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('button_again')))
            .onPressed,
        isNull,
      );
      expect(store.writes, 2);
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GachaReveal), findsNothing);
      expect(controller.failure!.error, same(error));
      await tester.tap(find.text('診断情報'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              (w.data?.contains('gacha disk full') ?? false),
        ),
        findsOneWidget,
      );
      expect(controller.progress!.residents.counts['03_penguin'], 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'large text and reduced motion show usable result on compact screen',
    (tester) async {
      final store = MemoryStore()..raw = funded().encode();
      await open(tester, store, reduced: true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gacha-result')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('button_town')));
      await tester.tap(find.byKey(const ValueKey('button_town')));
      await tester.pumpAndSettle();
      expect(find.byType(GachaReveal), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
