import 'package:flutter/material.dart';

import 'residents.dart';

const ownedResidentLimit = 8;
const townResidentLimit = 8;
const applauseResidentLimit = 8;

enum TownResident {
  shiba('01_shiba', 'しばいぬ', '001_shiba', Resident.child),
  rabbit('02_rabbit', 'うさぎ', '002_usagi', Resident.student),
  penguin('03_penguin', 'ペンギン', '003_penguin', Resident.adult),
  cat('04_cat', 'ねこ', '004_neko', Resident.adult),
  squirrel('05_squirrel', 'りす', '005_risu', Resident.child),
  bear('06_bear', 'くま', '006_kuma', Resident.elder);

  const TownResident(this.id, this.label, this.artFolder, this.tipSource);
  final String id;
  final String label;
  final String artFolder;
  final Resident tipSource;
  List<String> get tips => tipSource.tips;
  String get idleAsset => 'assets/characters/$artFolder/idle_front_01.png';
  List<String> get clapAssets => [
    for (final frame in ['01', '02'])
      'assets/characters/$artFolder/clap_front_$frame.png',
  ];
  static TownResident fromId(String id) => values.firstWhere(
    (resident) => resident.id == id,
    orElse: () => throw FormatException('Unknown resident ID: $id'),
  );
}

class TownResidentAvatar extends StatelessWidget {
  const TownResidentAvatar({super.key, required this.resident, this.size = 80});
  final TownResident resident;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    resident.idleAsset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

/// Counts retain insertion order, so existing residents keep their town slots.
class ResidentCollection {
  ResidentCollection({
    required this.baselinePoints,
    required Map<String, int> counts,
  }) : counts = Map.unmodifiable(counts);
  factory ResidentCollection.initial(int points) => ResidentCollection(
    baselinePoints: points,
    counts: const {'01_shiba': 1, '02_rabbit': 1},
  );
  final int baselinePoints;
  final Map<String, int> counts;
  List<TownResident> get owned => counts.keys.map(TownResident.fromId).toList();
  int get draws => counts.values.fold(0, (a, b) => a + b) - 2;
  int earnedTickets(int points) => (points - baselinePoints) ~/ 30;
  int tickets(int points) => earnedTickets(points) - draws;
  int untilNextTicket(int points) => 30 - (points - baselinePoints) % 30;
  ResidentCollection acquire(TownResident resident, int points) {
    if (tickets(points) <= 0) {
      throw StateError('No resident tickets available.');
    }
    return ResidentCollection(
      baselinePoints: baselinePoints,
      counts: {...counts, resident.id: (counts[resident.id] ?? 0) + 1},
    );
  }

  Map<String, Object> encode() => {
    'baselinePoints': baselinePoints,
    'counts': counts,
  };
  static ResidentCollection decode(dynamic raw, int points) {
    if (raw is! Map<String, dynamic> ||
        raw.length != 2 ||
        raw['baselinePoints'] is! int ||
        raw['counts'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid resident collection schema.');
    }
    final baseline = raw['baselinePoints'] as int;
    final entries = raw['counts'] as Map<String, dynamic>;
    if (baseline < 0 ||
        baseline > points ||
        baseline % 10 != 0 ||
        entries.length > ownedResidentLimit ||
        !entries.containsKey('01_shiba') ||
        !entries.containsKey('02_rabbit')) {
      throw const FormatException('Invalid resident collection values.');
    }
    final counts = <String, int>{};
    for (final entry in entries.entries) {
      TownResident.fromId(entry.key);
      if (entry.value is! int || entry.value < 1) {
        throw FormatException('Invalid resident count: ${entry.key}');
      }
      counts[entry.key] = entry.value as int;
    }
    final result = ResidentCollection(baselinePoints: baseline, counts: counts);
    if (result.tickets(points) < 0) {
      throw const FormatException('Too many resident draws.');
    }
    return result;
  }
}
