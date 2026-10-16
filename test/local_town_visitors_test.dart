import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/local_content_preview.dart';
import 'package:future_lift/local_town_visitors.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/town_areas.dart';

Map<String, Object?> character(String id, String area,
    {bool walk = true}) => {
  'key': 'c$id', 'id': id, 'label': id,
  'artFolder': id, 'nextDialogueNumber': 2,
  'inGacha': true, 'walkInTown': walk,
  'profile': '', 'homeAreaId': area,
};
Map<String, Object?> line(String speaker,
    {int priority = 0, bool once = false, List<Object> conditions = const []}) => {
  'id': '${speaker}_001', 'residentId': speaker, 'text': 'こんにちは！',
  'priority': priority, 'once': once, 'logic': 'all',
  'conditions': conditions,
};
RemoteContentCatalog catalog(List<Object> characters, List<Object> lines) =>
  RemoteContentCatalog.fromJson(jsonEncode({
    'version': 1, 'characters': characters, 'dialogues': lines,
  }));

void main() {
  test('unknown CMS resident joins plaza before home unlock, without duplicates', () {
    final content = catalog([
      character('01_shiba', 'plaza'),
      character('037_tora', 'park'),
      character('038_owl', 'park'),
      character('039_cat', 'salon', walk: false),
    ], [
      line('01_shiba'), line('037_tora'), line('038_owl'), line('039_cat'),
    ]);
    final before = localVisitorsForArea(
      content, TownArea.plaza, lifetimePoints: 0,
      owned: const [TownResident.shiba, TownResident.rabbit],
    );
    expect(before.map((row) => row.id), ['038_owl', '037_tora']);
    expect(localVisitorsForArea(content, TownArea.park,
      lifetimePoints: 0, owned: const [TownResident.shiba]), isEmpty);
    final after = localVisitorsForArea(
      content, TownArea.park, lifetimePoints: 90,
      owned: const [TownResident.shiba, TownResident.rabbit],
    );
    expect(after.map((row) => row.id), ['038_owl', '037_tora']);
    expect(localVisitorsForArea(content, TownArea.plaza,
      lifetimePoints: 90, owned: const [TownResident.shiba]), isEmpty);
    expect(localVisitorsForArea(content, TownArea.park,
      lifetimePoints: 90, owned: const [],
      debugTownSelectionActive: true), isEmpty);
  });

  test('every new remote-only resident appears without a fixed visitor cap', () {
    final chars = [
      for (var i = 40; i < 51; i++) character('${i}_new', 'plaza'),
    ];
    final lines = [
      for (var i = 40; i < 51; i++) line('${i}_new'),
    ];
    expect(localVisitorsForArea(catalog(chars, lines), TownArea.plaza,
      lifetimePoints: 0, owned: const []).length, 11);
  });

  test('visitor greeting picks unconditional non-once highest priority', () {
    final basic = catalog(
      [character('038_owl', 'park')],
      [
        line('038_owl', priority: 1),
        {
          ...line('038_owl', priority: 90),
          'id': '038_owl_002',
          'conditions': [
            {'type': 'mission', 'missionId': 'outside', 'minCount': 3},
          ],
        },
        {...line('038_owl', priority: 80, once: true), 'id': '038_owl_003'},
        {...line('038_owl', priority: 10), 'id': '038_owl_004'},
      ],
    );
    expect(visitorGreeting(basic, '038_owl').id, '038_owl_004');
  });

  test('missing non-once unconditional dialogue is invalid', () {
    expect(() => catalog(
      [character('038_owl', 'plaza')],
      [line('038_owl', once: true)],
    ), throwsFormatException);
  });
}
