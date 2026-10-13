import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/gacha_hud.dart';
import 'package:future_lift/ticket_counter_badge.dart';

void main() {
  for (final width in <double>[296, 340, 550]) {
    testWidgets('gacha tickets sit below kotohogi on ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width + 20, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: GachaHud(
                  points: 170,
                  tickets: 7,
                  ticketBadgeKey: const ValueKey('gacha-screen-tickets'),
                ),
              ),
            ),
          ),
        ),
      );
      final kotohogi = find.byKey(const ValueKey('kotohogi-bar-art'));
      final tickets = find.byKey(const ValueKey('gacha-screen-tickets'));
      expect(kotohogi, findsOneWidget);
      expect(tickets, findsOneWidget);
      final nameplate = find.byKey(const ValueKey('gacha-player-nameplate'));
      final name = find.byKey(const ValueKey('player-display-name'));
      expect(name, findsOneWidget);
      expect(tester.widget<Text>(name).data, 'ハル');
      final nameRect = tester.getRect(name);
      expect(nameRect.left, greaterThan(tester.getRect(nameplate).left));
      expect(nameRect.right, lessThanOrEqualTo(
        tester.getRect(nameplate).right));
      final availableWidth = width - GachaHud.horizontalGap;
      expect(tester.getSize(nameplate).width,
          closeTo(availableWidth * GachaHud.nameplateShare, .02));
      expect(tester.getSize(kotohogi).width,
          closeTo(availableWidth * GachaHud.balanceShare, .02));
      expect(tester.getRect(nameplate).right,
          lessThan(tester.getRect(kotohogi).left));
      expect(find.byKey(const ValueKey('total-points')), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('total-points'))).right,
          lessThanOrEqualTo(tester.getRect(kotohogi).right + 1));
      expect(find.text('所持ガチャ券'), findsNothing);
      expect(tester.widget<TicketCounterBadge>(tickets).tickets, 7);
      expect(tester.getRect(tickets).top,
          greaterThan(tester.getRect(kotohogi).bottom));
      expect(tester.getRect(tickets).right,
          lessThanOrEqualTo(tester.getRect(kotohogi).right + 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ticket count stays live under the same kotohogi bar',
      (tester) async {
    Widget hud(int tickets) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 340,
          child: GachaHud(
            points: 60,
            tickets: tickets,
            ticketBadgeKey: const ValueKey('reveal-tickets'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(hud(10));
    final badge = find.byKey(const ValueKey('reveal-tickets'));
    expect(tester.widget<TicketCounterBadge>(badge).tickets, 10);
    await tester.pumpWidget(hud(9));
    expect(tester.widget<TicketCounterBadge>(badge).tickets, 9);
    expect(tester.takeException(), isNull);
  });
}
