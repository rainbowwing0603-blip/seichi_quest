# 広告・通知仕様

## 広告
`google_mobile_ads` を利用。Debug/ProfileはGoogle公式テスト用App ID、Releaseは聖地クエスト本番App IDをGradle manifestPlaceholderで切り替える。

Mobile Ads初期化は初回フレーム後へ遅延し、Google Maps初期化とネイティブmain thread負荷が集中しないようにする。InterstitialAdServiceのpreloadも地図初期化後に遅延する。BannerAdWidgetを利用する。

## 方針
広告はゲーム体験を妨げないことを優先し、GPS到着・獲得の重要操作を広告表示で失敗させない。広告ロード失敗をアプリ機能失敗として扱わない。

## 通知
`flutter_local_notifications` を利用。NotificationServiceは起動初回フレーム後に初期化する。通知設定画面を持つ。

## 将来
広告配置・頻度を変更する場合は収益だけでなく、地図操作、スタンプ獲得、イベント切替、初回起動時間への影響を確認する。
