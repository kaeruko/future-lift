import 'package:flutter/material.dart';

import 'resident_collection.dart';

/// An interior reached by tapping the door of the right-hand village house.
/// Route navigation preserves the selected village and resident positions.
/// The salon's host is always present; she is not a gacha/town-walking resident.
class SalonRoom extends StatelessWidget {
  const SalonRoom({super.key, this.onResident});

  static const backgroundAsset = 'assets/kotohogu/salon_background_001.jpg';
  static const host = TownResident.c031_kimono_fox;

  /// Uses the same CMS-backed conversations and seen-ID tracking as town NPCs.
  final Future<void> Function(TownResident)? onResident;

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
                      backgroundAsset,
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
                      button: onResident != null,
                      label: '${host.label}のおはなし',
                      child: Tooltip(
                        message: host.label,
                        child: InkWell(
                          key: const ValueKey('salon-fox-resident'),
                          borderRadius: BorderRadius.circular(36),
                          onTap: onResident == null
                              ? null
                              : () => onResident!(host),
                          child: Image.asset(
                            host.idleAsset,
                            fit: BoxFit.contain,
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
