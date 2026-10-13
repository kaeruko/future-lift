import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/gacha_hud.dart';
import 'package:future_lift/ticket_counter_badge.dart';

void main() {
  for (final width in <double>[320, 402, 570]) {
    testWidgets('HUD obtains full size from loose Stack constraints at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.amber),
                  ),
                  PinnedGachaHud(
                    points: 100,
                    tickets: 7,
                    ticketBadgeKey: const ValueKey('loose-hud-tickets'),
                    contentBuilder: (context, remainingHeight) => ListView(
                      children: [
                        Text('Scene has ${remainingHeight.toStringAsFixed(0)}px'),
                        const SizedBox(height: 1100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final pinned = tester.getSize(find.byType(PinnedGachaHud));
      expect(pinned.width, width);
      expect(pinned.height, 720);
      expect(find.byKey(const ValueKey('gacha-player-nameplate')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('kotohogi-bar-art')),
          findsOneWidget);
      expect(
        tester.widget<TicketCounterBadge>(
          find.byKey(const ValueKey('loose-hud-tickets')),
        ).tickets,
        7,
      );
      expect(tester.getSize(find.byKey(const ValueKey('kotohogi-bar-art'))).width,
          greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shared HUD stays fixed while scene scrolls at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> build(int tickets) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PinnedGachaHud(
              points: 170,
              tickets: tickets,
              ticketBadgeKey: const ValueKey('fixed-tickets'),
              contentBuilder: (context, height) => ListView(
                key: const ValueKey('scene-scroll'),
                children: [
                  const SizedBox(height: 1200),
                  Text('Remaining height ${height.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
        ));
      }

      await build(8);
      final name = find.byKey(const ValueKey('gacha-player-nameplate'));
      final points = find.byKey(const ValueKey('kotohogi-bar-art'));
      final tickets = find.byKey(const ValueKey('fixed-tickets'));
      expect(name, findsOneWidget);
      expect(points, findsOneWidget);
      expect(tickets, findsOneWidget);
      expect(tester.getRect(name).right, lessThan(tester.getRect(points).left));
      expect(tester.getRect(tickets).top,
          greaterThan(tester.getRect(points).bottom));
      final nameAt = tester.getRect(name);
      final pointsAt = tester.getRect(points);
      final ticketsAt = tester.getRect(tickets);
      await tester.drag(find.byKey(const ValueKey('scene-scroll')),
          const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(tester.getRect(name), nameAt);
      expect(tester.getRect(points), pointsAt);
      expect(tester.getRect(tickets), ticketsAt);
      expect(tester.widget<TicketCounterBadge>(tickets).tickets, 8);

      await build(7);
      expect(tester.getRect(name), nameAt);
      expect(tester.getRect(points), pointsAt);
      expect(tester.getRect(tickets), ticketsAt);
      expect(tester.widget<TicketCounterBadge>(tickets).tickets, 7);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
