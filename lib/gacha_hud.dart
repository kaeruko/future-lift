import 'package:flutter/material.dart';

import 'home_skin.dart';
import 'resident_collection.dart';
import 'ticket_counter_badge.dart';

/// Compact, responsive game HUD. Names and ranks are deliberately not invented.
class GachaHud extends StatelessWidget {
  const GachaHud({
    super.key,
    required this.points,
    required this.tickets,
    this.ticketBadgeKey,
  });

  final int points;
  final int tickets;
  final Key? ticketBadgeKey;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Expanded(
        flex: 7,
        child: PlayerNameplate(),
      ),
      const SizedBox(width: 6),
      Expanded(
        flex: 4,
        child: LayoutBuilder(
          builder: (context, c) {
            final badgeWidth = (c.maxWidth * .90).clamp(0.0, 156.0);
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  KotohogiBar(points: points),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(right: 5, bottom: 2),
                    child: Text(
                      '所持ガチャ券',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF63351F),
                        shadows: [
                          Shadow(color: Color(0xFFFFF4DA), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'ガチャ券 $tickets枚',
                    child: SizedBox(
                      width: badgeWidth,
                      height: badgeWidth * 64 / 176,
                      child: FittedBox(
                        alignment: Alignment.centerRight,
                        fit: BoxFit.contain,
                        child: TicketCounterBadge(
                          key: ticketBadgeKey,
                          tickets: tickets,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

/// The same decorative player nameplate is used in home and gacha.
class PlayerNameplate extends StatelessWidget {
  const PlayerNameplate({super.key});

  @override
  Widget build(BuildContext context) => AspectRatio(
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
        );
}
