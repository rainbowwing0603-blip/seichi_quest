# 聖地クエスト スタンプ画像アップロード

## できること

透過 PNG を Storage の固定パス `content-media/stamps/{eventContentId}.png` に登録します。
既定では本番環境へ登録します。テストまたは両環境を指定する場合は API の `target` を指定します。`-ProductionOnly` または `-TestOnly` で登録先を限定できます。同じ UUID の既存オブジェクトは上書きされます。

## 実行方法（Windows PowerShell）

リポジトリのルートで実行します。

```powershell
.\tools\stamp-upload\Upload-SeichiStamp.ps1 -ImagePath "C:\path\to\stamp.png" -EventContentId "イベントコンテンツのUUID"
```

テスト環境だけに登録する場合：

```powershell
.\tools\stamp-upload\Upload-SeichiStamp.ps1 -ImagePath "C:\path\to\stamp.png" -EventContentId "イベントコンテンツのUUID" -TestOnly
```

実行時に Supabase Storage の service-role key を非表示入力します。キーをコマンド引数、スクリプト、Git、GPT の会話に貼り付けないでください。service-role key は RLS を迂回できる強い権限を持つため、信頼できる PC 上だけで使用してください。

環境変数 `SEICHI_PROD_SUPABASE_SERVICE_ROLE_KEY` と `SEICHI_TEST_SUPABASE_SERVICE_ROLE_KEY` が設定済みの場合は、その値を使用します。

## 注意点

- 入力ファイルは PNG である必要があります。透過を維持したい場合は、透過 PNG として書き出してください。
- `EventContentId` はイベントコンテンツの UUID です。スポット ID やイベント ID ではありません。
- Storage オブジェクトを登録する処理です。DB のイベントコンテンツやアプリ側の参照ロジックは変更しません。
- `content-media` バケットが存在し、Storage API が利用可能である必要があります。
- 既存ファイルを上書きするので、UUID を必ず確認してください。
- 本番・テスト両方への登録が既定です。片方だけ試す場合は `-TestOnly` / `-ProductionOnly` を指定してください。

## Edge Function の設定

本番 Edge Function は `https://npirfaoxcarfuqjlwgav.supabase.co/functions/v1/stamp-upload` にデプロイ済みです。現在の状態では `STAMP_UPLOAD_TOKEN` が未設定のため、アップロードはまだ有効化されていません。

本番だけを使う最小構成では、Supabase Dashboard の **Edge Functions → Secrets** に次の secret を追加します。値は GitHub やチャットへ貼り付けないでください。

- `STAMP_UPLOAD_TOKEN`: API 呼び出し用の長くランダムなトークン

本番プロジェクト側では Supabase が提供する `SUPABASE_SERVICE_ROLE_KEY` を使用します。テストまたは `both` を使う場合に限り、追加で `SUPABASE_TEST_SERVICE_ROLE_KEY` にテストプロジェクトの service-role key を登録してください。

API の JSON 本文は `{\"eventContentId\":\"イベントコンテンツUUID\",\"imageBase64\":\"PNGのBase64\",\"target\":\"production\"}`、認証ヘッダーは `x-stamp-upload-token` です。8 MiB 以下の PNG のみを受け付けます。

本番・テストのキーは必ず別々に登録します。`target` の既定値は `production` です。`both` を指定すると両方へ書き込みます。

## 自動登録の制約と確認

ChatGPT の通常チャットには Actions を追加できないため、この機能を使うには Actions を設定した専用 GPT 内で画像を生成します。OpenAI が提供する `openaiFileIdRefs` の一時URLを API が取得する方式なので、画像をPCへダウンロードして再アップロードする手順は不要です。Supabase の service-role key は GPT 側へ渡しません。

コードは本番 Edge Function にデプロイ済みですが、`STAMP_UPLOAD_TOKEN` と GPT Action の設定はユーザー側で必要です。これらの設定が完了するまで、エンドツーエンドの画像保存・アプリ表示は未検証です。