import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/local_content_preview.dart';

Map<String, Object?> resident(String id, String folder) => {
  'key': 'c$id',
  'id': id,
  'label': id == '037_tora' ? 'とらお' : '新しい住民',
  'artFolder': folder,
  'nextDialogueNumber': 2,
  'inGacha': true, 'walkInTown': true,
  'profile': '', 'homeAreaId': 'park',
};
Map<String, Object?> dialogue(String id, String speaker) => {
  'id': id, 'residentId': speaker, 'text': 'よろしくね！',
  'priority': 0, 'once': false, 'logic': 'all',
  'conditions': <Object>[],
};
String catalog(List<Object> residents, List<Object> lines) => jsonEncode({
  'version': 1, 'characters': residents, 'dialogues': lines,
});

void main() {
  test('new server resident is visible without a compiled enum', () {
    final result = RemoteContentCatalog.fromJson(catalog([
      resident('037_tora', '037_tora'),
      resident('038_owl', '038_owl'),
    ], [
      dialogue('037_tora_001', '037_tora'),
      dialogue('038_owl_001', '038_owl'),
    ]));
    expect(result.characters.length, 2);
    expect(result.residentById('038_owl').label, '新しい住民');
    expect(result.linesFor('038_owl').single.id, '038_owl_001');
    expect(remoteSpriteUri(
      localServerUri('http://10.0.2.2:8765'),
      result.residentById('038_owl'), 'walk_front_04.png',
    ).toString(), 'http://10.0.2.2:8765/api/runtime/sprites/038_owl/walk_front_04.png');
  });

  test('invalid host or URL cannot silently change the backend', () {
    for (final value in [
      '', 'https://example.com', 'http://example.com:8765',
      'http://10.0.2.2:8765/other', 'http://localhost:8765/?foo=1',
    ]) {
      expect(() => localServerUri(value), throwsFormatException);
    }
  });

  test('pinned HTTPS release uses one immutable catalog and sprite base', () {
    const hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final base = contentPreviewUri('https://d1234.cloudfront.net/releases/$hash/');
    expect(base.resolve('api/runtime/catalog').toString(),
        'https://d1234.cloudfront.net/releases/$hash/api/runtime/catalog');
    const person = RemoteResident(
      id: '038_owl', label: 'ふくろう', artFolder: '038_owl',
      profile: '', homeAreaId: 'park',
    );
    expect(remoteSpriteUri(base, person, 'idle_front_01.png').toString(),
        'https://d1234.cloudfront.net/releases/$hash/api/runtime/sprites/038_owl/idle_front_01.png');
    for (final bad in [
      'https://d1234.cloudfront.net/',
      'https://d1234.cloudfront.net/current.json',
      'https://d1234.cloudfront.net/releases/latest/',
      'https://d1234.cloudfront.net/releases/$hash',
      'https://d1234.cloudfront.net/releases/$hash/?ignored=1',
      'http://example.org/releases/$hash/',
    ]) {
      expect(() => contentPreviewUri(bad), throwsFormatException,
          reason: bad);
    }
  });

  test('unexpected image filename is rejected', () {
    const character = RemoteResident(id: '038_owl', label: 'new',
        artFolder: '038_owl', profile: '', homeAreaId: 'park');
    expect(() => remoteSpriteUri(localServerUri('http://127.0.0.1:8765'),
      character, '../other.png'), throwsArgumentError);
  });

  test('duplicate or orphan residents and incompatible versions fail fast', () {
    final tora = resident('037_tora', '037_tora');
    expect(() => RemoteContentCatalog.fromJson(catalog(
      [tora, tora], [dialogue('037_tora_001', '037_tora')])),
      throwsFormatException);
    expect(() => RemoteContentCatalog.fromJson(catalog(
      [tora], [dialogue('037_tora_001', '038_owl')])),
      throwsFormatException);
    expect(() => RemoteContentCatalog.fromJson(
      '{"version":2,"characters":[],"dialogues":[]}'), throwsFormatException);
  });
}
