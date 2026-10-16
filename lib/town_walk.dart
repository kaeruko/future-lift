import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'resident_collection.dart';

/// A normalized, non-persistent position for a resident's gentle stroll.
@immutable
class TownWalkPose {
  const TownWalkPose({
    required this.x,
    required this.y,
    required this.direction,
    required this.frame,
  });

  final double x;
  final double y;
  /// Null means the resident is taking a break (idle sprite).
  final WalkDirection? direction;
  final int frame;
  bool get walking => direction != null;
}

/// The first eight positions retain the original arrangement (not a headcount
/// limit). Positions leave room for sprites in the clipped town viewport.
const townWalkSlots = <(double, double)>[
  (.10, .51),
  (.63, .49),
  (.33, .65),
  (.72, .73),
  (.03, .76),
  (.48, .47),
  (.28, .43),
  (.50, .76),
];

/// For nine or more residents, create unique grid origins rather than reusing
/// one of the first eight slots. All coordinates are image-relative.
(double, double) townWalkOrigin(int slot, {required int totalSlots}) {
  if (totalSlots <= 0) {
    throw RangeError.value(totalSlots, 'totalSlots', 'Must be positive');
  }
  if (slot < 0 || slot >= totalSlots) {
    throw RangeError.range(slot, 0, totalSlots - 1, 'slot');
  }
  if (totalSlots <= townWalkSlots.length) {
    return townWalkSlots[slot];
  }
  final columns = math.sqrt(totalSlots * 1.3).ceil();
  final rows = (totalSlots + columns - 1) ~/ columns;
  final col = slot % columns;
  final row = slot ~/ columns;
  return (
    .05 + (columns == 1 ? 0 : col * .69 / (columns - 1)),
    .40 + (rows == 1 ? 0 : row * .30 / (rows - 1)),
  );
}

const _walkStepMs = 150;
const _horizontalMs = 3000;
const _verticalMs = 1600;
const _restMs = 900;
const _walkCycleMs = 2 * _horizontalMs + 2 * _verticalMs + 4 * _restMs;

/// Deterministic, pause-inclusive 4-direction walk without saved game state.
TownWalkPose townWalkPose(
  int slot,
  Duration elapsed, {
  int? totalSlots,
}) {
  final count = totalSlots ?? math.max(townWalkSlots.length, slot + 1);
  final start = townWalkOrigin(slot, totalSlots: count);
  final dense = count > townWalkSlots.length;
  final width = dense
      ? math.min(.05, .35 / math.sqrt(count))
      : (slot.isEven ? .080 : .065);
  final height = dense
      ? math.min(.026, .20 / math.sqrt(count))
      : (slot.isEven ? .035 : .045);
  // Stagger characters to avoid a synchronized marching formation.
  var time = (elapsed.inMilliseconds + slot * 1640) % _walkCycleMs;
  var x = start.$1;
  var y = start.$2;
  final legs = <(int, double, double, WalkDirection)>[
    (_horizontalMs, width, 0, WalkDirection.right),
    (_verticalMs, 0, height, WalkDirection.front),
    (_horizontalMs, -width, 0, WalkDirection.left),
    (_verticalMs, 0, -height, WalkDirection.back),
  ];
  for (final leg in legs) {
    final duration = leg.$1;
    if (time < duration) {
      final fraction = time / duration;
      return TownWalkPose(
        x: x + leg.$2 * fraction,
        y: y + leg.$3 * fraction,
        direction: leg.$4,
        frame: (time ~/ _walkStepMs) % 4,
      );
    }
    time -= duration;
    x += leg.$2;
    y += leg.$3;
    if (time < _restMs) {
      return TownWalkPose(x: x, y: y, direction: null, frame: 0);
    }
    time -= _restMs;
  }
  throw StateError('Town walk cycle exceeded its duration.');
}
