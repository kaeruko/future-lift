import 'package:flutter/material.dart';

import 'residents.dart';

int get ownedResidentLimit => TownResident.values.length > 8 ? TownResident.values.length : 8;
const townResidentLimit = 8;
const applauseResidentLimit = 8;

/// Maximum spendable kotohogi; contribution totals keep growing.
const maxSpendableKotohogi = 999;

enum WalkDirection { front, back, left, right }

enum TownResident {
  // BEGIN CMS RESIDENTS
  shiba("01_shiba", "しばいぬ", "001_shiba", Resident.child, true, true),
  rabbit("02_rabbit", "うさぎ", "002_usagi", Resident.student, true, true),
  penguin("03_penguin", "ペンギン", "003_penguin", Resident.adult, true, true),
  cat("04_cat", "ねこ", "004_neko", Resident.adult, true, true),
  squirrel("05_squirrel", "りす", "005_risu", Resident.child, true, true),
  bear("06_bear", "くま", "006_kuma", Resident.elder, true, true)
  // END CMS RESIDENTS
  ;

  const TownResident(this.id, this.label, this.artFolder, this.tipSource, this.inGacha, this.walkInTown);
  final String id;
  final String label;
  final String artFolder;
  final Resident tipSource;
  final bool inGacha;
  final bool walkInTown;
  static List<TownResident> get gachaPool =>
      values.where((resident) => resident.inGacha).toList(growable: false);
  List<String> get tips => tipSource.tips;
  String get idleAsset => 'assets/characters/$artFolder/idle_front_01.png';
  List<String> get clapAssets => [
    for (final frame in ['01', '02'])
      'assets/characters/$artFolder/clap_front_$frame.png',
  ];
  /// Walking assets use four real poses per direction.
  /// Shiba's left-facing frames were never supplied; mirror its right poses.
  String walkAsset(WalkDirection direction, int frame) {
    if (frame < 0 || frame >= 4) {
      throw RangeError.range(frame, 0, 3, 'frame');
    }
    final side = direction == WalkDirection.left && this == TownResident.shiba
        ? WalkDirection.right : direction;
    final number = (frame + 1).toString().padLeft(2, '0');
    return 'assets/characters/$artFolder/walk_${side.name}_$number.png';
  }

  bool mirrorWalk(WalkDirection direction) =>
      this == TownResident.shiba && direction == WalkDirection.left;

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
    this.debugTicketsGranted = 0,
    this.bonusDraws = 0,
    this.expiredKotohogi = 0,
  }) : counts = Map.unmodifiable(counts);
  factory ResidentCollection.initial(int points) => ResidentCollection(
    baselinePoints: points,
    counts: const {'01_shiba': 1, '02_rabbit': 1},
  );
  final int baselinePoints;
  final Map<String, int> counts;
  /// Extra test tickets, separate from mission-earned tickets.
  final int debugTicketsGranted;
  /// Free eleventh draws from ten-ticket bundles; not paid with tickets.
  final int bonusDraws;
  /// Credits forfeited because the balance would exceed 999.
  final int expiredKotohogi;
  List<TownResident> get owned => counts.keys.map(TownResident.fromId).toList();
  int get draws => counts.values.fold(0, (a, b) => a + b) - 2 - bonusDraws;
  /// Spendable kotohogi derived from the legacy ticket ledger.
  ///
  /// Each saved draw costs 30; previously earned partial amounts remain.
  /// No persistent schema migration or implicit currency conversion occurs.
  int availableKotohogi(int points) =>
      points - baselinePoints - expiredKotohogi +
      (debugTicketsGranted - draws) * 30;

  int earnedTickets(int points) =>
      (points - baselinePoints - expiredKotohogi) ~/ 30;
  int tickets(int points) => earnedTickets(points) + debugTicketsGranted - draws;
  int untilNextTicket(int points) =>
      30 - (points - baselinePoints - expiredKotohogi) % 30;

  /// Preserve lifetime contribution history while limiting unspent credits.
  ResidentCollection withKotohogiCap(int nextPoints) {
    final excess = availableKotohogi(nextPoints) - maxSpendableKotohogi;
    if (excess <= 0) return this;
    return ResidentCollection(
      baselinePoints: baselinePoints,
      counts: counts,
      debugTicketsGranted: debugTicketsGranted,
      bonusDraws: bonusDraws,
      expiredKotohogi: expiredKotohogi + excess,
    );
  }
  ResidentCollection acquire(TownResident resident, int points) {
    if (tickets(points) <= 0) {
      throw StateError('No resident tickets available.');
    }
    return ResidentCollection(
      baselinePoints: baselinePoints,
      counts: {...counts, resident.id: (counts[resident.id] ?? 0) + 1},
      debugTicketsGranted: debugTicketsGranted,
      bonusDraws: bonusDraws,
      expiredKotohogi: expiredKotohogi,
    );
  }

  /// Draw eleven residents using ten tickets, preserving the bonus across saves.
  ResidentCollection acquireTenPlusOne(List<TownResident> results, int points) {
    if (results.length != 11) throw ArgumentError.value(results.length, 'results');
    if (tickets(points) < 10) throw StateError('Not enough resident tickets.');
    final next = Map<String, int>.of(counts);
    for (final resident in results) {
      next[resident.id] = (next[resident.id] ?? 0) + 1;
    }
    return ResidentCollection(
      baselinePoints: baselinePoints,
      counts: next,
      debugTicketsGranted: debugTicketsGranted,
      bonusDraws: bonusDraws + 1,
      expiredKotohogi: expiredKotohogi,
    );
  }

  ResidentCollection grantTicketsForDebug(int amount) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    return ResidentCollection(
      baselinePoints: baselinePoints,
      counts: counts,
      debugTicketsGranted: debugTicketsGranted + amount,
      bonusDraws: bonusDraws,
      expiredKotohogi: expiredKotohogi,
    );
  }

  Map<String, Object> encode() => {
    'baselinePoints': baselinePoints,
    'counts': counts,
    if (debugTicketsGranted > 0) 'debugTicketsGranted': debugTicketsGranted,
    if (bonusDraws > 0) 'bonusDraws': bonusDraws,
    if (expiredKotohogi > 0) 'expiredKotohogi': expiredKotohogi,
  };
  static ResidentCollection decode(dynamic raw, int points) {
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference({
          'baselinePoints', 'counts', 'debugTicketsGranted', 'bonusDraws',
          'expiredKotohogi',
        }).isNotEmpty ||
        raw.length != 2 +
            (raw.containsKey('debugTicketsGranted') ? 1 : 0) +
            (raw.containsKey('bonusDraws') ? 1 : 0) +
            (raw.containsKey('expiredKotohogi') ? 1 : 0) ||
        raw['baselinePoints'] is! int ||
        raw['counts'] is! Map<String, dynamic> ||
        (raw.containsKey('debugTicketsGranted') &&
            (raw['debugTicketsGranted'] is! int ||
                (raw['debugTicketsGranted'] as int) <= 0)) ||
        (raw.containsKey('bonusDraws') &&
            (raw['bonusDraws'] is! int ||
                (raw['bonusDraws'] as int) <= 0)) ||
        (raw.containsKey('expiredKotohogi') &&
            (raw['expiredKotohogi'] is! int ||
                (raw['expiredKotohogi'] as int) <= 0))) {
      throw const FormatException('Invalid resident collection schema.');
    }
    final baseline = raw['baselinePoints'] as int;
    final entries = raw['counts'] as Map<String, dynamic>;
    final extras = raw.containsKey('debugTicketsGranted')
        ? raw['debugTicketsGranted'] as int : 0;
    final free = raw.containsKey('bonusDraws') ? raw['bonusDraws'] as int : 0;
    final expired = raw.containsKey('expiredKotohogi')
        ? raw['expiredKotohogi'] as int
        : 0;
    if (expired > points - baseline || baseline < 0 ||
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
    final total = counts.values.fold<int>(0, (a, b) => a + b) - 2;
    if (free > total ~/ 11 || free > total || total < 0) {
      throw const FormatException('Invalid free draw count.');
    }
    final result = ResidentCollection(
      baselinePoints: baseline,
      counts: counts,
      debugTicketsGranted: extras,
      bonusDraws: free,
      expiredKotohogi: expired,
    );
    if (result.tickets(points) < 0) {
      throw const FormatException('Too many resident draws.');
    }
    return result;
  }
}
