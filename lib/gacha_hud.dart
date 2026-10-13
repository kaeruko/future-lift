import 'dart:math' as math;

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

  // Share available HUD width so currency values remain legible on phones.
  static const double nameplateShare = .56;
  static const double balanceShare = 1 - nameplateShare;
  static const double horizontalGap = 6;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      // Never ask KotohogiBar to lay out with a zero/unbounded width.
      // A positioned HUD supplies a finite, explicit width below.
      if (!width.isFinite || width <= 6) {
        return const SizedBox.shrink();
      }
      final leftWidth = (width - horizontalGap) * nameplateShare;
      final rightWidth = (width - horizontalGap) * balanceShare;
      final badgeWidth = math.min(156.0, rightWidth * .90);
      return SizedBox(
        width: width,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: leftWidth,
              child: const PlayerNameplate(),
            ),
            const SizedBox(width: horizontalGap),
            SizedBox(
              width: rightWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Column normally gives non-stretch children a *loose*
                    // cross-axis width. The bar must instead receive a tight
                    // positive width to render its proportional artwork.
                    SizedBox(
                      width: rightWidth,
                      child: KotohogiBar(points: points),
                    ),
                    const SizedBox(height: 4),
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
              ),
            ),
          ],
        ),
      );
    },
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
                        fontSize: c.maxHeight * .27,
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
                        fontSize: c.maxHeight * .20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}

/// A fixed HUD at the same safe-area position across home, town, shrine,
/// and result screens. Only the content underneath it is scrollable.
/// The builder gets the actual remaining height (after the HUD).
class PinnedGachaHud extends StatelessWidget {
  const PinnedGachaHud({
    super.key,
    required this.points,
    required this.tickets,
    required this.contentBuilder,
    this.ticketBadgeKey,
  });

  final int points;
  final int tickets;
  final Key? ticketBadgeKey;
  final Widget Function(BuildContext, double) contentBuilder;

  static const double edge = 12;
  static const double top = 12;
  static const double bottomGap = 10;
  static const double maxHudWidth = 570;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width =
          math.min(maxHudWidth, math.max(0.0, constraints.maxWidth - edge * 2));
      final leftWidth =
          (width - GachaHud.horizontalGap) * GachaHud.nameplateShare;
      final rightWidth =
          (width - GachaHud.horizontalGap) * GachaHud.balanceShare;
      final badgeWidth = math.min(156, rightWidth * .90);
      final leftHeight = leftWidth * 209 / 788;
      final rightHeight = 4 + rightWidth * 211 / 982 + 4 +
          badgeWidth * 64 / 176;
      final reservedHeight =
          top + math.max(leftHeight, rightHeight) + bottomGap;
      final remainingHeight = math.max(0.0, constraints.maxHeight - reservedHeight);
      // When nested in Center > ConstrainedBox > Stack, the parent can
      // provide loose constraints. A Stack with only Positioned children
      // otherwise sizes itself to 0x0, breaking both the points bar and
      // the home screen's responsive action button widths.
      return Stack(
        children: [
          const SizedBox.expand(),
          Positioned.fill(
            top: reservedHeight,
            child: contentBuilder(context, remainingHeight),
          ),
          if (width > 6)
            Positioned(
              left: edge,
              right: edge,
              top: top,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  child: GachaHud(
                    points: points,
                    tickets: tickets,
                    ticketBadgeKey: ticketBadgeKey,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
