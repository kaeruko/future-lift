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
