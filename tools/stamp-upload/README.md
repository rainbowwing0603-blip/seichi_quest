# 聖地クエスト スタンプ画像アップロード

## できること

透過 PNG を Storage の固定パス `content-media/stamps/{eventContentId}.png` に登録します。
既定では本番・テスト両方へ登録します。`-ProductionOnly` または `-TestOnly` で登録先を限定できます。同じ UUID の既存オブジェクトは上書きされます。

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

## GPT で画像を作成した直後の完全自動登録について

このスクリプトは、GPT で生成した画像ファイルが PC 上に保存された後の登録を自動化します。現在の ChatGPT 接続では、生成直後の画像バイナリをこのリポジトリや Supabase Storage に直接渡す経路が確立していないため、「GPT 内で生成した瞬間に自動登録」まで完了したものではありません。service-role key を GPT の会話や公開 API に渡す方式は採用しないでください。

完全自動化するには、認証付きアップロード API と、生成画像の実データをその API に渡す GPT Action / クライアント連携を別途接続・検証する必要があります。API 側は許可されたイベントコンテンツ UUID のみを受け取り、画像形式・サイズ・認証を検証してから Storage に書き込む構成にしてください。