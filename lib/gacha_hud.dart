import 'package:flutter/material.dart';

import 'home_skin.dart';
import 'resident_collection.dart';

/// Compact, responsive game HUD. Names and ranks are deliberately not invented.
class GachaHud extends StatelessWidget {
  const GachaHud({super.key, required this.points});

  final int points;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 7,
        child: AspectRatio(
          aspectRatio: 788 / 209,
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/kotohogi_hud/player_nameplate.png',
                  key: const ValueKey('gacha-player-nameplate'),
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                Positioned(
                  left: c.maxWidth * .028,
                  top: c.maxHeight * .055,
                  width: c.maxHeight * .85,
                  height: c.maxHeight * .85,
                  child: ClipOval(
                    child: Image.asset(
                      TownResident.shiba.idleAsset,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Positioned(
                  left: c.maxWidth * .285,
                  right: c.maxWidth * .055,
                  top: c.maxHeight * .17,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '今日も一歩ずつ',
                      style: TextStyle(
                        color: const Color(0xFFFFEFCD),
                        fontWeight: FontWeight.w900,
                        fontSize: c.maxHeight * .24,
                        shadows: const [
                          Shadow(color: Color(0xFF3F1D16), blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: c.maxWidth * .285,
                  right: c.maxWidth * .055,
                  top: c.maxHeight * .54,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '自分を言祝ごう',
                      style: TextStyle(
                        color: const Color(0xFFFFEFCD),
                        fontWeight: FontWeight.w700,
                        fontSize: c.maxHeight * .18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        flex: 4,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: KotohogiBar(points: points),
        ),
      ),
    ],
  );
}
