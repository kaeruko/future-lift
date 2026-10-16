import 'dart:async';

import 'package:flutter/material.dart';

import 'resident_collection.dart';

/// An interior reached by tapping the door of the right-hand village house.
/// Route navigation preserves the selected village and resident positions.
/// The salon's host is always present; she is not a gacha/town-walking resident.
class SalonRoom extends StatefulWidget {
  const SalonRoom({super.key, this.onResident});

  static const backgroundAsset = 'assets/kotohogu/salon_background_001.jpg';
  static const host = TownResident.c031_kimono_fox;

  /// Uses the same CMS-backed conversations and seen-ID tracking as town NPCs.
  final Future<void> Function(TownResident)? onResident;

  @override
  State<SalonRoom> createState() => _SalonRoomState();
}

class _SalonRoomState extends State<SalonRoom> {
  static const _frameDuration = Duration(milliseconds: 200);
  static const _cycleFrames = 40;
  Timer? _ticker;
  int _ticks = 0;
  bool _talking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled && _ticker == null) {
      _ticker = Timer.periodic(_frameDuration, (_) {
        if (mounted && !_talking) setState(() => _ticks++);
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

  String _spriteAsset(BuildContext context) {
    if (_talking ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return SalonRoom.host.idleAsset;
    }
    final frame = _ticks % _cycleFrames;
    if (frame < 4) return SalonRoom.host.idleAsset;
    // Cycle front-facing walking frames without moving the sprite's position.
    if (frame < 32) {
      return SalonRoom.host.walkAsset(WalkDirection.front, (frame - 4) % 4);
    }
    // Finish the eight-second cycle with a short round of applause.
    return SalonRoom.host.clapAssets[((frame - 32) ~/ 2) % 2];
  }

  Future<void> _talk() async {
    final callback = widget.onResident;
    if (callback == null || _talking) return;
    setState(() => _talking = true);
    try {
      await callback(SalonRoom.host);
    } finally {
      if (mounted) setState(() => _talking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF3DC),
    body: Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              // Keep the salon artwork and NPC in the same coordinate space,
              // including on tall and narrow phone displays.
              width: 941,
              height: 1672,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      SalonRoom.backgroundAsset,
                      key: const ValueKey('salon-background'),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    // A welcoming spot toward the foreground of the salon.
                    // Image and tap target scale together with the background.
                    left: 350,
                    top: 1070,
                    width: 240,
                    height: 240,
                    child: Semantics(
                      button: widget.onResident != null,
                      label: '${SalonRoom.host.label}のおはなし',
                      child: Tooltip(
                        message: SalonRoom.host.label,
                        child: InkWell(
                          key: const ValueKey('salon-fox-resident'),
                          borderRadius: BorderRadius.circular(36),
                          onTap: widget.onResident == null ? null : _talk,
                          child: Image.asset(
                            _spriteAsset(context),
                            key: const ValueKey('salon-fox-sprite'),
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: FilledButton.tonalIcon(
                key: const ValueKey('salon-return-village'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('里山にもどる'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
