import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/dialogue_engine.dart';
import 'package:future_lift/progress.dart';
import 'package:future_lift/resident_collection.dart';

Map<String, Object> row(String id, String resident, String text, {
  int priority = 0,
  bool once = false,
  String logic = 'all',
  List<Map<String, Object>> conditions = const [],
}) => {
  'id': id,
  'residentId': resident,
  'text': text,
  'priority': priority,
  'once': once,
  'logic': logic,
  'conditions': conditions,
};

DialogueCatalog catalog(List<Map<String, Object>> additions) {
  final defaults = [
    for (final r in TownResident.values)
      row(r.id.replaceAll('0', '') + '_default', r.id, '通常の雑談'),
  ];
  return DialogueCatalog.fromJson(jsonEncode({
    'version': 1,
    'dialogues': [...defaults, ...additions],
  }));
}

Progress completed(List<Mission> missions) {
  var p = Progress.empty(DateTime(2026, 10, 13));
  for (final mission in missions) p = p.complete(mission);
  return p;
}

void main() {
  testWidgets('bundled JSON loads and every character has an ordinary line', (tester) async {
    final live = await DialogueCatalog.load();
    expect(live.entries.length, greaterThanOrEqualTo(24));
    final p = Progress.empty(DateTime(2026, 10, 13));
    for (final resident in TownResident.values) {
      expect(live.select(resident: resident, progress: p,
        now: DateTime.utc(2026, 10, 12, 15)), isA<DialogueEntry>());
    }
  });

  test('annual range, new year wrap, weekday, and exact date use JST', () {
    final conditions = [
      {'type':'date', 'mode':'annual_range','start':'12-20','end':'01-05'},
    ];
    final c = catalog([
      row('winter', '01_shiba', '冬だね', priority: 10, conditions: conditions),
      row('weekday', '02_rabbit', '月曜日', priority: 10, conditions: [
        {'type':'date', 'mode':'weekday','days':[1]},
      ]),
      row('one_day', '03_penguin', '今日だけ', priority: 10, conditions: [
        {'type':'date', 'mode':'exact','date':'2026-12-25'},
      ]),
    ]);
    final p = completed([]);
    DialogueEntry pick(TownResident r, DateTime utc) =>
      c.select(resident:r,progress:p,now:utc);
    expect(pick(TownResident.shiba,DateTime.utc(2026,12,24,15)).id, 'winter');
    expect(pick(TownResident.shiba,DateTime.utc(2027,1,4,15)).id, 'winter');
    expect(pick(TownResident.shiba,DateTime.utc(2027,1,6,15)).text, '通常の雑談');
    expect(pick(TownResident.rabbit,DateTime.utc(2026,10,11,15)).id,'weekday');
    expect(pick(TownResident.rabbit,DateTime.utc(2026,10,12,15)).text,'通常の雑談');
    expect(pick(TownResident.penguin,DateTime.utc(2026,12,24,15)).id,'one_day');
    expect(pick(TownResident.penguin,DateTime.utc(2026,12,25,15)).text,'通常の雑談');
  });

  test('AND/OR mission conditions, priorities and once shown persistence', () {
    final c=catalog([
      row('and','01_shiba','散歩と学び',priority:20,once:true,conditions:[
        {'type':'mission','missionId':'outside','minCount':1},
        {'type':'mission','missionId':'hobby','minCount':1},
      ]),
      row('or','01_shiba','どちらか達成',priority:10,logic:'any',conditions:[
        {'type':'mission','missionId':'outside','minCount':1},
        {'type':'kotohogi','min':100},
      ]),
    ]);
    const date = '2026-10-13';
    expect(date, isNotEmpty);
    final now=DateTime.utc(2026,10,12,15);
    var p=completed([Mission.outside]);
    expect(c.select(resident:TownResident.shiba,progress:p,now:now).id,'or');
    p=p.complete(Mission.hobby);
    expect(c.select(resident:TownResident.shiba,progress:p,now:now).id,'and');
    p=p.markDialogueSeen('and');
    expect(c.select(resident:TownResident.shiba,progress:p,now:now).id,'or');
    final restored=Progress.decode(p.encode(), expectedVersion:5);
    expect(restored.seenDialogues,contains('and'));
    expect(restored.countFor('outside'),1);
  });

  test('mission counters survive journal deletion, rollovers and debug resets', () {
    var p=completed([Mission.outside, Mission.hobby]);
    p=p.clearHistory().onDay(DateTime(2026,10,14)).complete(Mission.outside);
    expect(p.countFor('outside'),2);
    expect(p.countFor('all'),3);
    expect(p.history.length,1);
    final restored=Progress.decode(p.encode(), expectedVersion:5);
    expect(restored.countFor('outside'),2);
    expect(restored.resetMissionsForDebug().countFor('outside'),2);
    expect(restored.markDialogueSeen('hello').seenDialogues,contains('hello'));
  });

  test('legacy data migrates observed counts only, without inventing history', () {
    final original = completed([Mission.outside, Mission.hobby]);
    final raw=jsonDecode(original.encode()) as Map<String,dynamic>;
    raw['version']=4;
    raw.remove('missionCounts');
    raw.remove('seenDialogues');
    final old=Progress.decode(jsonEncode(raw),expectedVersion:4);
    expect(old.countFor('outside'),1);
    expect(old.countFor('hobby'),1);
    expect(old.countFor('all'),2);

    final cleared=Map<String,dynamic>.of(raw);
    cleared['history']={};
    // Current period completion flags remain consistent with a cleared journal.
    final migrated=Progress.decode(jsonEncode(cleared),expectedVersion:4);
    expect(migrated.countFor('outside'),0);
    expect(migrated.countFor('all'),2);
    expect(Progress.decode(migrated.encode()).countFor('outside'),0);
  });

  test('invalid catalogs and save counters fail instead of silently falling back', () {
    expect(() => DialogueCatalog.fromJson('{"version":1,"dialogues":[]}' ),
      throwsFormatException);
    final root=jsonDecode(jsonEncode({
      'version':1,
      'dialogues':[for(final r in TownResident.values)
        row(r.id.replaceAll('0','')+'_default',r.id,'普通')],
    })) as Map<String,dynamic>;
    for(final invalid in [
      {'type':'date','mode':'exact','date':'2026-02-30'},
      {'type':'date','mode':'annual_range','start':'00-01','end':'04-10'},
      {'type':'date','mode':'weekday','days':[0]},
      {'type':'mission','missionId':'unknown','minCount':3},
      {'type':'kotohogi','min':-1},
    ]) {
      final changed=jsonDecode(jsonEncode(root)) as Map<String,dynamic>;
      final entries=changed['dialogues'] as List;
      (entries[0] as Map<String,dynamic>)['conditions']=[invalid];
      expect(()=>DialogueCatalog.fromJson(jsonEncode(changed)),throwsFormatException,
        reason:invalid.toString());
    }
    final base=jsonDecode(completed([Mission.outside]).encode()) as Map<String,dynamic>;
    for(final counts in [
      {'outside':2},
      {'unknown':1},
      {'outside':-1},
      {'outside':1.2},
    ]) {
      expect(()=>Progress.decode(jsonEncode({...base,'missionCounts':counts})),
        throwsFormatException,reason:counts.toString());
    }
    expect(()=>Progress.decode(jsonEncode({...base,'seenDialogues':['a','a']})),
      throwsFormatException);
  });
}
