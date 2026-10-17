import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/dialogue_engine.dart';
import 'package:future_lift/marche.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/town.dart';
import 'package:future_lift/town_areas.dart';

Progress tonkoProgress({bool owned = true}) => Progress(
  day: '2026-10-17',
  lastCompletedDay: null,
  points: 300,
  residents: ResidentCollection(
    baselinePoints: 0,
    counts: {
      '01_shiba': 1,
      '02_rabbit': 1,
      if (owned) '041_pig_middle': 1,
    },
  ),
  completed: {},
);

void main() {
  test('opening the stall requires owning Tonko and her saved dialogue', () {
    final owned = tonkoProgress();
    final unowned = tonkoProgress(owned: false);
    expect(isMarcheOpen(owned), isFalse);
    expect(isMarcheOpen(owned.markDialogueSeen('041_pig_middle_032')), isFalse);
    expect(isMarcheOpen(unowned.markDialogueSeen(tonkoMarcheOpeningDialogueId)),
        isFalse);
    final open = owned.markDialogueSeen(tonkoMarcheOpeningDialogueId);
    expect(isMarcheOpen(open), isTrue);
    expect(isMarcheOpen(Progress.decode(open.encode(), expectedVersion: 5)),
        isTrue);
    expect(isMarcheOpen(open.onDay(DateTime(2026, 10, 18))), isTrue);
  });

  test('the checked-in story progresses into the opening in five chats', () {
    final catalog = DialogueCatalog.fromJson(
        File('assets/dialogues/dialogues.json').readAsStringSync());
    var progress = tonkoProgress();
    final milestones = [
      '041_pig_middle_011', '041_pig_middle_021',
      '041_pig_middle_022', '041_pig_middle_032',
      tonkoMarcheOpeningDialogueId,
    ];
    for (final id in milestones) {
      final entry = catalog.select(
        resident: tonkoMarcheOwner,
        progress: progress,
        now: DateTime.utc(2026, 10, 17),
      );
      expect(entry.id, id);
      expect(isMarcheOpen(progress), isFalse);
      progress = progress.markDialogueSeen(entry.id);
    }
    expect(isMarcheOpen(progress), isTrue);
    final greeting = catalog.entries.singleWhere(
        (entry) => entry.id == tonkoMarcheGreetingDialogueId);
    expect(greeting.residentId, tonkoMarcheOwner.id);
    expect(greeting.once, isFalse);
    expect(greeting.matches(progress, DateTime.utc(2026, 10, 17), {}),
        isTrue);
    for (var rotation = 0; rotation < 30; rotation++) {
      expect(catalog.select(
        resident: tonkoMarcheOwner,
        progress: progress,
        now: DateTime.utc(2026, 10, 17),
        rotation: rotation,
      ).id, isNot(tonkoMarcheGreetingDialogueId));
    }
  });

  testWidgets('stall is shown only in the opened plaza and can be tapped',
      (tester) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var visits = 0;
    Widget scene(TownArea area, bool open) => MaterialApp(
      home: Scaffold(
        body: TownScene(
          level: 0, area: area, lifetimePoints: 300,
          residents: const [], fillViewport: true,
          marcheOpen: open,
          onVisitMarche: () { visits++; },
        ),
      ),
    );
    const key = ValueKey('plaza-marche-entrance');
    await tester.pumpWidget(scene(TownArea.plaza, false));
    expect(find.byKey(key), findsNothing);
    await tester.pumpWidget(scene(TownArea.park, true));
    expect(find.byKey(key), findsNothing);
    await tester.pumpWidget(scene(TownArea.plaza, true));
    expect(find.byKey(key), findsOneWidget);
    final rect = tester.getRect(find.byKey(key));
    expect(rect.width, greaterThan(60));
    expect(rect.height, greaterThan(60));
    await tester.tap(find.byKey(key));
    await tester.pump();
    expect(visits, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('the transparent market image fits the plaza source canvas', () {
    final bytes = File('assets/kotohogu/marche.png').readAsBytesSync();
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = bytes.buffer.asByteData();
    expect(header.getUint32(16), 540);
    expect(header.getUint32(20), 474);
    expect(bytes[25], 6);
    expect(plazaMarcheRect.right, lessThan(768));
    expect(plazaMarcheRect.bottom, lessThan(1376));
  });
}
