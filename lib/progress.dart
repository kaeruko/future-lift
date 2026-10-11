import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Mission {
  strength('筋力を使った', '自分のペースで、体を動かせたら。'),
  outside('外に出た・歩いた', '少しの外出も、今日の一歩。'),
  conversation('人と話した', 'ひと言のやりとりも、大切なつながり。');

  const Mission(this.title, this.description);
  final String title;
  final String description;
}

String localDay(DateTime time) {
  final date = time.toLocal();
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class Progress {
  Progress({
    required this.day,
    required this.lastCompletedDay,
    required this.points,
    required Set<Mission> completed,
    Map<String, Set<Mission>> history = const {},
  }) : completed = Set.unmodifiable(completed),
       history = Map.unmodifiable({
         for (final entry in history.entries)
           entry.key: Set<Mission>.unmodifiable(entry.value),
       });

  factory Progress.empty(DateTime now) => Progress(
    day: localDay(now),
    lastCompletedDay: null,
    points: 0,
    completed: {},
  );

  final String day;
  final String? lastCompletedDay;
  final int points;
  final Set<Mission> completed;
  final Map<String, Set<Mission>> history;

  int get townLevel => points >= 180
      ? 3
      : points >= 90
      ? 2
      : points >= 30
      ? 1
      : 0;

  Progress onDay(DateTime now) {
    final today = localDay(now);
    if (today.compareTo(day) < 0) {
      throw StateError('Device date $today is earlier than saved date $day.');
    }
    if (today == day) return this;
    return Progress(
      day: today,
      lastCompletedDay: lastCompletedDay,
      points: points,
      completed: {},
      history: history,
    );
  }

  Progress complete(Mission mission) {
    if (completed.contains(mission)) return this;
    return Progress(
      day: day,
      lastCompletedDay: day,
      points: points + 10,
      completed: {...completed, mission},
      history: {
        ...history,
        day: {...?history[day], mission},
      },
    );
  }

  /// Erases the journal only. Today's completion state and points remain intact.
  Progress clearHistory() => Progress(
    day: day,
    lastCompletedDay: lastCompletedDay,
    points: points,
    completed: completed,
  );

  String encode() => jsonEncode({
    'version': 2,
    'day': day,
    'lastCompletedDay': lastCompletedDay,
    'points': points,
    'completed': [for (final mission in Mission.values)
      if (completed.contains(mission)) mission.name],
    'history': {
      for (final date in (history.keys.toList()..sort()))
        date: [
          for (final mission in Mission.values)
            if (history[date]!.contains(mission)) mission.name,
        ],
    },
  });

  /// Strictly accepts v1 for migration and v2 for normal storage.
  static Progress decode(String raw, {int? expectedVersion}) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid FutureLift save schema.');
    }
    final version = data['version'];
    if (version is! int || (version != 1 && version != 2) ||
        (expectedVersion != null && version != expectedVersion)) {
      throw FormatException('Unsupported FutureLift save version: $version');
    }
    final requiredKeys = {
      'version', 'day', 'lastCompletedDay', 'points', 'completed',
      if (version == 2) 'history',
    };
    if (data.keys.toSet().difference(requiredKeys).isNotEmpty ||
        data.length != requiredKeys.length ||
        !_validDay(data['day']) ||
        (data['lastCompletedDay'] != null &&
            !_validDay(data['lastCompletedDay'])) ||
        data['points'] is! int) {
      throw const FormatException('Invalid FutureLift save schema.');
    }
    final day = data['day'] as String;
    final last = data['lastCompletedDay'] as String?;
    final points = data['points'] as int;
    final completed = _missions(data['completed'], 'completed');
    final history = <String, Set<Mission>>{};

    if (version == 1) {
      // Old saves know only the *current* day, never previous days.
      if (completed.isNotEmpty) history[day] = completed;
    } else {
      final rawHistory = data['history'];
      if (rawHistory is! Map<String, dynamic>) {
        throw const FormatException('Invalid FutureLift history map.');
      }
      for (final entry in rawHistory.entries) {
        final date = entry.key;
        if (!_validDay(date) || date.compareTo(day) > 0 ||
            last == null || date.compareTo(last) > 0) {
          throw FormatException('Invalid history date: $date');
        }
        final missions = _missions(entry.value, 'history[$date]');
        if (missions.isEmpty) {
          throw FormatException('Empty history entry: $date');
        }
        history[date] = missions;
      }
    }

    if (points < 0 || points % 10 != 0 ||
        points < completed.length * 10 ||
        (points == 0) != (last == null) ||
        (last != null && last.compareTo(day) > 0) ||
        (completed.isNotEmpty && last != day) ||
        (completed.isEmpty && last == day) ||
        (history[day] != null && !completed.containsAll(history[day]!)) ||
        history.values.fold<int>(0, (sum, events) => sum + events.length) * 10 > points) {
      throw const FormatException('Inconsistent FutureLift progress values.');
    }
    return Progress(
      day: day,
      lastCompletedDay: last,
      points: points,
      completed: completed,
      history: history,
    );
  }

  static Set<Mission> _missions(dynamic raw, String field) {
    if (raw is! List) throw FormatException('Invalid mission list: $field');
    final result = <Mission>{};
    for (final name in raw) {
      if (name is! String || !Mission.values.any((m) => m.name == name)) {
        throw FormatException('Unknown mission ID in $field: $name');
      }
      if (!result.add(Mission.values.singleWhere((m) => m.name == name))) {
        throw FormatException('Duplicate mission ID in $field: $name');
      }
    }
    return result;
  }

  static bool _validDay(dynamic value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final parsed = DateTime.tryParse(value);
    return parsed != null && localDay(parsed) == value;
  }
}

abstract interface class ProgressStore {
  Future<Progress?> load();
  Future<void> save(Progress progress);
}

class LocalProgressStore implements ProgressStore {
  LocalProgressStore(this.preferences);
  final SharedPreferencesAsync preferences;
  static const key = 'future_lift.progress.v2';
  static const legacyKey = 'future_lift.progress.v1';

  @override
  Future<Progress?> load() async {
    final current = await preferences.getString(key);
    if (current != null) {
      final restored = Progress.decode(current, expectedVersion: 2);
      // Clean up any v1 copy left by an interrupted migration.
      if (await preferences.getString(legacyKey) != null) {
        await preferences.remove(legacyKey);
      }
      return restored;
    }

    final legacy = await preferences.getString(legacyKey);
    if (legacy == null) return null;
    final migrated = Progress.decode(legacy, expectedVersion: 1);
    // Save v2 first, so cleanup failure cannot destroy the only copy.
    await save(migrated);
    await preferences.remove(legacyKey);
    return migrated;
  }

  @override
  Future<void> save(Progress progress) =>
      preferences.setString(key, progress.encode());
}

class ProgressFailure {
  const ProgressFailure(this.operation, this.error, this.stackTrace);
  final String operation;
  final Object error;
  final StackTrace stackTrace;
  String get diagnostics =>
      '$operation\n${LocalProgressStore.key} / ${LocalProgressStore.legacyKey}\n$error\n$stackTrace';
}

class ProgressController extends ChangeNotifier {
  ProgressController(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final ProgressStore store;
  final DateTime Function() clock;
  Progress? progress;
  ProgressFailure? failure;
  bool busy = false;
  bool _dayRefreshPending = false;

  void _finishOperation() {
    busy = false;
    notifyListeners();
    if (_dayRefreshPending) {
      _dayRefreshPending = false;
      unawaited(refreshDay());
    }
  }

  Future<void> initialize() async {
    if (busy || failure != null || progress != null) return;
    busy = true;
    notifyListeners();
    try {
      final saved = await store.load();
      final current = saved?.onDay(clock()) ?? Progress.empty(clock());
      if (saved != null && !identical(current, saved)) {
        await store.save(current);
      }
      progress = current;
    } catch (error, stack) {
      failure = ProgressFailure('端末内データの読み込み・日付更新', error, stack);
    } finally {
      _finishOperation();
    }
  }

  Future<void> refreshDay() async {
    if (failure != null) return;
    if (busy) {
      _dayRefreshPending = true;
      return;
    }
    if (progress == null) return;
    busy = true;
    try {
      final current = progress!.onDay(clock());
      if (!identical(current, progress)) {
        await store.save(current);
        progress = current;
      }
    } catch (error, stack) {
      failure = ProgressFailure('日付更新の保存', error, stack);
    } finally {
      _finishOperation();
    }
  }

  Future<bool> complete(Mission mission) async {
    if (busy || failure != null || progress == null) return false;
    busy = true;
    notifyListeners();
    try {
      final today = progress!.onDay(clock());
      final next = today.complete(mission);
      if (identical(next, progress)) return false;
      // Commit the whole snapshot before publishing points or celebration.
      await store.save(next);
      progress = next;
      return !identical(next, today);
    } catch (error, stack) {
      failure = ProgressFailure('ミッション ${mission.name} の達成保存', error, stack);
      return false;
    } finally {
      _finishOperation();
    }
  }

  Future<bool> clearHistory() async {
    if (busy || failure != null || progress == null ||
        progress!.history.isEmpty) return false;
    busy = true;
    notifyListeners();
    try {
      final next = progress!.clearHistory();
      await store.save(next);
      progress = next;
      return true;
    } catch (error, stack) {
      failure = ProgressFailure('履歴の削除', error, stack);
      return false;
    } finally {
      _finishOperation();
    }
  }
}
