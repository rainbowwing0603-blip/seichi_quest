# 仕様 ↔ コード対応表

| 領域 | 主なFlutter実装 | 主なSupabase/設定 |
|---|---|---|
| 起動 | `lib/main.dart`, `services/startup_coordinator.dart` | Supabase initialize |
| イベント | `services/event_service.dart`, `widgets/event_explore_page.dart` | `events`, `user_event_preferences`, `user_event_participations`, `user_event_favorites` |
| 地点 | `models/seichi.dart`, `services/seichi_service.dart` | `places`, `seichi` |
| GPS | `services/location_service.dart`, `services/stamp_eligibility_policy.dart` | place collection RPC群 |
| 獲得 | `collection_history_service.dart`, `services/collection_sync_service.dart` | `place_visits`, `collection_history` |
| キャッシュ | `services/stamp_cache_service.dart` | SharedPreferences + cloud history |
| NEXT | `services/next_destination_service.dart`, `services/destination_persistence_service.dart` | user/event scoped local state |
| 推奨ルート | `services/recommended_route_policy.dart` | local persistence |
| スタンプ帳 | `widgets/collection_page.dart` | collection history / content |
| コンテンツ | `models/content_block.dart`, `services/content_block_service.dart`, `widgets/content_block_renderer.dart` | `contents`, `event_contents`, `content_blocks`, `content-media` |
| 実績 | `services/progression_service.dart`, `widgets/quest_page.dart` | `achievements`, `event_achievements` |
| ランキング | `widgets/ranking_page.dart` | event ranking RPC群 |
| プロフィール | `services/profile_service.dart`, `widgets/profile_page.dart` | `profiles` |
| アカウント | `widgets/account_page.dart`, `services/session_service.dart` | Auth, `delete-account` |
| 広告 | `widgets/banner_ad_widget.dart`, `services/interstitial_ad_service.dart` | Android AdMob manifest placeholder |
| 通知 | `services/notification_service.dart`, `widgets/notification_settings_page.dart` | local notification |
| 設定 | `services/app_settings_service.dart`, `widgets/app_settings_page.dart` | SharedPreferences |
| 外部リンク | `services/external_navigation_service.dart` | URL Launcher |
| 天候 | `services/weather_service.dart`, `services/weather_refresh_policy.dart` | external HTTP |
| Android release | Android Gradle | key.properties / upload keystore |
| DB変更 | Flutter呼出し側 | `supabase/migrations/*.sql` |
| Privacy | app/account UI | `docs/privacy/index.html` |

## 更新
ファイル移動・責務分割時はこの表も更新する。テーブルやRPCを削除する前に、対応するFlutter参照が残っていないか確認する。


## 地図のソナー・方位表示・天候エフェクト

| 領域 | 実装・仕様 | 検証観点 |
|---|---|---|
| 地図ソナー | `lib/widgets/map_page.dart`, `lib/painters/sonar_painter.dart`, `lib/main.dart` | 目的地の取得範囲は薄い静的リングと低頻度の単発パルスで表示する。マーカー用アニメーションと地図オーバーレイ用アニメーションは別クロックで管理し、地図更新頻度を抑える。 |
| 方位追従 | `lib/widgets/map_page.dart`, `lib/main.dart`, `services/app_settings_service.dart` | 方位追従の切替は設定を永続化し、カメラ位置・ズームを維持して方位のみ変更する。方位データが無効な場合はカメラを回転させない。 |
| 天候エフェクト | `lib/widgets/weather_effect_overlay.dart` | 表示エフェクトの強度とアニメーション負荷を抑え、地図上の目的地・操作性を優先する。 |
