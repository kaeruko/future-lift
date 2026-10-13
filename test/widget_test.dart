import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/celebration.dart';
import 'package:future_lift/clap_characters.dart';
import 'package:future_lift/main.dart';
import 'package:future_lift/dialogue_engine.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/residents.dart';
import 'package:future_lift/town.dart';

import 'progress_test.dart' show MemoryStore;

void main() {
  test('all confetti particles fall completely past the screen by the end', () {
    // Use the same deterministic random stream and particle timing as the painter.
    final random = math.Random(31);
    const height = 900.0;
    for (var i = 0; i < 110; i++) {
      random.nextDouble(); // start X
      final delay = random.nextDouble() * .38;
      final exponent = .7 + random.nextDouble() * .65;
      random.nextDouble(); // horizontal drift

      expect(confettiFallFraction(0, delay, exponent), 0);
      expect(confettiFallY(0, delay, exponent, height), -30);
      var previous = -30.0;
      for (var step = 1; step <= 100; step++) {
        final y = confettiFallY(step / 100, delay, exponent, height);
        expect(
          y,
          greaterThanOrEqualTo(previous),
          reason: 'Particle $i at $step%',
        );
        previous = y;
      }
      expect(confettiFallFraction(.99, delay, exponent), lessThan(1));
      expect(confettiFallFraction(1, delay, exponent), 1);
      // The painter culls particles beyond height + 35.
      expect(
        confettiFallY(1, delay, exponent, height),
        greaterThan(height + 35),
        reason: 'Particle $i stayed visible',
      );
    }
  });

  testWidgets('researched cost illustration accompanies applause', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      const MaterialApp(
        home: Celebration(
          missionTitle: '筋力を使った',
          total: 10,
          residents: [],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.text('🎊 日本の社会保障に貢献！ 🎊').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('社会保障に貢献しました！'), findsOneWidget);
    expect(
      find.text('参考推計：医療・介護費 年間約81,000円（研究集団の比較）'),
      findsOneWidget,
    );
    expect(find.textContaining('研究2件の集団間費用差'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('six sprites clap in sequence and respect reduced motion', (
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
    expect(find.byType(IndexedStack), findsNWidgets(6));
    expect(frame(), 0);
    await show(.25);
    expect(frame(), 1);
    await show(.5);
    expect(frame(), 0);
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
    MemoryStore store, {
    bool showTutorial = false,
  }) async {
    final controller = ProgressController(
      store,
      clock: () => DateTime(2026, 10, 9, 12),
    );
    final catalog = await tester.runAsync(DialogueCatalog.load);
    if (catalog == null) throw StateError('Dialogue asset did not load');
    await tester.pumpWidget(FutureLiftApp(
      controller: controller,
      dialogueCatalog: catalog,
      enableTutorial: showTutorial,
    ));
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
    expect(
      find.text('🎊 日本の社会保障に貢献！ 🎊').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('社会保障に貢献しました！'), findsOneWidget);
    expect(
      find.text('参考推計：医療・介護費 年間約81,000円（研究集団の比較）'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('ミッション達成！ 日本の社会保障に貢献！'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Celebration),
        matching: find.text('ことほぎ +10'),
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
    // On shorter screens, the larger currency/ticket HUD reserves more
    // vertical space. The bottom home action remains reachable by scrolling.
    await tester.ensureVisible(find.byKey(const ValueKey('open-missions')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('open-missions')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('みんなのまち').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TownScene>(find.byType(TownScene)).level, 0);
    final background = tester.widget<Image>(
      find.descendant(
        of: find.byType(TownScene),
        matching: find.byKey(const ValueKey('town-background')),
      ),
    );
    expect(background.image, isA<AssetImage>());
    expect(
      (background.image as AssetImage).assetName,
      'assets/kotohogu/town_background_001.jpg',
    );
    expect(background.fit, BoxFit.cover);
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

  for (final size in <Size>[
    const Size(320, 720),
    const Size(360, 720),
    const Size(402, 874),
  ]) {
    testWidgets('town fills the first screen without duplicate titles at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await launch(tester, MemoryStore());
      await tester.tap(find.text('みんなのまち').last);
      await tester.pumpAndSettle();

      expect(find.text('みんなのまち'), findsOneWidget);
      expect(find.text(townNames.first), findsOneWidget);
      expect(find.text('LEVEL 0'), findsOneWidget);
      expect(find.byKey(const ValueKey('town-page-shrine-background')),
          findsNothing);
      final art = find.byType(TownScene);
      expect(tester.widget<TownScene>(art).fillViewport, isTrue);
      final scene = tester.getRect(art);
      final fullScreen = tester.getRect(
        find.byKey(const ValueKey('town-page-fullscreen')),
      );
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(scene.left, closeTo(fullScreen.left, .1));
      expect(scene.top, closeTo(fullScreen.top, .1));
      expect(scene.width, closeTo(fullScreen.width, .1));
      expect(scene.height, closeTo(fullScreen.height, .1));
      expect(fullScreen.width, closeTo(size.width, .1));
      expect(fullScreen.bottom, lessThanOrEqualTo(nav.top + .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

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
    final catalog = await tester.runAsync(DialogueCatalog.load);
    if (catalog == null) throw StateError('Dialogue asset did not load');
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: FutureLiftHome(
          controller: controller,
          dialogueCatalog: catalog,
          enableTutorial: false,
        ),
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
    // This page intentionally paints behind the pinned currency HUD.
    // Bring the sprite to the visible middle before tapping, not directly
    // underneath the overlay at the top of the scrollable.
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('resident-0'))),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resident-0')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'journal shows only celebrations and deletion preserves progress',
    (tester) async {
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
      expect(find.text('直近30日は 2日、2個の行動を言祝ぎました。'), findsOneWidget);
      expect(find.text('今月は1日、1個の行動を言祝ぎました。'), findsOneWidget);
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('clear-history')),
        160,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('history-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
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
    },
  );

  testWidgets('three mission periods can be selected and celebrated', (
    tester,
  ) async {
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
      find.byKey(const ValueKey('complete-weeklyStrength')),
      160,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complete-weeklyStrength')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(Celebration), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-celebration')));
    await tester.pumpAndSettle();
    expect(controller.progress!.weeklyCompleted, {Mission.weeklyStrength});

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mission-tab-monthly')),
      -180,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mission-tab-monthly')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mission-period-progress')),
      -100,
    );
    await tester.pumpAndSettle();
    expect(find.text('0/3 言祝ぎ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(Mission.monthlyReview.title),
      160,
    );
    expect(find.text(Mission.monthlyReview.title), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('debug menu replays thanks without changing points or history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final original = Progress.empty(DateTime(2026, 10, 9))
        .complete(Mission.strength);
    final store = MemoryStore()..raw = original.encode();
    final controller = await launch(tester, store);

    await tester.tap(find.text('メニュー').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('debug-replay-celebration')),
      findsOneWidget,
    );
    expect(find.textContaining('所持ことほぎ：10'), findsOneWidget);
    final saved = store.raw;
    final writes = store.writes;

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('debug-replay-celebration')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final celebration = tester.widget<Celebration>(find.byType(Celebration));
      expect(celebration.preview, isTrue);
      expect(celebration.total, 10);
      expect(celebration.missionTitle, Mission.strength.title);
      expect(find.byKey(const ValueKey('debug-preview-label')), findsOneWidget);
      expect(find.byKey(const ValueKey('close-celebration')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('close-celebration')));
      await tester.pumpAndSettle();
      expect(controller.progress!.points, 10);
      expect(controller.progress!.completed, {Mission.strength});
      expect(controller.progress!.history['2026-10-09'], {Mission.strength});
      expect(store.writes, writes);
      expect(store.raw, saved);
    }

    await tester.tap(find.byKey(const ValueKey('debug-preview-mission')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Mission.outside.title).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('debug-replay-celebration')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final different = tester.widget<Celebration>(find.byType(Celebration));
    expect(different.missionTitle, Mission.outside.title);
    expect(different.total, 10);
    await tester.tap(find.byKey(const ValueKey('close-celebration')));
    await tester.pumpAndSettle();
    expect(store.writes, writes);
    expect(store.raw, saved);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('town HUD shows only the spendable kotohogi on small phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final controller = await launch(tester, store);
    await tester.tap(find.text('みんなのまち').last);
    await tester.pumpAndSettle();

    final nameplate = find.byKey(const ValueKey('gacha-player-nameplate'));
    final art = find.byKey(const ValueKey('kotohogi-bar-art'));
    final amount = find.byKey(const ValueKey('total-points'));
    expect(find.byKey(const ValueKey('town-page-fullscreen')), findsOneWidget);
    expect(find.byKey(const ValueKey('town-background')), findsOneWidget);
    expect(nameplate, findsOneWidget);
    expect(art, findsOneWidget);
    expect(find.byKey(const ValueKey('kotohogi-bar-label')), findsOneWidget);
    expect(tester.widget<Text>(amount).data, '0');
    expect(find.textContaining('ガチャ券'), findsNothing);
    expect(tester.getRect(nameplate).right,
        lessThan(tester.getRect(art).left));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('メニュー').last);
    await tester.pumpAndSettle();
    final addCurrency = find.byKey(const ValueKey('debug-add-ticket-10'));
    await tester.ensureVisible(addCurrency);
    await tester.pumpAndSettle();
    await tester.tap(addCurrency);
    await tester.pumpAndSettle();
    expect(controller.progress!.residents.availableKotohogi(0), 300);
    await tester.tap(find.text('みんなのまち').last);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(amount).data, '300');
    expect(find.textContaining('ガチャ券'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('debug currency buttons update and persist balance without lifetime points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final controller = await launch(tester, store);
    await tester.tap(find.text('メニュー').last);
    await tester.pumpAndSettle();

    final plusOne = find.byKey(const ValueKey('debug-add-ticket-1'));
    final plusTen = find.byKey(const ValueKey('debug-add-ticket-10'));
    await tester.ensureVisible(plusOne);
    await tester.pumpAndSettle();
    await tester.tap(plusOne);
    await tester.pumpAndSettle();
    expect(controller.progress!.residents.tickets(0), 1);
    expect(find.text('所持ことほぎ：30'), findsOneWidget);
    expect(find.text('ガチャ券 +1枚'), findsNothing);
    await tester.ensureVisible(plusTen);
    await tester.tap(plusTen);
    await tester.pumpAndSettle();
    expect(controller.progress!.residents.tickets(0), 11);
    expect(controller.progress!.residents.availableKotohogi(0), 330);
    expect(controller.progress!.points, 0);
    expect(controller.progress!.history, isEmpty);
    expect(store.writes, 2);
    expect(Progress.decode(store.raw!).residents.tickets(0), 11);
    expect(Progress.decode(store.raw!).residents.availableKotohogi(0), 330);

    await tester.tap(find.text('みんなのまち').last);
    await tester.pumpAndSettle();
    expect(
      controller.progress!.residents.tickets(controller.progress!.points),
      11,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('debug menu reset confirms and clears mission flags only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final original = Progress.empty(DateTime(2026, 10, 9))
        .complete(Mission.strength)
        .complete(Mission.weeklyStrength)
        .complete(Mission.monthlyReview);
    final store = MemoryStore()..raw = original.encode();
    final controller = await launch(tester, store);
    await tester.tap(find.text('メニュー').last);
    await tester.pumpAndSettle();
    final reset = find.byKey(const ValueKey('debug-reset-all-missions'));
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('全ミッションをリセットしますか？'), findsOneWidget);
    expect(find.textContaining('ことほぎが再び加算'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(controller.progress!.completed, {Mission.strength});
    expect(controller.progress!.weeklyCompleted, {Mission.weeklyStrength});
    expect(controller.progress!.monthlyCompleted, {Mission.monthlyReview});
    expect(store.writes, 0);

    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('debug-confirm-reset-missions')),
    );
    await tester.pumpAndSettle();
    expect(find.text('全ミッションの達成状態をリセットしました'), findsOneWidget);
    expect(controller.progress!.completed, isEmpty);
    expect(controller.progress!.weeklyCompleted, isEmpty);
    expect(controller.progress!.monthlyCompleted, isEmpty);
    expect(controller.progress!.points, 30);
    expect(controller.progress!.history, original.history);
    expect(store.writes, 1);
    final restored = Progress.decode(store.raw!);
    expect(restored.completed, isEmpty);
    expect(restored.weeklyCompleted, isEmpty);
    expect(restored.monthlyCompleted, isEmpty);
    expect(restored.history, original.history);

    await tester.tap(find.text('ミッション').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('complete-strength')),
      160,
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('complete-strength')),
    );
    expect(button.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('complete-strength')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(Celebration), findsOneWidget);
    expect(controller.progress!.points, 40);
    await tester.tap(find.byKey(const ValueKey('close-celebration')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('sixteen non-duplicate fixed tips are available', () {
    expect(Resident.values.expand((r) => r.tips).toSet().length, 16);
  });
  testWidgets('Kotohogisu appears once and guides to missions', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.reset());
    final store = MemoryStore();
    final controller = await launch(tester, store, showTutorial: true);
    expect(find.byKey(const ValueKey('kotohogisu-tutorial')), findsOneWidget);
    expect(find.textContaining('ぼくはコトホギス'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kotohogisu-next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ミッション」で教えてね'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kotohogisu-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kotohogisu-next')));
    await tester.pumpAndSettle();
    expect(controller.progress!.seenDialogues, contains('tutorial_kotohogisu_v1'));
    expect(find.byKey(const ValueKey('kotohogisu-tutorial')), findsNothing);
    expect(find.byKey(const ValueKey('complete-strength')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await launch(tester, store, showTutorial: true);
    expect(find.byKey(const ValueKey('kotohogisu-tutorial')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Kotohogisu skip keeps points unchanged', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.reset());
    final store = MemoryStore();
    final controller = await launch(tester, store, showTutorial: true);
    await tester.tap(find.byKey(const ValueKey('kotohogisu-skip')));
    await tester.pumpAndSettle();
    expect(controller.progress!.seenDialogues, contains('tutorial_kotohogisu_v1'));
    expect(controller.progress!.points, 0);
    expect(find.byKey(const ValueKey('kotohogisu-tutorial')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

}
