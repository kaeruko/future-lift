import 'dart:async';

import 'package:flutter/material.dart';

import 'resident_collection.dart';
import 'town_walk.dart';

const townNames = ['穏やかなまち', '花のあるまち', '笑顔が集まるまち', 'にぎやかなまち'];
const townDescriptions = [
  'いつものまちで、みんなが暮らしています。',
  '道ばたに、色とりどりの花が咲きました。',
  '公園に、笑顔の住民が集まってきました。',
  '小さな飾りが、まちの日常を彩っています。',
];

/// The owned residents wander gently around the illustrated plaza.
class TownScene extends StatefulWidget {
  const TownScene({
    super.key,
    required this.level,
    required this.residents,
    this.onResident,
  });

  final int level;
  final List<TownResident> residents;
  final Future<void> Function(TownResident)? onResident;

  @override
  State<TownScene> createState() => _TownSceneState();
}

class _TownSceneState extends State<TownScene> {
  static const _frameDuration = Duration(milliseconds: 150);
  Timer? _ticker;
  int _ticks = 0;
  final _pauseStarted = <TownResident, int>{};
  final _pausedMillis = <TownResident, int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context);
    if (enabled && _ticker == null) {
      _ticker = Timer.periodic(_frameDuration, (_) {
        if (mounted) setState(() => _ticks++);
      });
    } else if (!enabled) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _elapsedMillis(TownResident resident) {
    final now = _ticks * _frameDuration.inMilliseconds;
    final pauseStart = _pauseStarted[resident];
    final currentPause = pauseStart == null ? 0 : now - pauseStart;
    return now - (_pausedMillis[resident] ?? 0) - currentPause;
  }

  Future<void> _talk(TownResident resident) async {
    final callback = widget.onResident;
    if (callback == null || _pauseStarted.containsKey(resident)) return;
    setState(() {
      _pauseStarted[resident] = _ticks * _frameDuration.inMilliseconds;
    });
    try {
      await callback(resident);
    } finally {
      if (mounted) {
        setState(() {
          final start = _pauseStarted.remove(resident)!;
          _pausedMillis[resident] = (_pausedMillis[resident] ?? 0) +
              _ticks * _frameDuration.inMilliseconds - start;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.22,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final reduced = MediaQuery.disableAnimationsOf(context);
          final count = widget.residents.length < townResidentLimit
              ? widget.residents.length : townResidentLimit;
          final size = (width * .14).clamp(40.0, 76.0);
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/kotohogu/town_background_001.jpg',
                  key: const ValueKey('town-background'),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              for (var index = 0; index < count; index++)
                _resident(
                  widget.residents[index],
                  index,
                  width,
                  height,
                  size,
                  reduced,
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _resident(
    TownResident resident,
    int index,
    double width,
    double height,
    double size,
    bool reduced,
  ) {
    final pose = reduced
        ? TownWalkPose(
            x: townWalkSlots[index].$1,
            y: townWalkSlots[index].$2,
            direction: null,
            frame: 0,
          )
        : townWalkPose(
            index,
            Duration(milliseconds: _elapsedMillis(resident)),
          );
    final direction = pose.direction;
    final walking = direction != null &&
        !_pauseStarted.containsKey(resident) && !reduced;
    final asset = walking
        ? resident.walkAsset(direction!, pose.frame)
        : resident.idleAsset;
    final sprite = Image.asset(
      asset,
      key: ValueKey('resident-sprite-$index'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    return Positioned(
      left: width * pose.x,
      top: height * pose.y,
      child: Semantics(
        button: widget.onResident != null,
        label: '${resident.label}のTips',
        child: Tooltip(
          message: resident.label,
          child: InkWell(
            key: ValueKey('resident-$index'),
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onResident == null ? null : () => _talk(resident),
            child: walking && resident.mirrorWalk(direction!)
                ? Transform.flip(flipX: true, child: sprite)
                : sprite,
          ),
        ),
      ),
    );
  }
}
