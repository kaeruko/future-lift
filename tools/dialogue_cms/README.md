# コトホグ セリフCMS（ローカル専用）

外部サービスやDBは不要。Python標準ライブラリだけで動く、ブラウザ用の編集画面です。

## 起動する

PowerShell でリポジトリのルートから:

```powershell
cd C:\Users\mail\work\kotohogu
python tools/dialogue_cms/server.py
```

ブラウザで **http://127.0.0.1:8765** を開く。終了はターミナルで Ctrl+C。

## できること

- キャラ別のセリフを追加・修正・削除
- 累計ミッション回数（合計・種類別）、ことほぎによる表示条件
- 指定日・指定期間・毎年の指定日・毎年の期間・曜日による表示条件
- 条件の AND / OR、優先順位、初回のみのセリフ
- 仮の日付・ミッション実績によるセリフ表示プレビュー
- JSON スキーマ検証後、`assets/dialogues/dialogues.json` を安全に上書き

**保存後、公開済みのアプリが即時更新されるわけではありません。** JSONをGitにコミットし、Flutterアプリを再ビルドして反映してください。

```powershell
git status
git add assets/dialogues/dialogues.json
git commit -m "Update dialogue content"
git push
```

## 累計カウントと古いセーブについて

アプリ内部の保存形式はv5。従来v4から明示的に移行し、過去の履歴に残っている種類別ミッション回数のみを初期カウントとして復元します。すでに削除された履歴、同日デバッグ再達成など不明な過去の回数は作りません。新しい達成は累計カウントへ加算され、履歴を削除しても減りません。全ミッション累計だけは既存の「ことほぎ ÷ 10」で確定できます。

## 条件仕様

```json
{
  "id": "shiba_sakura_outside_5",
  "residentId": "01_shiba",
  "text": "桜の季節だね！最近のお散歩はどうだった？",
  "priority": 20,
  "once": false,
  "logic": "all",
  "conditions": [
    { "type": "date", "mode": "annual_range", "start": "03-20", "end": "04-10" },
    { "type": "mission", "missionId": "outside", "minCount": 5 }
  ]
}
```

日本時間（JST）で日付を判定します。指定期間の両端を含めます。毎年の期間は12月〜1月の年越しも扱えます。閏日の年次セリフは2月29日がある年のみ表示します。曜日は月曜=1〜日曜=7です。

同じ優先順位のセリフは話しかけるたびに切り替わります。条件が無い、かつ `once=false` の通常セリフを各キャラ最低1件要求します。条件に合わない時は通常セリフに戻ります。`once=true` の行はセリフID単位で閲覧済みが保存されます。

編集画面の条件プレビューは、閲覧済みのセリフIDを持たない仮ユーザーとして判定します。

## 安全性

サーバーは `127.0.0.1` のみに待ち受け、PUTを同一オリジンに制限します。データはJSON検証後に一時ファイルへ書き、原子的に差し替えます。GitHubへの変更はCMSが自動では実行しません。

検証: `python -m unittest discover -s tools/dialogue_cms -p 'test_*.py'`


## キャラクター登録（CMS）

管理画面の「キャラクター管理」で「＋ キャラ追加」を押します。先に
`assets/characters/<画像フォルダ名>/` へスプライトを配置し、
名前・安定したキャラID・Dart識別子・画像フォルダ・ガチャ登場・まちを歩くを指定します。
セリフ管理タブには、そのキャラの通常セリフが自動追加されています。

各フォルダには `idle_front_01.png`、`clap_front_01.png` と
`clap_front_02.png`、上下左右それぞれ `walk_<方向>_01.png`〜
`walk_<方向>_04.png` が必要です（元から存在するしばいぬのみ左向きを右画像反転で代用）。
例: `assets/characters/008_hukurou.png/`。フォルダがない場合や画像不足は保存エラーとなります。

保存は `assets/characters/characters.json` と
`assets/dialogues/dialogues.json` に加えて、
`lib/resident_collection.dart` のCMS生成領域と
`pubspec.yaml` のキャラアセット登録領域を同期します。
既存住民のID・内部識別子・画像フォルダは変更・削除できません。
所持済み住民を安全に保持するため、ガチャ対象外やまち非表示にするフラグを使用してください。
ガチャは「ガチャに登場」がONのキャラから等確率で選びます。
まちで表示する住民は従来どおり最大8人までです。

```powershell
python -m unittest discover -s tools/dialogue_cms -p 'test_*.py'
flutter analyze
flutter test
git status
git add assets/characters/characters.json assets/dialogues/dialogues.json lib/resident_collection.dart pubspec.yaml
git commit -m "Update residents with local CMS"
git push
```

CMSはローカル専用です。セリフ編集もキャラクター追加も公開アプリへの即時反映はしません。
