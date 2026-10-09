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
  }) : completed = Set.unmodifiable(completed);

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
    );
  }

  Progress complete(Mission mission) {
    if (completed.contains(mission)) return this;
    return Progress(
      day: day,
      lastCompletedDay: day,
      points: points + 10,
      completed: {...completed, mission},
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'day': day,
    'lastCompletedDay': lastCompletedDay,
    'points': points,
    'completed': completed.map((m) => m.name).toList(),
  });

  static Progress decode(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data.length != 5 ||
        data['version'] is! int ||
        data['version'] != 1 ||
        !_validDay(data['day']) ||
        !data.containsKey('lastCompletedDay') ||
        (data['lastCompletedDay'] != null &&
            !_validDay(data['lastCompletedDay'])) ||
        data['points'] is! int ||
        data['completed'] is! List) {
      throw const FormatException('Invalid FutureLift v1 save schema.');
    }
    final day = data['day'] as String;
    final last = data['lastCompletedDay'] as String?;
    final points = data['points'] as int;
    final names = data['completed'] as List;
    final completed = <Mission>{};
    for (final name in names) {
      if (name is! String || !Mission.values.any((m) => m.name == name)) {
        throw FormatException('Unknown mission ID: $name');
      }
      if (!completed.add(Mission.values.singleWhere((m) => m.name == name))) {
        throw FormatException('Duplicate mission ID: $name');
      }
    }
    if (points < 0 ||
        points % 10 != 0 ||
        points < completed.length * 10 ||
        (points == 0) != (last == null) ||
        (last != null && last.compareTo(day) > 0) ||
        (completed.isNotEmpty && last != day) ||
        (completed.isEmpty && last == day)) {
      throw const FormatException('Inconsistent FutureLift progress values.');
    }
    return Progress(
      day: day,
      lastCompletedDay: last,
      points: points,
      completed: completed,
    );
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
  static const key = 'future_lift.progress.v1';

  @override
  Future<Progress?> load() async {
    final raw = await preferences.getString(key);
    // Only a missing key represents a new installation. Corrupt data is fatal.
    return raw == null ? null : Progress.decode(raw);
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
      '$operation\n${LocalProgressStore.key}\n$error\n$stackTrace';
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
}
