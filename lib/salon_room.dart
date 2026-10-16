import 'package:flutter/material.dart';

/// An interior reached by tapping the door of the right-hand village house.
/// Route navigation preserves the selected village and resident positions.
class SalonRoom extends StatelessWidget {
  const SalonRoom({super.key});

  static const backgroundAsset = 'assets/kotohogu/salon_background_001.jpg';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF3DC),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          backgroundAsset,
          key: const ValueKey('salon-background'),
          fit: BoxFit.cover,
          excludeFromSemantics: true,
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
