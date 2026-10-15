import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/town_area_navigator.dart';
import 'package:future_lift/town_areas.dart';

void main() {
  test('stable area IDs and lifetime unlock thresholds', () {
    expect(TownArea.fromId('plaza'), TownArea.plaza);
    expect(TownArea.fromId('shopping'), TownArea.shopping);
    expect(() => TownArea.fromId('invalid'), throwsFormatException);
    expect(TownArea.plaza.isUnlocked(0), true);
    expect(TownArea.park.isUnlocked(89), false);
    expect(TownArea.park.isUnlocked(90), true);
    expect(TownArea.village.isUnlocked(299), false);
    expect(TownArea.village.isUnlocked(300), true);
  });

  test('residents are sorted into homes without a global eight-person cap', () {
    expect(TownResident.c026_farmer.homeAreaId, 'village');
    expect(TownResident.c027_daydreamer.homeAreaId, 'village');
    expect(TownResident.c009_chef.homeAreaId, 'shopping');
    final all = TownResident.values.toList();
    expect(areaResidents(all, TownArea.plaza),
        [TownResident.shiba, TownResident.rabbit, TownResident.penguin]);
    expect(areaResidents(all, TownArea.park),
        [TownResident.squirrel, TownResident.bear]);
    expect(areaResidents(all, TownArea.shopping),
        [TownResident.cat, TownResident.c009_chef, TownResident.c032_miner]);
    expect(areaResidents(all, TownArea.village),
        [TownResident.c026_farmer, TownResident.c027_daydreamer]);
    expect(areaResidents(all, TownArea.village,
        debugOverride: [TownResident.shiba, TownResident.c027_daydreamer]),
        [TownResident.c027_daydreamer]);
    expect(() => areaResidents(all, TownArea.plaza,
        debugOverride: [TownResident.shiba, TownResident.shiba]),
        throwsArgumentError);
  });

  testWidgets('arrows navigate locked and artwork-pending areas', (tester) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TownArea area = TownArea.plaza;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        return TownAreaNavigator(
          area: area,
          onAreaChanged: (next) => setState(() => area = next),
          level: 0,
          lifetimePoints: 90,
          residents: const [
            TownResident.shiba, TownResident.rabbit,
            TownResident.squirrel, TownResident.c026_farmer,
          ],
        );
      })),
    ));
    expect(find.byKey(const ValueKey('town-background')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('town-area-next')));
    await tester.pumpAndSettle();
    expect(area, TownArea.park);
    expect(find.text('景色を準備中だよ'), findsOneWidget);
    expect(find.byKey(const ValueKey('town-background')), findsNothing);
    expect(find.byKey(const ValueKey('area-resident-05_squirrel')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('town-area-next')));
    await tester.pumpAndSettle();
    expect(area, TownArea.shopping);
    expect(find.text('まだ行けないエリアだよ'), findsOneWidget);
    expect(find.textContaining('あと90ことほぎ'), findsOneWidget);
    expect(find.byKey(const ValueKey('area-resident-027_daydreamer')),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
