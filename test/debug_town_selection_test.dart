import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/debug_menu_screen.dart';
import 'package:future_lift/dialogue_engine.dart';
import 'package:future_lift/game_home.dart';
import 'package:future_lift/main.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/town.dart';

import 'progress_test.dart' show MemoryStore;

void main() {
  test('debug override selects unowned residents without mutating ownership', () {
    final owned = [TownResident.shiba, TownResident.rabbit];
    expect(visibleTownResidents(owned), owned);
    final special = [TownResident.c027_daydreamer, TownResident.c026_farmer];
    expect(visibleTownResidents(owned, debugOverride: special), special);
    expect(visibleTownResidents(owned, debugOverride: []), isEmpty);
    expect(owned, [TownResident.shiba, TownResident.rabbit]);

    expect(
      () => visibleTownResidents(
        owned,
        debugOverride: [TownResident.shiba, TownResident.shiba],
      ),
      throwsArgumentError,
    );
    expect(
      () => visibleTownResidents(
        owned,
        debugOverride: TownResident.values.take(townResidentLimit + 1).toList(),
      ),
      throwsArgumentError,
    );
    expect(
      visibleTownResidents(
        owned,
        debugOverride: TownResident.values.take(townResidentLimit).toList(),
      ).length,
      townResidentLimit,
    );
  });

  testWidgets('debug cast changes home and town without writing save data',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = MemoryStore();
    final catalog = DialogueCatalog.fromJson(jsonEncode({
      'version': 1,
      'dialogues': [
        for (final resident in TownResident.values)
          {
            'id': 'fallback_${resident.id}',
            'residentId': resident.id,
            'text': 'こんにちは、${resident.label}です。',
            'priority': 0,
            'once': false,
            'logic': 'all',
            'conditions': [],
          },
      ],
    }));
    final controller = ProgressController(
      store,
      clock: () => DateTime(2026, 10, 15, 12),
    );
    await tester.pumpWidget(FutureLiftApp(
      controller: controller,
      dialogueCatalog: catalog,
      enableTutorial: false,
    ));
    await tester.pumpAndSettle();
    final originalSave = store.raw;
    final originalWrites = store.writes;

    await tester.tap(find.byKey(const ValueKey('footer-menu')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('debug-town-enable'));
    await tester.scrollUntilVisible(toggle, 200);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final selectedBefore = tester.widget<DebugMenuScreen>(
      find.byType(DebugMenuScreen),
    ).debugTownResidents;
    expect(selectedBefore, [TownResident.shiba, TownResident.rabbit]);

    final daydreamer = find.byKey(
      const ValueKey('debug-town-resident-027_daydreamer'),
    );
    await tester.scrollUntilVisible(daydreamer, 160);
    await tester.pumpAndSettle();
    await tester.tap(daydreamer);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DebugMenuScreen>(find.byType(DebugMenuScreen))
          .debugTownResidents,
      [TownResident.shiba, TownResident.rabbit, TownResident.c027_daydreamer],
    );

    await tester.tap(find.byKey(const ValueKey('footer-home')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GameHome>(find.byType(GameHome)).debugTownResidents,
      contains(TownResident.c027_daydreamer),
    );
    expect(
      find.byKey(const ValueKey('home-resident-sprite-027_daydreamer')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('footer-town')));
    await tester.pumpAndSettle();
    final town = tester.widget<TownScene>(find.byType(TownScene));
    expect(town.debugTownResidents,
        [TownResident.shiba, TownResident.rabbit, TownResident.c027_daydreamer]);
    expect(find.byKey(const ValueKey('resident-2')), findsOneWidget);

    // A preview dialogue must not record seen IDs or change the owned set.
    final dialogue = town.onResident!(TownResident.c027_daydreamer);
    await tester.pumpAndSettle();
    expect(find.text('こんにちは、おやすみくんです。'), findsOneWidget);
    await tester.tap(find.text('また話そう'));
    await tester.pumpAndSettle();
    await dialogue;
    expect(store.raw, originalSave);
    expect(store.writes, originalWrites);
    expect(controller.progress!.seenDialogues, isEmpty);
    expect(controller.progress!.residents.owned,
        [TownResident.shiba, TownResident.rabbit]);

    await tester.tap(find.byKey(const ValueKey('footer-menu')));
    await tester.pumpAndSettle();
    final restore = find.byKey(const ValueKey('debug-town-enable'));
    await tester.scrollUntilVisible(restore, 200);
    await tester.pumpAndSettle();
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DebugMenuScreen>(find.byType(DebugMenuScreen))
          .debugTownResidents,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('footer-town')));
    await tester.pumpAndSettle();
    expect(tester.widget<TownScene>(find.byType(TownScene)).debugTownResidents,
        isNull);
    expect(find.byKey(const ValueKey('resident-2')), findsNothing);
    expect(store.raw, originalSave);
    expect(store.writes, originalWrites);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
