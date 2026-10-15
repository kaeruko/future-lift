import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/dialogue_engine.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/resident_conversation_dialog.dart';

void main() {
  final catalog = DialogueCatalog.fromJson(jsonEncode({
    'version': 1,
    'dialogues': [
      for (final resident in TownResident.values)
        {
          'id': 'ordinary_${resident.id}',
          'residentId': resident.id,
          'text': 'ひとりのおはなし',
          'priority': 0,
          'once': false,
          'logic': 'all',
          'conditions': [],
        },
      {
        'id': 'farmer_and_daydreamer',
        'residentId': '026_farmer',
        'text': 'おやすみくん。農業をやらんかね。',
        'priority': 60,
        'once': false,
        'logic': 'all',
        'conditions': [
          {'type': 'townTogether', 'otherResidentId': '027_daydreamer'},
        ],
        'reply': {
          'residentId': '027_daydreamer',
          'text': 'もふ？おひるねできる？',
        },
      },
    ],
  }));

  Future<void> openDialogue(
    WidgetTester tester,
    TownResident speaker,
    Set<String> visible,
  ) async {
    final line = catalog.select(
      resident: speaker,
      progress: Progress.empty(DateTime(2026, 10, 15)),
      now: DateTime.utc(2026, 10, 15),
      townResidentIds: visible,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => ResidentConversationDialog(
                  speaker: speaker,
                  dialogue: line,
                ),
              ),
              child: const Text('会話を開く'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('会話を開く'));
    await tester.pumpAndSettle();
  }

  testWidgets('tap the dialogue itself to show the other resident',
      (tester) async {
    await openDialogue(
      tester,
      TownResident.c026_farmer,
      {'026_farmer', '027_daydreamer'},
    );
    expect(find.text('やすぞう'), findsOneWidget);
    expect(find.text('おやすみくん。農業をやらんかね。'), findsOneWidget);
    expect(find.text('もふ？おひるねできる？'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dialogue-visible-line')));
    await tester.pumpAndSettle();

    expect(find.text('おやすみくん'), findsOneWidget);
    expect(find.text('やすぞう'), findsNothing);
    expect(find.text('おやすみくん。農業をやらんかね。'), findsNothing);
    expect(find.text('もふ？おひるねできる？'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.text('また話そう'));
    await tester.pumpAndSettle();
    expect(find.byType(ResidentConversationDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary dialogue still closes in one tap', (tester) async {
    await openDialogue(tester, TownResident.rabbit, {'02_rabbit'});
    expect(find.text('うさぎ'), findsOneWidget);
    expect(find.text('ひとりのおはなし'), findsOneWidget);
    expect(find.text('つづきへ'), findsNothing);
    expect(find.byKey(const ValueKey('dialogue-turn-count')), findsNothing);
    await tester.tap(find.text('また話そう'));
    await tester.pumpAndSettle();
    expect(find.byType(ResidentConversationDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
