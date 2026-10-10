import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/celebration.dart';
import 'package:future_lift/main.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/residents.dart';
import 'package:future_lift/town.dart';

import 'progress_test.dart' show MemoryStore;

void main() {
  Future<ProgressController> launch(
    WidgetTester tester,
    MemoryStore store,
  ) async {
    final controller = ProgressController(
      store,
      clock: () => DateTime(2026, 10, 9, 12),
    );
    await tester.pumpWidget(FutureLiftApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('core journey: missions, celebration, +10, town, tip, restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.reset());
    final store = MemoryStore();
    final controller = await launch(tester, store);
    for (final mission in Mission.values) {
      await tester.scrollUntilVisible(find.text(mission.title), 200);
      expect(find.text(mission.title), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('complete-strength')),
      -250,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complete-strength')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('ありがとう！'), findsOneWidget);
    expect(find.text('社会貢献 +10'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Celebration),
        matching: find.byType(ResidentAvatar),
      ),
      findsNWidgets(4),
    );
    expect(controller.progress!.points, 10);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('close-celebration')));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('complete-strength')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('できた！  達成済み'), findsOneWidget);
    await tester.tap(find.text('今日のミッション').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('open-missions')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('みんなのまち').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TownScene>(find.byType(TownScene)).level, 0);
    await tester.tap(find.byKey(const ValueKey('resident-0')));
    await tester.pumpAndSettle();
    expect(find.text(Resident.child.tips.first), findsOneWidget);
    await tester.tap(find.text('また話そう'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resident-0')));
    await tester.pumpAndSettle();
    expect(find.text(Resident.child.tips[1]), findsOneWidget);
    await tester.tap(find.text('また話そう'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    final restarted = await launch(tester, store);
    expect(restarted.progress!.completed, {Mission.strength});
    expect(restarted.progress!.points, 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'storage failure displays halt and original diagnostics, no celebration',
    (tester) async {
      await launch(tester, MemoryStore()..saveError = StateError('disk full'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('open-missions')),
        150,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-missions')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('complete-strength')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('complete-strength')));
      await tester.pumpAndSettle();
      expect(find.text('記録を確認できないため、停止しました'), findsOneWidget);
      expect(find.byType(Celebration), findsNothing);
      await tester.tap(find.text('診断情報'));
      await tester.pumpAndSettle();
      expect(find.textContaining('disk full'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('compact screen, large text and reduced motion remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ProgressController(
      MemoryStore(),
      clock: () => DateTime(2026, 10, 9),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: FutureLiftHome(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('complete-strength')),
      150,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complete-strength')));
    await tester.pumpAndSettle();
    expect(find.byType(Celebration), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('close-celebration')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('close-celebration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('みんなのまち').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('resident-0')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resident-0')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('sixteen non-duplicate fixed tips are available', () {
    expect(Resident.values.expand((r) => r.tips).toSet().length, 16);
  });
}
