import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/progress.dart';

class MemoryStore implements ProgressStore {
  String? raw;
  int writes = 0;
  Object? loadError;
  Object? saveError;
  Completer<void>? gate;

  @override
  Future<Progress?> load() async {
    if (loadError != null) throw loadError!;
    return raw == null ? null : Progress.decode(raw!);
  }

  @override
  Future<void> save(Progress progress) async {
    writes++;
    if (gate != null) await gate!.future;
    if (saveError != null) throw saveError!;
    raw = progress.encode();
  }
}

void main() {
  final today = DateTime(2026, 10, 9, 12);

  test(
    'midnight refresh waits for an in-flight save without losing earned points',
    () async {
      var now = DateTime(2026, 10, 9, 23, 59);
      final store = MemoryStore()..gate = Completer<void>();
      final controller = ProgressController(store, clock: () => now);
      await controller.initialize();
      final completion = controller.complete(Mission.strength);
      now = DateTime(2026, 10, 10);
      await controller.refreshDay();
      store.gate!.complete();
      expect(await completion, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(controller.progress!.day, '2026-10-10');
      expect(controller.progress!.completed, isEmpty);
      expect(controller.progress!.points, 10);
      expect(controller.progress!.lastCompletedDay, '2026-10-09');
      expect(Progress.decode(store.raw!).day, '2026-10-10');
      expect(store.writes, 2);
    },
  );

  test(
    'award once per mission per day and restore from serialized storage',
    () async {
      final store = MemoryStore();
      final controller = ProgressController(store, clock: () => today);
      await controller.initialize();
      expect(controller.progress!.points, 0);
      expect(await controller.complete(Mission.strength), isTrue);
      expect(await controller.complete(Mission.strength), isFalse);
      expect(controller.progress!.points, 10);
      expect(store.writes, 1);
      final restarted = ProgressController(store, clock: () => today);
      await restarted.initialize();
      expect(restarted.progress!.completed, {Mission.strength});
      expect(restarted.progress!.lastCompletedDay, '2026-10-09');
      expect(restarted.progress!.points, 10);
      for (final mission in [Mission.outside, Mission.conversation]) {
        expect(await restarted.complete(mission), isTrue);
      }
      expect(restarted.progress!.points, 30);
      expect(restarted.progress!.townLevel, 1);
    },
  );

  test('midnight and absence reset only daily missions, retaining last date and points', () async {
    var now = DateTime(2026, 12, 31, 23, 59);
    final store = MemoryStore();
    final controller = ProgressController(store, clock: () => now);
    await controller.initialize();
    await controller.complete(Mission.outside);
    now = DateTime(2027, 1, 1);
    await controller.refreshDay();
    expect(controller.progress!.day, '2027-01-01');
    expect(controller.progress!.completed, isEmpty);
    expect(controller.progress!.lastCompletedDay, '2026-12-31');
    expect(controller.progress!.points, 10);
    await controller.complete(Mission.outside);
    expect(controller.progress!.points, 20);
    now = DateTime(2027, 3, 1);
    final restarted = ProgressController(store, clock: () => now);
    await restarted.initialize();
    expect(restarted.progress!.completed, isEmpty);
    expect(restarted.progress!.points, 20);
    expect(restarted.progress!.lastCompletedDay, '2027-01-01');
  });

  test(
    'completion checks the current day even before lifecycle refresh',
    () async {
      var now = today;
      final controller = ProgressController(MemoryStore(), clock: () => now);
      await controller.initialize();
      await controller.complete(Mission.conversation);
      now = now.add(const Duration(days: 1));
      expect(await controller.complete(Mission.conversation), isTrue);
      expect(controller.progress!.points, 20);
      expect(controller.progress!.completed, {Mission.conversation});
    },
  );

  test(
    'concurrent taps cannot double award, and nothing publishes before save',
    () async {
      final store = MemoryStore()..gate = Completer<void>();
      final controller = ProgressController(store, clock: () => today);
      await controller.initialize();
      final first = controller.complete(Mission.strength);
      expect(controller.busy, isTrue);
      expect(controller.progress!.points, 0);
      expect(await controller.complete(Mission.strength), isFalse);
      expect(await controller.complete(Mission.outside), isFalse);
      store.gate!.complete();
      expect(await first, isTrue);
      expect(controller.progress!.points, 10);
      expect(store.writes, 1);
    },
  );

  test('save failure preserves original exception/stack, stops awards and never retries', () async {
    final error = StateError('disk unavailable');
    final store = MemoryStore()..saveError = error;
    final controller = ProgressController(store, clock: () => today);
    await controller.initialize();
    expect(await controller.complete(Mission.strength), isFalse);
    expect(controller.failure!.error, same(error));
    expect(
      controller.failure!.stackTrace.toString(),
      contains('MemoryStore.save'),
    );
    expect(controller.progress!.points, 0);
    expect(controller.progress!.completed, isEmpty);
    expect(store.raw, isNull);
    await controller.refreshDay();
    await controller.initialize();
    expect(await controller.complete(Mission.outside), isFalse);
    expect(store.writes, 1);
  });

  test(
    'read and rollover save errors halt without replacing existing data',
    () async {
      final error = StateError('cannot read');
      final store = MemoryStore()..loadError = error;
      final controller = ProgressController(store, clock: () => today);
      await controller.initialize();
      expect(controller.failure!.error, same(error));
      expect(controller.progress, isNull);
      expect(store.writes, 0);
      final saved = Progress.empty(today).complete(Mission.strength).encode();
      store
        ..loadError = null
        ..raw = saved
        ..saveError = error;
      final nextDay = ProgressController(
        store,
        clock: () => today.add(const Duration(days: 1)),
      );
      await nextDay.initialize();
      expect(nextDay.failure!.error, same(error));
      expect(store.raw, saved);
    },
  );

  test(
    'invalid schema, types, dates, IDs and inconsistent values fail fast',
    () {
      final valid =
          jsonDecode(Progress.empty(today).encode()) as Map<String, dynamic>;
      for (final patch in <Map<String, dynamic>>[
        {'version': 2},
        {'version': 1.0},
        {'points': '10'},
        {'points': -10},
        {'points': 1},
        {'day': '2026-02-30'},
        {'day': '2026-1-1'},
        {
          'completed': ['unknown'],
        },
        {
          'completed': ['strength', 'strength'],
        },
        {'points': 10},
        {'lastCompletedDay': '2026-10-10'},
        {
          'completed': ['strength'],
        },
        {'extra': true},
      ]) {
        expect(
          () => Progress.decode(jsonEncode({...valid, ...patch})),
          throwsFormatException,
          reason: patch.toString(),
        );
      }
      expect(() => Progress.decode('broken'), throwsFormatException);
    },
  );

  test(
    'corrupt storage halts instead of initializing an empty profile',
    () async {
      final store = MemoryStore()..raw = '{broken';
      final controller = ProgressController(store, clock: () => today);
      await controller.initialize();
      expect(controller.failure!.error, isA<FormatException>());
      expect(controller.progress, isNull);
      expect(store.raw, '{broken');
      expect(store.writes, 0);
    },
  );

  test(
    'backward device dates stop without silently granting duplicate missions',
    () async {
      final store = MemoryStore()
        ..raw = Progress.empty(today).complete(Mission.strength).encode();
      final controller = ProgressController(
        store,
        clock: () => today.subtract(const Duration(days: 1)),
      );
      await controller.initialize();
      expect(controller.failure!.error, isA<StateError>());
      expect(store.writes, 0);
    },
  );

  test('four town stages use cumulative points and never decay', () {
    for (final (points, level) in [
      (0, 0),
      (20, 0),
      (30, 1),
      (80, 1),
      (90, 2),
      (170, 2),
      (180, 3),
      (9990, 3),
    ]) {
      final progress = Progress(
        day: localDay(today),
        lastCompletedDay: null,
        points: points,
        completed: {},
      );
      expect(progress.townLevel, level);
      expect(progress.onDay(DateTime(2028)).townLevel, level);
    }
  });
}
