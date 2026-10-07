# システム構成

## クライアント
Flutter / Dart。主要依存は Supabase Flutter、Google Maps、Geolocator、SharedPreferences、Google Mobile Ads、Flutter Local Notifications、URL Launcher、HTTP等。

`main.dart` はアプリ起動とメイン状態調停を担う。機能ロジックは `services/`、表示は `widgets/`、データ表現は `models/` に分離されつつある。

## バックエンド
Supabase project ref: `wxlvhpmolrtcwryaazfb`、Tokyoリージョン、PostgreSQL 17系。Database / Auth / Storage / Edge Functionsを利用。

## 起動
1. Flutter binding初期化
2. Supabase初期化
3. 最初のUI描画
4. Mobile Adsと通知SDKは初回フレーム後に遅延初期化
5. StartupCoordinatorでクラウドユーザー、イベント、収集同期、聖地データをクリティカル起動
6. 描画後に実績、クラウド履歴、NEXT、推奨ルート等を復元
7. オンボーディング完了後に位置情報を開始

## 状態
ユーザー、現在イベント、獲得ID、GPS位置、NEXT、推奨ルート、プロフィール、ランク、レベル、設定をメイン状態が統合する。永続化はSupabaseとSharedPreferencesの双方を使う。

## 広告状態
広告はBanner / Interstitial / Rewardedを分離して扱う。Rewarded Story Previewは `StoryRewardedAdService` と `StoryPreviewService` が担当し、ContentBlock表示側はRewarded利用可否と一時 entitlement を参照する。Android ReleaseのRewarded ad unit IDはbuild-time `--dart-define` から注入する。

## 注意
`main.dart` には依然として多くの調停責務がある。今後の機能追加は新しい巨大分岐をmainへ増やすより、Service/Policy/Coordinatorへ切り出す。



## 2026-10-08差分反映
- Mobile Ads / local notificationsは初回Flutter frame後へ遅延初期化し、Google Maps等のネイティブ初期化とmain thread負荷を分散する。
- Bannerはadaptive sizeを試行し、50dpを超える場合は通常Bannerへフォールバックする。
- Interstitialはstartup 3分、前回から15分、stamp後2分、画面滞在10秒をRelease基準とし、AdPlacementPolicyのblocking contextを通して自然な区切りだけで表示する。
- Rewarded Story PreviewはStoryRewardedAdService / StoryPreviewService / ContentRevealPolicyで分離する。
- SCREENSHOT_MODEはBanner/Interstitial/デバッグ用記念カード表示を抑制する。
- iOSはplatform-specific AdMob unitをbuild-time configurationで注入できる構造とする。
- Google Play / Codemagic操作はGitHub Actionsから安全な制御ブリッジ経由で実行できる。Production trackはtest-release workflowから選択できない。
