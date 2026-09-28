# Media Studio (Debug only)

聖地クエストのSNS・ストア掲載用素材を、実際の `MapPage` と Google Maps から生成する開発者専用エントリポイントです。

## 起動

```powershell
flutter run --debug -t lib/main_media_studio.dart
```

通常の `lib/main.dart` からは import しません。Releaseビルドではこのエントリポイントを使用しないでください。さらに `main_media_studio.dart` 自身も `kDebugMode` を検査し、Debug以外ではStudioを起動しません。

## 一括生成

1. イベントを選択
2. 「全Nスポット一括生成」を押す
3. 各スポットで実際のGoogle Mapを描画
4. タイル安定待ち
5. 通常MAP素材を保存
6. STAMP GET状態を表示
7. 大きな `SAMPLE` 表示を焼き込んだ素材を保存
8. 次のスポットへ進む

保存先は Android の `Pictures/SeichiQuest/MediaStudio` です。

ファイル名例:

```
01_鬼押出し園_map.png
01_鬼押出し園_stamp_get_SAMPLE.png
02_伊香保石段街_map.png
02_伊香保石段街_stamp_get_SAMPLE.png
```

## 安全設計

- 広告SDKを初期化しない
- `BannerAdWidget` を構築しない
- collection_history へ書き込まない
- SharedPreferences の獲得状態を書き換えない
- ランキング・実績へ反映しない
- 疑似獲得画像には必ず `SAMPLE`
- 本番の `MapPage` を再利用し、動画専用の偽UIを作らない
- 画面キャプチャはAndroid `PixelCopy` で実ウィンドウを取得するため、Google MapsのPlatformViewも含める

## 注意

Google MapsをSNS・広告素材として利用する際は、Google Maps Platformの利用条件と画面内の帰属表示を維持してください。
