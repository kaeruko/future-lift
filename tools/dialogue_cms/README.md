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

- キャラ管理画面で、各住民のプロフィール（自由文1項目、改行可、最大1000文字）を編集・保存
- キャラ別のセリフを追加・修正・削除（セリフIDはキャラID＋連番で自動発行。会話・豆知識の区別なし）
- 累計ミッション回数（合計・種類別）、ことほぎによる表示条件
- 指定日・指定期間・毎年の指定日・毎年の期間・曜日による表示条件
- 条件の AND / OR、優先順位、初回のみのセリフ
- まちに2人のキャラが実際に表示されているときだけ成立する条件と、相手の返事（掛け合い）
- 「特定のセリフIDを見たことがある」条件。全キャラ共通なので、別のキャラの会話を続きの条件にできます
- 仮の日付・ミッション実績によるセリフ表示プレビュー
- JSON スキーマ検証後、`assets/dialogues/dialogues.json` を安全に上書き

**保存後、公開済みのアプリが即時更新されるわけではありません。** JSONをGitにコミットし、Flutterアプリを再ビルドして反映してください。

```powershell
git status
git add assets/dialogues/dialogues.json assets/characters/characters.json
git commit -m "Update dialogue content and sequence counters"
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

セリフに種類の区別はありません。日付やミッションなどの条件に一致したセリフから優先順位の高いものを選びます。同じ優先順位のセリフは話しかけるたびに切り替わります。条件が無い、かつ `once=false` の通常セリフを各キャラ最低1件要求します。条件に合わない時は通常セリフに戻ります。**すべてのセリフ**について初回表示時にIDを閲覧済みとして保存します。`once=true` の行だけは、そのIDが閲覧済みになると以後の候補から外れます。

CMSの条件プレビューでは「見たことがあるセリフ（仮設定）」から既読IDを選択できます。実際のセーブデータは変更しません。

## 別キャラにも使える既読セリフID条件

セリフCMSの表示条件に「指定セリフを見たことがある」を追加して、全キャラのセリフIDから選択します。
セリフの種類やキャラID、2人の組み合わせに依存しない共通条件です。

```json
{
  "id": "03_penguin_001",
  "residentId": "03_penguin",
  "text": "さっきのお話の続き、聞かせてね",
  "priority": 20,
  "once": false,
  "logic": "all",
  "conditions": [
    {"type": "seenDialogue", "dialogueId": "009_chef_002"},
    {"type": "townTogether", "otherResidentId": "04_cat"}
  ],
  "reply": {"residentId": "04_cat", "text": "わたしも聞きたい！"}
}
```

この例はシェフの `009_chef_002` を見たことがあり、かつペンギンとねこが
まちにそろっているときだけ、2人の会話を表示します。セリフIDは全キャラを通じて一意です。
参照するセリフIDが存在しない・自分自身である場合は保存エラー。
参照先のセリフを削除する場合は、まず依存する条件を外す必要があります。
以前のセーブデータに既読記録がない通常セリフは、更新後に改めて表示されると記録されます。
セーブ形式（v5）およびセリフJSONの版（v1）は変更しません。

## まちで2人そろったときの特別な掛け合い

セリフCMSで発言するキャラを選び、表示条件に
「まちで2人そろう」を追加して、一緒にいる**相手キャラ**を選びます。
条件の組み合わせは AND にして、必要なら「＋ 相手の返事を追加」で
そのキャラの返事も入力します。相手がいなければこの掛け合いは出ません。

```json
{
  "id": "01_shiba_001",
  "residentId": "01_shiba",
  "text": "今日は雲をながめようよ",
  "priority": 20,
  "once": false,
  "logic": "all",
  "conditions": [
    {"type": "townTogether", "otherResidentId": "02_rabbit"}
  ],
  "reply": {"residentId": "02_rabbit", "text": "あの雲、絵に描きたい！"}
}
```

通常の1人のセリフは `reply` なしで従来通り。返事は省略可能です。
`reply` を付けるなら、AND条件の「まちで2人そろう」で指定した相手だけが
返事を話せます。違う人が返事をする定義は保存時に拒否します。
ゲーム内の判定は「所持している2人」だけではなく、ガチャの所持順から
「まちに表示」ONの住民を最大8人選んだ**実際の表示枠**に2人とも入ること。
ホームに並ぶキャラとまちの表示枠は同じ基準です。
CMSのプレビューではチェックした仮のまち住民を使って確認できます。
既存のセリフID・保存データ・通常会話と豆知識を分けない設計は変わりません。

## セリフIDの自動採番

セリフ管理タブで「キャラクターで絞る」から追加先を選び、「＋ セリフ追加」を押すと
`キャラID_連番` を自動発行します（例: `009_chef_001`, `009_chef_002`）。
番号は各キャラで独立しており、最低3桁のゼロ埋めです（1000件目は4桁）。
セリフID・所属キャラはセーブデータと閲覧済み記録の参照に使うため変更不可。
既存の `shiba_default_1` などの旧IDは変更せずに残します。

登録済みキャラの `nextDialogueNumber` は `assets/characters/characters.json` に
保存し、削除したセリフの番号も再利用しません。キャラの名前や、日付・ミッション条件、
セリフ本文、優先順位などは通常どおり編集できます。
CMS保存時はIDと連番が整合するか検証し、食い違いがあれば保存しません。


## 安全性

サーバーは `127.0.0.1` のみに待ち受け、PUTを同一オリジンに制限します。データはJSON検証後に一時ファイルへ書き、原子的に差し替えます。GitHubへの変更はCMSが自動では実行しません。

検証: `python -m unittest discover -s tools/dialogue_cms -p 'test_*.py'`


## キャラクター登録（CMS）

管理画面の「キャラクター管理」で「＋ キャラ追加」を押します。先に
`assets/characters/<キャラID>/` へスプライトを配置し、
名前・プロフィール・安定したキャラID（例: `009_chef`）・ガチャ登場・まちを歩くを指定します。
新規キャラは画像フォルダをIDと同じ名前にし、Dart識別子は `c` + ID（例: `c009_chef`）で自動生成します。
IDは数字2桁以上とアンダースコア・英小文字の名前で構成します。
セリフ管理タブには、そのキャラの `キャラID_001` という条件なしセリフが自動追加されています。会話も豆知識も同じセリフ欄から登録し、必要な条件を付けてください。

各フォルダには `idle_front_01.png`、`clap_front_01.png` と
`clap_front_02.png`、上下左右それぞれ `walk_<方向>_01.png`〜
`walk_<方向>_04.png` が必要です（元から存在するしばいぬのみ左向きを右画像反転で代用）。
例: `assets/characters/009_chef/`。フォルダがない場合や画像不足は保存エラーとなります。

キャラ設定に「Tipsの元キャラ」はありません。すべてのセリフは `assets/dialogues/dialogues.json` だけで管理します（セリフJSONは引き続きversion 1）。
キャラ定義JSONはプロフィール `profile`（最大1000文字の文字列、空欄可）を含むversion 4です。既存の登録住民は空文字で明示的に移行済みです。既存のID・採番カウンターはそのままです。

保存は `assets/characters/characters.json` と
`assets/dialogues/dialogues.json` に加えて、
`lib/resident_collection.dart` のCMS生成領域（`TownResident.profile` も使用可能）と
`pubspec.yaml` のキャラアセット登録領域を同期します。
既存住民のID・内部識別子・画像フォルダは変更・削除できません（既存の異なる命名は維持します）。
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

CMSはローカル専用です。プロフィールも含め、保存してGitへ反映・アプリ再ビルドするまで公開アプリには反映されません。プロフィールのゲーム内表示画面は今回追加しません。
カタログversion 4への移行前に、未保存のセリフやキャラ設定は必ず別途バックアップしてください。旧CMSを開いたままの保存は行わず、`git pull --ff-only` とサーバー再起動、ブラウザ再読み込みを行ってください。
