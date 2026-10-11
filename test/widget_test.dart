import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/celebration.dart';
import 'package:future_lift/clap_characters.dart';
import 'package:future_lift/main.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/residents.dart';
import 'package:future_lift/town.dart';

import 'progress_test.dart' show MemoryStore;

void main() {
  testWidgets('eight sprites clap in sequence and respect reduced motion', (
    tester,
  ) async {
    Future<void> show(double phase, {bool reduced = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ClapCharacters(phase: phase, reduced: reduced),
            ),
          ),
        ),
      );
    }

    int frame() => tester
        .widget<IndexedStack>(find.byKey(const ValueKey('clap-01_shiba')))
        .index!;

    await show(0);
    expect(find.byType(IndexedStack), findsNWidgets(8));
    expect(frame(), 0);
    await show(.25);
    expect(frame(), 1);
    await show(.5);
    expect(frame(), 2);
    await show(.75);
    expect(frame(), 1);
    await show(0, reduced: true);
    expect(
      tester
          .widgetList<IndexedStack>(find.byType(IndexedStack))
          .every((sprite) => sprite.index == 1),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(find.text('ミッション').last);
    await tester.pumpAndSettle();
    for (final mission in Mission.forPeriod(MissionPeriod.daily)) {
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
    expect(
      find.descendant(
        of: find.byType(Celebration),
        matching: find.text('社会貢献 +10'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Celebration),
        matching: find.byType(ClapCharacters),
      ),
      findsOneWidget,
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
    await tester.tap(find.text('ホーム').last);
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
    await tester.tap(find.text('ミッション').last);
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

  testWidgets('journal shows only celebrations and deletion preserves progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = Progress(
      day: '2026-10-09',
      lastCompletedDay: '2026-10-09',
      points: 30,
      completed: {Mission.strength},
      history: {
        '2026-09-30': {Mission.outside},
        '2026-10-09': {Mission.strength},
      },
    );
    final store = MemoryStore()..raw = saved.encode();
    final controller = await launch(tester, store);
    await tester.tap(find.text('履歴').last);
    await tester.pumpAndSettle();
    expect(find.text('これまで言祝がれた日々'), findsOneWidget);
    expect(find.text('直近30日は 2日、2個の行動を言祝ぎました。'),
        findsOneWidget);
    expect(find.text('今月は1日、1個の行動を言祝ぎました。'),
        findsOneWidget);
    expect(find.text('祝'), findsOneWidget);
    expect(find.text('×'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('previous-history-month')));
    await tester.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-day-30')));
    await tester.pumpAndSettle();
    expect(find.text('外に出た・歩いた'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-history-month')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clear-history')));
    await tester.pumpAndSettle();
    expect(find.text('すべての履歴を削除しますか？'), findsOneWidget);
    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();
    expect(controller.progress!.history.length, 2);

    await tester.tap(find.byKey(const ValueKey('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-clear-history')));
    await tester.pumpAndSettle();
    expect(controller.progress!.history, isEmpty);
    expect(controller.progress!.points, 30);
    expect(controller.progress!.completed, {Mission.strength});
    expect(Progress.decode(store.raw!).history, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('three mission periods can be selected and celebrated', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final controller = await launch(tester, store);
    await tester.tap(find.text('ミッション').last);
    await tester.pumpAndSettle();
    expect(find.text(Mission.movement.title), findsOneWidget);
    expect(find.text('いつもより身体を動かした'), findsNothing);
    expect(find.text('0/7 言祝ぎ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mission-tab-weekly')));
    await tester.pumpAndSettle();
    expect(find.text('0/4 言祝ぎ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('complete-weeklyStrength')), 160,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complete-weeklyStrength')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(Celebration), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-celebration')));
    await tester.pumpAndSettle();
    expect(controller.progress!.weeklyCompleted, {Mission.weeklyStrength});

    await tester.ensureVisible(find.byKey(const ValueKey('mission-tab-monthly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mission-tab-monthly')));
    await tester.pumpAndSettle();
    expect(find.text('0/3 言祝ぎ'), findsOneWidget);
    expect(find.text(Mission.monthlyReview.title), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('sixteen non-duplicate fixed tips are available', () {
    expect(Resident.values.expand((r) => r.tips).toSet().length, 16);
  });
}
