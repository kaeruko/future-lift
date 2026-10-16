# ことほぐ iOS App Storeビルド（GitHub Actions）

正式なBundle ID: `jp.cloxs.kotohogu`

`.github/workflows/ios-app-store.yml` は、公開リポジトリの標準 `macos-26`
ランナー上で署名付き `.ipa` を作る手動実行ワークフローです。
`workflow_dispatch` 専用で、外部プルリクエストから秘密鍵を利用しません。
既存の `.github/workflows/flutter.yml` の品質チェックは変更しません。

## Apple Developer（先に手動で行う）

1. Certificates, Identifiers & Profiles の Identifiers で、Explicit App ID `jp.cloxs.kotohogu` を登録。
2. WindowsならOpenSSL、MacならキーチェーンでCSRを作成し、Apple Distribution 証明書を発行。
3. 対応する秘密鍵とダウンロードした `.cer` からパスワード付き `.p12` を作成。
4. Profiles → Distribution → App Store Connect を選び、先ほどのApp IDとApple Distribution証明書を紐付けて `.mobileprovision` をダウンロード。

Windows PowerShell（作業場所は**リポジトリの外**）での例：

```powershell
mkdir "$HOME\kotohogu-ios-signing"
cd "$HOME\kotohogu-ios-signing"
openssl genrsa -aes256 -out kotohogu.key 2048
openssl req -new -sha256 -key kotohogu.key -out kotohogu.certSigningRequest -subj "/CN=Kotohogu Distribution"
# AppleにCSRを提出してApple Distribution証明書を取得後:
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey kotohogu.key -in distribution.pem -out kotohogu.p12
```

## GitHub Actions Secrets（リポジトリ Settings → Secrets and variables → Actions）

| Secret | 値 |
| --- | --- |
| `IOS_P12_BASE64` | `.p12` ファイルをBase64エンコードした内容 |
| `IOS_P12_PASSWORD` | `.p12` のエクスポート時に設定したパスワード |
| `IOS_PROFILE_BASE64` | `.mobileprovision` ファイルをBase64エンコードした内容 |

PowerShellでBase64にする例（ファイル名は置き換える）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.\kotohogu.p12')))
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.\kotohogu.mobileprovision')))
```

表示されたBase64値はGitHub Actions Secretsのみに入力する。チャット、Issue、
コード、ワークフローログに貼り付けない。秘密鍵（`.key`）、`.p12`、パスワード、
`.p8`、プロビジョニングプロファイルをGitで管理しない。

## ビルドする

1. GitHub → Actions → `iOS App Store IPA` → `Run workflow`。
2. Secretsを読み込み、一時キーチェーンに証明書を入れ、配布用プロファイルをインストール。
3. `ios/` がまだGitHubにないので、Flutter 3.47.6からiOS RunnerをCI上で生成。
   `tools/ios/prepare_xcode_project.py` が `jp.cloxs.kotohogu` に統一し、
   証明書とプロファイルを照合して手動署名・ExportOptionsを作成。
4. Xcode 26以上の環境で `flutter build ipa --release` を実行。
5. Actions実行結果 → Artifacts → `kotohogu-app-store-ipa` を取得。
   アーティファクトの保持期間は7日です。**公開リポジトリなので生成IPAを第三者が
   ダウンロードできる可能性があります。** 配布してよいビルドだけ実行してください。

このワークフローは**IPAを生成するだけ**です。App Store Connectへの自動アップロード、
TestFlightへの配信、App Store審査申請は行いません。
APIキー（`.p8`）も現段階では不要です。

**初回提出前の確認事項**：アプリアイコン、プライバシーポリシー、ストア用スクリーンショット、
正しいアプリ名、実機での起動とセーブ、健康Tipsの文言確認。
iOS設定を細かく変える段階では生成した `ios/` をリポジトリに確定することを推奨。
Flutter/Dartの実行テストや署名付きビルドの成功は、実際にActionsを走らせて確認してください。

## TestFlightにアップロードする（成功済みIPAを再利用）

`.github/workflows/ios-testflight-upload.yml` は **手動アップロード専用** です。
`iOS App Store IPA` で成功したrunのartifactを使い、再ビルドせず
App Store Connectへ送ります。リリースや外部テスターへの配信は自動で行いません。

追加のGitHub Actions Repository Secrets：

| Secret | 内容 |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect APIキーの10文字のKey ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID（UUID） |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | 該当APIキー `.p8` のBase64 |

Windows PowerShell（キーの**中身を画面に表示せず**GitHubへ貼る）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.\AuthKey_XXXXXXXXXX.p8'))) | Set-Clipboard
```

APIキーにはApp Store Connectの対象アプリのビルドアップロード権限が必要です。
Key IDと.p8は同じキーの組み合わせを使ってください。

1. Actions → `iOS App Store IPA` で署名付きIPAビルドが成功していることを確認。
2. Actions → `iOS TestFlight Upload` → `Run workflow` をクリック。
   **`source_run_id` は空欄のままでOK**。GitHubが採番した最新の成功済み
   `iOS App Store IPA` のRun IDを自動取得する。
3. 過去のIPAを選びたいときだけ、成功済みビルドURL
   （例：`/actions/runs/12345678901`）のRun IDを任意入力する。
4. アップロード後、App Store Connect → ことほぐ → TestFlight でAppleの処理を待つ。

ワークフローは選択したrunが **mainの成功済みiOS App Store IPA** で
あることを検証し、そのrunの `kotohogu-app-store-ipa` だけを取得。
展開後にBundle ID `jp.cloxs.kotohogu`、表示名、バージョン、
署名のTeam IDを確認してから `xcrun altool` で送信します。
別のrunにフォールバックしません。Artifactsの保存期限（7日）を過ぎたら、
ビルドワークフローを新しく実行してください。

**注意：** APIキーSecretは署名用Secret（`IOS_P12_BASE64`等）とは別。
TestFlightへアップロードしても、審査提出や一般公開はまだされません。
