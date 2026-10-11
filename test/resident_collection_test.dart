import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/clap_characters.dart';
import 'package:future_lift/celebration.dart';
import 'package:future_lift/main.dart';
import 'package:future_lift/town.dart';

import 'progress_test.dart' show MemoryStore;

class FixedRandom implements Random {
  FixedRandom(this.index);
  final int index;
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    return index;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

Progress funded({int points = 30}) => Progress(
  day: '2026-10-11',
  lastCompletedDay: '2026-10-11',
  points: points,
  completed: {},
  residents: ResidentCollection.initial(0),
);

void main() {
  test('tickets every 30 new points; duplicates do not add town residents', () {
    var progress = Progress.empty(DateTime(2026, 10, 11));
    expect(progress.residents.owned, [TownResident.shiba, TownResident.rabbit]);
    progress = progress.complete(Mission.strength).complete(Mission.outside);
    expect(progress.residents.tickets(progress.points), 0);
    progress = progress.complete(Mission.conversation);
    expect(progress.residents.tickets(progress.points), 1);
    final duplicate = progress.acquireResident(TownResident.shiba);
    expect(duplicate.residents.owned.length, 2);
    expect(duplicate.residents.counts['01_shiba'], 2);
    expect(duplicate.points, 30);
    expect(duplicate.residents.tickets(30), 0);
    expect(
      () => duplicate.acquireResident(TownResident.penguin),
      throwsStateError,
    );
    final restored = Progress.decode(duplicate.encode());
    expect(restored.residents.counts, duplicate.residents.counts);
    for (final preserved in [
      restored.onDay(DateTime(2026, 10, 12)),
      restored.clearHistory(),
      restored.resetMissionsForDebug(),
    ]) {
      expect(preserved.residents.encode(), restored.residents.encode());
    }
  });

  test('all six residents never stop draws or ticket earning', () {
    var progress = funded(points: 240);
    for (final resident in TownResident.values.skip(2)) {
      progress = progress.acquireResident(resident);
    }
    expect(progress.residents.owned.length, 6);
    progress = progress.acquireResident(TownResident.penguin);
    expect(progress.residents.owned.length, 6);
    expect(progress.residents.counts['03_penguin'], 2);
    expect(progress.residents.tickets(240), 3);
    progress = progress
        .complete(Mission.strength)
        .complete(Mission.outside)
        .complete(Mission.conversation);
    expect(progress.residents.tickets(270), 4);
    expect(Progress.decode(progress.encode()).residents.owned.length, 6);
  });

  test(
    'v3 migration preserves points and starts tickets at migration baseline',
    () {
      final raw =
          jsonDecode(funded(points: 100).encode()) as Map<String, dynamic>;
      raw['version'] = 3;
      raw.remove('residents');
      final migrated = Progress.decode(jsonEncode(raw), expectedVersion: 3);
      expect(migrated.points, 100);
      expect(migrated.residents.baselinePoints, 100);
      expect(migrated.residents.tickets(100), 0);
      final next = migrated
          .complete(Mission.strength)
          .complete(Mission.outside)
          .complete(Mission.conversation);
      expect(next.residents.tickets(130), 1);
      expect(Progress.decode(next.encode(), expectedVersion: 4).points, 130);
    },
  );

  test(
    'bad resident IDs, counts, missing fields and overspent tickets fail',
    () {
      final raw = jsonDecode(funded().encode()) as Map<String, dynamic>;
      for (final invalid in [
        null,
        {
          'baselinePoints': 40,
          'counts': {'01_shiba': 1, '02_rabbit': 1},
        },
        {
          'baselinePoints': 0,
          'counts': {'01_shiba': 1, '02_rabbit': 1, 'unknown': 1},
        },
        {
          'baselinePoints': 0,
          'counts': {'01_shiba': 1, '02_rabbit': 0},
        },
        {
          'baselinePoints': 0,
          'counts': {'01_shiba': 1, '02_rabbit': 1.0},
        },
        {
          'baselinePoints': 0,
          'counts': {'01_shiba': 3, '02_rabbit': 1},
        },
        {
          'baselinePoints': 0,
          'counts': {'01_shiba': 1},
        },
      ]) {
        expect(
          () => Progress.decode(jsonEncode({...raw, 'residents': invalid})),
          throwsFormatException,
        );
      }
      raw.remove('residents');
      expect(() => Progress.decode(jsonEncode(raw)), throwsFormatException);
    },
  );

  test(
    'draw commits once before publishing; saving failure retains diagnostics',
    () async {
      final random = FixedRandom(2);
      final store = MemoryStore()..raw = funded().encode();
      final controller = ProgressController(
        store,
        clock: () => DateTime(2026, 10, 11),
        random: random,
      );
      await controller.initialize();
      store.gate = Completer<void>();
      final draw = controller.drawResident();
      expect(controller.progress!.residents.owned.length, 2);
      expect(await controller.drawResident(), isNull);
      store.gate!.complete();
      expect(await draw, TownResident.penguin);
      expect(random.calls, 1);
      expect(store.writes, 1);
      expect(controller.progress!.residents.owned.length, 3);
      expect(Progress.decode(store.raw!).residents.owned.length, 3);

      final error = StateError('disk full');
      final failedStore = MemoryStore()
        ..raw = funded().encode()
        ..saveError = error;
      final failed = ProgressController(
        failedStore,
        clock: () => DateTime(2026, 10, 11),
        random: random,
      );
      await failed.initialize();
      expect(await failed.drawResident(), isNull);
      expect(failed.failure!.error, same(error));
      expect(failed.failure!.stackTrace.toString(), isNotEmpty);
      expect(failed.progress!.residents.tickets(30), 1);
      expect(failed.progress!.residents.owned.length, 2);
      expect(await failed.drawResident(), isNull);
      expect(failedStore.writes, 1);
    },
  );

  testWidgets(
    'new resident appears in town, applause and restored collection',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemoryStore()..raw = funded().encode();
      final controller = ProgressController(
        store,
        clock: () => DateTime(2026, 10, 11),
        random: FixedRandom(2),
      );
      await tester.pumpWidget(FutureLiftApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('みんなのまち').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TownScene>(find.byType(TownScene)).residents.length,
        2,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('draw-resident')),
        180,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('draw-resident')));
      await tester.pumpAndSettle();
      expect(find.text('ペンギンが、まちにやってきました！'), findsOneWidget);
      expect(controller.progress!.residents.tickets(30), 0);
      await tester.scrollUntilVisible(find.byType(TownScene), -180);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TownScene>(find.byType(TownScene)).residents.length,
        3,
      );
      await tester.tap(find.text('ミッション').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('complete-strength')),
        180,
      );
      await tester.tap(find.byKey(const ValueKey('complete-strength')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(Celebration), findsOneWidget);
      expect(
        tester.widget<ClapCharacters>(find.byType(ClapCharacters)).residents,
        [TownResident.shiba, TownResident.rabbit, TownResident.penguin],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(Progress.decode(store.raw!).residents.owned.length, 3);
    },
  );
}
