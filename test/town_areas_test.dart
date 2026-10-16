import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/town.dart';
import 'package:future_lift/town_area_navigator.dart';
import 'package:future_lift/town_areas.dart';

void main() {
  test('stable area IDs and lifetime unlock thresholds', () {
    expect(TownArea.fromId('plaza'), TownArea.plaza);
    expect(TownArea.fromId('shopping'), TownArea.shopping);
    expect(TownArea.park.backgroundAsset,
        'assets/kotohogu/park_background_001.png');
    expect(TownArea.plaza.backgroundAsset,
        'assets/kotohogu/town_background_001.jpg');
    expect(TownArea.shopping.backgroundAsset,
        'assets/kotohogu/street_background_001.png');
    expect(() => TownArea.fromId('invalid'), throwsFormatException);
    expect(TownArea.plaza.isUnlocked(0), true);
    expect(TownArea.park.isUnlocked(89), false);
    expect(TownArea.park.isUnlocked(90), true);
    expect(TownArea.village.isUnlocked(299), false);
    expect(TownArea.village.isUnlocked(300), true);
  });

  test('source dimensions match bundled backgrounds exactly', () {
    for (final area in TownArea.values) {
      final asset = area.backgroundAsset;
      if (asset == null) {
        expect(area.sourceWidth, isNull);
        expect(area.sourceHeight, isNull);
        continue;
      }
      final pixels = _imageDimensions(File(asset).readAsBytesSync());
      expect(pixels.$1, area.sourceWidth,
          reason: '${area.id} background width');
      expect(pixels.$2, area.sourceHeight,
          reason: '${area.id} background height');
    }
  });

  test('residents are sorted into homes without a global eight-person cap', () {
    expect(TownResident.c026_farmer.homeAreaId, 'village');
    expect(TownResident.c027_daydreamer.homeAreaId, 'village');
    expect(TownResident.c009_chef.homeAreaId, 'shopping');
    final all = TownResident.values.toList();
    expect(areaResidents(all, TownArea.plaza),
        [TownResident.shiba, TownResident.penguin, TownResident.c036_mosa]);
    expect(areaResidents(all, TownArea.park),
        [TownResident.rabbit, TownResident.squirrel]);
    expect(areaResidents(all, TownArea.shopping),
        [TownResident.cat, TownResident.c009_chef, TownResident.c032_miner,
         TownResident.c035_beaty]);
    expect(areaResidents(all, TownArea.village),
        [TownResident.bear, TownResident.c026_farmer,
         TownResident.c027_daydreamer]);
    expect(areaResidents(all, TownArea.village,
        debugOverride: [TownResident.shiba, TownResident.c027_daydreamer]),
        [TownResident.c027_daydreamer]);
    expect(() => areaResidents(all, TownArea.plaza,
        debugOverride: [TownResident.shiba, TownResident.shiba]),
        throwsArgumentError);
  });

  testWidgets('village front door can be tapped without intercepting other areas',
      (tester) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var visits = 0;
    Future<void> show(TownArea area) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TownScene(
            level: 0,
            area: area,
            residents: const [],
            fillViewport: true,
            onEnterSalon: () => visits++,
          ),
        ),
      ));
      await tester.pump();
    }

    await show(TownArea.plaza);
    expect(find.byKey(const ValueKey('village-salon-entrance')), findsNothing);

    await show(TownArea.village);
    final door = find.byKey(const ValueKey('village-salon-entrance'));
    expect(door, findsOneWidget);
    await tester.tap(door);
    await tester.pump();
    expect(visits, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('arrows show park art then locked shopping area', (tester) async {
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
    expect(find.byKey(const ValueKey('town-background')), findsOneWidget);
    expect(find.text('景色を準備中だよ'), findsNothing);
    expect(find.byKey(const ValueKey('resident-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('resident-1')), findsOneWidget);
    await tester.drag(
      find.byType(TownAreaNavigator), const Offset(-170, 0));
    await tester.pumpAndSettle();
    expect(area, TownArea.shopping);
    expect(find.text('まだ行けないエリアだよ'), findsOneWidget);
    expect(find.textContaining('あと90ことほぎ'), findsOneWidget);
    expect(find.byKey(const ValueKey('area-resident-027_daydreamer')),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

/// Read only the PNG IHDR / JPEG SOF size fields; no asynchronous image
/// decoding or test-engine frame scheduling is involved.
(int, int) _imageDimensions(Uint8List data) {
  if (data.length < 24) {
    throw const FormatException('Image is too short for dimension metadata');
  }
  final header = ByteData.sublistView(data);
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (List.generate(8, (i) => data[i]).toString() == png.toString()) {
    if (String.fromCharCodes(data.sublist(12, 16)) != 'IHDR') {
      throw const FormatException('PNG has no IHDR header');
    }
    return (
      header.getUint32(16, Endian.big),
      header.getUint32(20, Endian.big),
    );
  }
  if (data[0] == 0xff && data[1] == 0xd8) {
    var index = 2;
    while (index + 4 < data.length) {
      if (data[index] != 0xff) {
        throw FormatException('Invalid JPEG marker at byte $index');
      }
      while (index < data.length && data[index] == 0xff) {
        index++;
      }
      if (index >= data.length) break;
      final marker = data[index++];
      if (marker == 0xd9 || marker == 0xda) break;
      if (marker == 0x01 || marker >= 0xd0 && marker <= 0xd7) {
        continue;
      }
      if (index + 2 > data.length) break;
      final length = header.getUint16(index, Endian.big);
      if (length < 2 || index + length > data.length) {
        throw FormatException('Invalid JPEG segment length: $length');
      }
      if ((marker >= 0xc0 && marker <= 0xc3) ||
          (marker >= 0xc5 && marker <= 0xc7) ||
          (marker >= 0xc9 && marker <= 0xcb) ||
          (marker >= 0xcd && marker <= 0xcf)) {
        if (length < 7) throw const FormatException('Invalid JPEG SOF');
        return (
          header.getUint16(index + 5, Endian.big),
          header.getUint16(index + 3, Endian.big),
        );
      }
      index += length;
    }
    throw const FormatException('JPEG has no supported SOF segment');
  }
  throw const FormatException('Only PNG and JPEG town art is supported');
}
