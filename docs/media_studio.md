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
7. 獲得素材は背景・フレーム・札・文字を含む画面全体を粗いモザイク化し、内容を伏せた状態で保存
8. 次のスポットへ進む

保存先は Android の `Pictures/SeichiQuest/MediaStudio` です。

## PCへ一括回収してGPTへ渡す

Media Studioの生成は一度だけ行う想定です。生成後は、Androidエミュレータ内に残したまま運用せず、PCへ全画像を一括回収してGPTの動画制作入力にします。

PowerShell:

```powershell
cd C:\src\seichi_quest

$dest = ".\media_assets\app_captures"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

adb shell "mkdir -p /sdcard/Download/SeichiQuestMediaStudio"
adb shell "cp -f /sdcard/Pictures/SeichiQuest/MediaStudio/*.png /sdcard/Download/SeichiQuestMediaStudio/"
adb pull /sdcard/Download/SeichiQuestMediaStudio/. $dest

Get-ChildItem $dest -Filter *.png |
  Sort-Object Name |
  Select-Object Name, Length
```

回収先:

```text
media_assets/app_captures/
  01_鬼押出し園_map.png
  01_鬼押出し園_stamp_get_SAMPLE.png  # 獲得画面全体を粗いモザイク化
  02_伊香保温泉石段街_map.png
  02_伊香保温泉石段街_stamp_get_SAMPLE.png
  ...
```

命名規則はMedia Studio生成時のものをそのまま維持します。動画制作ではスポット番号とスポット名をキーに、現地素材とアプリキャプチャを対応付けます。

これは一回限りの素材回収を目的とした運用です。Media Studio自体にWindows固有の保存処理は追加せず、実アプリ画面の取得はAndroid側のPixelCopy、PCへの受け渡しだけADBで行います。

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
- 疑似獲得画像は画面全体を粗いモザイク化し、背景・フレーム・札・文字を含む獲得内容を動画で公開しない
- `SAMPLE` 表示も残し、Media Studio由来の疑似獲得素材であることを区別する
- 本番の `MapPage` を再利用し、動画専用の偽UIを作らない
- 画面キャプチャはAndroid `PixelCopy` で実ウィンドウを取得するため、Google MapsのPlatformViewも含める

## 注意

Google MapsをSNS・広告素材として利用する際は、Google Maps Platformの利用条件と画面内の帰属表示を維持してください。
