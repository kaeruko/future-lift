import 'package:flutter/material.dart';

/// Shrine-themed counter with a live, data-driven ticket quantity.
class TicketCounterBadge extends StatelessWidget {
  const TicketCounterBadge({super.key, required this.tickets});

  final int tickets;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '住民ガチャ券 $tickets枚',
    liveRegion: true,
    child: ExcludeSemantics(
      child: SizedBox(
        width: 176,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/gacya/ticket_counter_bg.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
            Positioned(
              left: 96,
              right: 24,
              top: 9,
              bottom: 8,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$tickets',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Color(0xFF32180C),
                        blurRadius: 2,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
