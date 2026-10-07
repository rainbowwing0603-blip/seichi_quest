# 広告・通知仕様

## 広告
`google_mobile_ads` を利用。Debug/ProfileはGoogle公式テスト用ID、Releaseは聖地クエスト本番AdMob App ID / Ad Unit IDを利用する。

Mobile Ads初期化は初回フレーム後へ遅延し、Google Maps初期化とネイティブmain thread負荷が集中しないようにする。InterstitialAdServiceのpreloadも地図初期化後に遅延する。BannerAdWidgetを利用する。

### Rewarded Story Preview
未獲得地点に対象Story/History等のContentBlockがある場合、Rewarded Adを任意視聴することで、その地点の物語を1時間だけ閲覧できる。広告視聴はスタンプ獲得を発生させない。

- 対象: after_collection の description / history / field_guide / story
- 対象外: スタンプ、実績、カード獲得、非対象block
- 有効期限: 1時間
- 時刻判定: 認証済みSupabase server clock
- 再開時、resume時、毎分で期限を確認
- 通信失敗時はプレビューを終了
- 権利はアカウント/コンテンツ単位の端末内保存で、別端末へ同期しない
- Release Androidでは `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID` を `--dart-define` で注入する
- ReleaseでRewarded IDが無い場合はボタンを表示せず、通常の未獲得コンテンツ表示へフォールバックする
- Rewarded Adは通常のInterstitial頻度制御と全画面表示ロックを共有する

## 方針
広告はゲーム体験を妨げないことを優先し、GPS到着・獲得の重要操作を広告表示で失敗させない。広告ロード失敗をアプリ機能失敗として扱わない。Rewarded Adはユーザーが明示的に選択した場合だけ表示する。

## 通知
`flutter_local_notifications` を利用。NotificationServiceは起動初回フレーム後に初期化する。通知設定画面を持つ。

## 将来
広告配置・頻度を変更する場合は収益だけでなく、地図操作、スタンプ獲得、イベント切替、初回起動時間への影響を確認する。
