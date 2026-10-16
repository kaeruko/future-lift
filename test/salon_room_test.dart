import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/salon_room.dart';
import 'package:future_lift/town_areas.dart';

void main() {
  test('salon host is not in the gacha or outdoor walking roster', () {
    expect(SalonRoom.host.id, '031_kimono_fox');
    expect(SalonRoom.host.inGacha, false);
    expect(SalonRoom.host.walkInTown, false);
    expect(TownResident.gachaPool, isNot(contains(SalonRoom.host)));
    expect(areaResidents(TownResident.values, TownArea.village),
        isNot(contains(SalonRoom.host)));
  });

  testWidgets('fox steps in place, claps, and pauses for dialogue',
      (tester) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gate = Completer<void>();
    var conversations = 0;
    await tester.pumpWidget(MaterialApp(
      home: SalonRoom(onResident: (_) {
        conversations++;
        return gate.future;
      }),
    ));
    final fox = find.byKey(const ValueKey('salon-fox-resident'));
    final sprite = find.byKey(const ValueKey('salon-fox-sprite'));
    String asset() => (tester.widget<Image>(sprite).image as AssetImage).assetName;
    final position = tester.getRect(fox);

    expect(asset(), SalonRoom.host.idleAsset);
    await tester.pump(const Duration(milliseconds: 800));
    expect(asset(), SalonRoom.host.walkAsset(WalkDirection.front, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(asset(), SalonRoom.host.walkAsset(WalkDirection.front, 1));
    await tester.pump(const Duration(milliseconds: 5400));
    expect(asset(), SalonRoom.host.clapAssets[0]);
    await tester.pump(const Duration(milliseconds: 400));
    expect(asset(), SalonRoom.host.clapAssets[1]);
    expect(tester.getRect(fox), position);

    await tester.tap(fox);
    await tester.pump();
    expect(conversations, 1);
    expect(asset(), SalonRoom.host.idleAsset);
    await tester.pump(const Duration(seconds: 3));
    expect(asset(), SalonRoom.host.idleAsset);
    await tester.tap(fox);
    await tester.pump();
    expect(conversations, 1, reason: 'Do not start overlapping conversations');

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(asset(), SalonRoom.host.clapAssets[1]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps salon fox idle', (tester) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const SalonRoom(),
      ),
    ));
    final sprite = find.byKey(const ValueKey('salon-fox-sprite'));
    String asset() => (tester.widget<Image>(sprite).image as AssetImage).assetName;
    expect(asset(), SalonRoom.host.idleAsset);
    await tester.pump(const Duration(seconds: 10));
    expect(asset(), SalonRoom.host.idleAsset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the salon host is always visible and can use regular dialogue',
      (tester) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TownResident? spokenTo;

    await tester.pumpWidget(MaterialApp(
      home: SalonRoom(onResident: (resident) async {
        spokenTo = resident;
      }),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('salon-background')), findsOneWidget);
    final host = find.byKey(const ValueKey('salon-fox-resident'));
    expect(host, findsOneWidget);
    await tester.tap(host);
    await tester.pump();
    expect(spokenTo, SalonRoom.host);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
