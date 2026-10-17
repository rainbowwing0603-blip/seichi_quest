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

Edge Function `stamp-upload` には、次の3つの secret が必要です。値は GitHub やチャットへ貼り付けず、Supabase の Edge Function Secrets に登録してください。

- `STAMP_UPLOAD_TOKEN`: API 呼び出し用に生成した十分に長いランダムトークン
- `SUPABASE_PRODUCTION_SERVICE_ROLE_KEY`: 本番プロジェクトの service-role key
- `SUPABASE_TEST_SERVICE_ROLE_KEY`: テストプロジェクトの service-role key

本番・テストのキーは必ず別々に登録します。`target` の既定値は `production` です。`both` を指定すると両方へ書き込みます。

## GPT で画像を作成した直後の完全自動登録について

このスクリプトは、GPT で生成した画像ファイルが PC 上に保存された後の登録を自動化します。Edge Function は `imageBase64` を受け取る API ですが、ChatGPT の画像生成結果をそのままこの API の `imageBase64` に渡せる連携は、まだ検証されていません。「GPT 内で生成した瞬間に自動登録」まで完了したものではありません。service-role key を GPT の会話や公開 API に渡す方式は採用しないでください。

完全自動化するには、Edge Function のデプロイと secrets 登録に加え、生成画像の実データを安全に API へ渡せる GPT Action / クライアント連携が必要です。API 側は UUID、PNG 形式、サイズ、認証を検証し、本番・テストの認証情報を分離して Storage に書き込む構成です。