import 'dart:convert';
import 'package:flutter/services.dart';
import 'progress.dart';
import 'resident_collection.dart';

class DialogueCatalog {
  DialogueCatalog._(this.entries);
  static const assetPath = 'assets/dialogues/dialogues.json';
  final List<DialogueEntry> entries;

  static Future<DialogueCatalog> load() async =>
      fromJson(await rootBundle.loadString(assetPath));

  static DialogueCatalog fromJson(String source) {
    final root = _object(jsonDecode(source), 'root');
    _keys(root, {'version', 'dialogues'}, 'root');
    if (root['version'] != 1 || root['dialogues'] is! List) {
      throw const FormatException('Invalid dialogue document version');
    }
    final entries = <DialogueEntry>[];
    final ids = <String>{};
    for (final row in root['dialogues'] as List) {
      final entry = DialogueEntry.parse(row);
      if (!ids.add(entry.id)) throw FormatException('Duplicate dialogue id: ' + entry.id);
      entries.add(entry);
    }
    for (final resident in TownResident.values) {
      if (!entries.any((e) => e.residentId == resident.id &&
          e.conditions.isEmpty && !e.once)) {
        throw FormatException('Missing unconditional dialogue: ' + resident.id);
      }
    }
    return DialogueCatalog._(List.unmodifiable(entries));
  }

  DialogueEntry select({
    required TownResident resident,
    required Progress progress,
    required DateTime now,
    int rotation = 0,
  }) {
    final available = entries.where((entry) =>
      entry.residentId == resident.id &&
      (!entry.once || !progress.seenDialogues.contains(entry.id)) &&
      entry.matches(progress, now)).toList();
    if (available.isEmpty) throw StateError('No dialogue: ' + resident.id);
    available.sort((a, b) => b.priority.compareTo(a.priority));
    final top = available.where((e) => e.priority == available.first.priority).toList();
    return top[rotation % top.length];
  }
}

class DialogueEntry {
  DialogueEntry._(this.id, this.residentId, this.text, this.priority,
      this.once, this.logic, this.conditions);
  final String id;
  final String residentId;
  final String text;
  final int priority;
  final bool once;
  final String logic;
  final List<DialogueCondition> conditions;

  factory DialogueEntry.parse(Object? source) {
    final data = _object(source, 'dialogue');
    _keys(data, {'id', 'residentId', 'text', 'priority', 'once', 'logic',
      'conditions'}, 'dialogue');
    final id = data['id'];
    final resident = data['residentId'];
    final message = data['text'];
    final priority = data['priority'];
    final once = data['once'];
    final logic = data['logic'];
    final conditions = data['conditions'];
    if (id is! String || !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id) ||
        resident is! String ||
        !TownResident.values.any((r) => r.id == resident) ||
        message is! String || message.trim().isEmpty || message.length > 500 ||
        priority is! int || priority < -1000 || priority > 1000 ||
        once is! bool || !{'all', 'any'}.contains(logic) ||
        conditions is! List || conditions.length > 8) {
      throw const FormatException('Invalid dialogue entry');
    }
    return DialogueEntry._(id, resident, message, priority, once, logic,
      List.unmodifiable(conditions.map(DialogueCondition.parse)));
  }

  bool matches(Progress progress, DateTime now) {
    if (conditions.isEmpty) return true;
    return logic == 'all'
        ? conditions.every((c) => c.matches(progress, now))
        : conditions.any((c) => c.matches(progress, now));
  }
}

class DialogueCondition {
  DialogueCondition._(this.fields);
  final Map<String, dynamic> fields;

  factory DialogueCondition.parse(Object? source) {
    final data = _object(source, 'condition');
    if (data['type'] == 'mission') {
      _keys(data, {'type', 'missionId', 'minCount'}, 'mission condition');
      final id = data['missionId'];
      final threshold = data['minCount'];
      if (id is! String || (id != 'all' &&
          !Mission.values.any((m) => m.name == id)) ||
          threshold is! int || threshold < 1 || threshold > 1000000) {
        throw const FormatException('Invalid mission condition');
      }
    } else if (data['type'] == 'kotohogi') {
      _keys(data, {'type', 'min'}, 'kotohogi condition');
      final minimum = data['min'];
      if (minimum is! int || minimum < 0 || minimum > 10000000) {
        throw const FormatException('Invalid kotohogi condition');
      }
    } else if (data['type'] == 'date') {
      final mode = data['mode'];
      if (mode == 'exact') {
        _keys(data, {'type', 'mode', 'date'}, 'exact date');
        _fullDay(data['date']);
      } else if (mode == 'range') {
        _keys(data, {'type', 'mode', 'start', 'end'}, 'date range');
        final start = _fullDay(data['start']);
        final end = _fullDay(data['end']);
        if (start.compareTo(end) > 0) throw const FormatException('Reversed date range');
      } else if (mode == 'annual') {
        _keys(data, {'type', 'mode', 'date'}, 'annual date');
        _monthDay(data['date']);
      } else if (mode == 'annual_range') {
        _keys(data, {'type', 'mode', 'start', 'end'}, 'annual range');
        _monthDay(data['start']);
        _monthDay(data['end']);
      } else if (mode == 'weekday') {
        _keys(data, {'type', 'mode', 'days'}, 'weekday');
        final days = data['days'];
        if (days is! List || days.isEmpty ||
            days.any((d) => d is! int || d < 1 || d > 7) ||
            days.toSet().length != days.length) {
          throw const FormatException('Invalid weekday condition');
        }
      } else {
        throw const FormatException('Unknown date mode');
      }
    } else {
      throw const FormatException('Unknown condition type');
    }
    return DialogueCondition._(Map.unmodifiable(data));
  }

  bool matches(Progress progress, DateTime now) {
    final kind = fields['type'];
    if (kind == 'mission') {
      return progress.countFor(fields['missionId'] as String) >=
          (fields['minCount'] as int);
    }
    if (kind == 'kotohogi') return progress.points >= fields['min'];
    // Convert absolute instant to Japan Standard Time (+09:00).
    final jst = now.toUtc().add(const Duration(hours: 9));
    final day = jst.year.toString().padLeft(4, '0') + '-' +
        jst.month.toString().padLeft(2, '0') + '-' +
        jst.day.toString().padLeft(2, '0');
    final md = day.substring(5);
    switch (fields['mode']) {
      case 'exact':
        return day == fields['date'];
      case 'range':
        return day.compareTo(fields['start'] as String) >= 0 &&
            day.compareTo(fields['end'] as String) <= 0;
      case 'annual':
        return md == fields['date'];
      case 'annual_range':
        final start = fields['start'] as String;
        final end = fields['end'] as String;
        return start.compareTo(end) <= 0
            ? md.compareTo(start) >= 0 && md.compareTo(end) <= 0
            : md.compareTo(start) >= 0 || md.compareTo(end) <= 0;
      case 'weekday':
        final weekday = DateTime.utc(jst.year, jst.month, jst.day).weekday;
        return (fields['days'] as List).contains(weekday);
    }
    throw StateError('Unvalidated date condition');
  }
}

Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map<String, dynamic>) throw FormatException('Expected object: ' + field);
  return value;
}
void _keys(Map<String, dynamic> data, Set<String> expected, String field) {
  if (data.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(data.keys.toSet()).isNotEmpty) {
    throw FormatException('Invalid fields: ' + field);
  }
}
String _fullDay(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid exact date');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.year.toString().padLeft(4, '0') + '-' +
      parsed.month.toString().padLeft(2, '0') + '-' +
      parsed.day.toString().padLeft(2, '0') != value) {
    throw const FormatException('Invalid calendar date');
  }
  return value;
}
String _monthDay(Object? value) {
  if (value is! String || !RegExp(r'^\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid annual date');
  }
  _fullDay('2000-' + value);
  return value;
}
