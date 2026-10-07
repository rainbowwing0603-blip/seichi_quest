# 仕様 ↔ コード対応表

| 領域 | 主なFlutter実装 | 主なSupabase/設定 |
|---|---|---|
| 起動 | `lib/main.dart`, `services/startup_coordinator.dart` | Supabase initialize |
| イベント | `services/event_service.dart`, `widgets/event_explore_page.dart`, `widgets/event_detail_page.dart` | `events`, preferences / participations / favorites |
| 地点・収集物 | `models/quest_item.dart`, `services/quest_item_service.dart`, `services/quest_item_mapper.dart` | `places`, `contents`, `event_contents` |
| GPS | `services/location_service.dart`, `services/stamp_eligibility_policy.dart` | place collection RPC群 |
| 不正対策 | `services/location_integrity_policy.dart`, `services/location_integrity_service.dart` | `location_security_states`, `location_security_events`, server-time RPC |
| 獲得 | `collection_history_service.dart`, `services/collection_sync_service.dart` | `place_visits`, `collection_history` |
| NEXT | `services/next_destination_service.dart`, `destination_persistence_service.dart` | user/event scoped local state |
| 地図表示 | `widgets/map_page.dart`, `quest_map_display_policy.dart`, `quest_map_cluster_service.dart` | viewport/event RPC群 |
| 地域進捗 | `regional_map_progress_service.dart` | geo region / collection series / regional progress RPC |
| ソナー | `painters/sonar_painter.dart`, `widgets/map_page.dart` | Place radius |
| 天候・太陽 | `weather_service.dart`, `solar_position_service.dart`, `weather_effect_overlay.dart` | external HTTP / local solar calculation |
| コンテンツ | `content_block_service.dart`, `content_block_renderer.dart`, `quest_spot_detail_sheet.dart` | `contents`, `event_contents`, `content_blocks`, Storage |
| 物語プレビュー | `services/story_rewarded_ad_service.dart`, `services/story_preview_service.dart`, `widgets/quest_item_content_section.dart` | Supabase server-time RPC / local entitlement |
| 実績 | `progression_service.dart`, `widgets/quest_page.dart` | `achievements`, `event_achievements` |
| ランキング | `widgets/ranking_page.dart` | ranking RPC群 |
| お知らせ | `announcement_service.dart`, announcements widgets | `announcements`, `announcement_reads` |
| 広告 | `ad_placement_policy.dart`, banner/interstitial services, `story_rewarded_ad_service.dart` | Android AdMob settings / build-time Rewarded ID |
| 設定 | `app_settings_service.dart`, `app_settings_page.dart` | SharedPreferences |
| アプリ更新 | `app_version_service.dart` | `app_release_policies` |
| アカウント | `account_page.dart`, `session_service.dart` | Auth, `delete-account` |
| DB変更 | Flutter呼出し側 | `supabase/migrations/*.sql` |
| Privacy | app/account UI | `docs/privacy/index.html` |

## 更新
ファイル移動・責務分割時はこの表も更新する。機能追加時は対応する仕様書と同じ変更単位でこの表を更新する。テーブルやRPCを削除する前に、対応するFlutter参照が残っていないか確認する。ユーザー向け表示と内部セキュリティ/GPS検証メタデータの境界もレビュー対象とする。
