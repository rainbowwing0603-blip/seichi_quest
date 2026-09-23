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
