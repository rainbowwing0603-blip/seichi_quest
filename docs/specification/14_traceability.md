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
| 実績 | `progression_service.dart`, `widgets/quest_page.dart` | `achievements`, `event_achievements` |
| ランキング | `widgets/ranking_page.dart` | ranking RPC群 |
| お知らせ | `announcement_service.dart`, announcements widgets | `announcements`, `announcement_reads` |
| 広告 | `ad_placement_policy.dart`, banner/interstitial/rewarded services | GitHub Actions `production` Environment の3種類のAndroid AdMob unit variables、`--dart-define`、本番ビルドの形式/テストIDガード |
| 設定 | `app_settings_service.dart`, `app_settings_page.dart` | SharedPreferences |
| アプリ更新 | `app_version_service.dart` | `app_release_policies` |
| アカウント | `account_page.dart`, `session_service.dart` | Auth, `delete-account` |
| DB変更 | Flutter呼出し側 | `supabase/migrations/*.sql` |
| Privacy | app/account UI | `docs/privacy/index.html` |

| リリース・採番 | `.github/workflows/google-play-test-release.yml`, `pubspec.yaml` | Google Play Android Publisher API（既存Bundle最大versionCode + 1） |
| 仕様更新ゲート | `.github/workflows/specification-update-gate.yml` | PRの変更ファイルを検査し、実装・DB・CI/CD変更時の仕様書更新を要求 |

## 更新
ファイル移動・責務分割時はこの表も更新する。テーブルやRPCを削除する前に、対応するFlutter参照が残っていないか確認する。ユーザー向け表示と内部セキュリティ/GPS検証メタデータの境界もレビュー対象とする。

| Supabase環境分離 | `lib/main.dart`、リリースWorkflow | `APP_ENV` / `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY`。本番は別Supabaseプロジェクトを使用 |


## 2026-10-09 production schema rebuild

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| 参加状態 | `lib/services/event_service.dart` → `ensure_event_participation` RPC; `supabase/migrations/20261009010000_secure_event_participation_rpc.sql` | サーバー時刻、`auth.uid()`、非アクティブイベント拒否、直接書込権限の剥奪 |
| 本番DB設計 | `docs/production-schema-target.md`; `supabase/baselines/closed_test_catalog_snapshot_20261009.sql` | 現行カタログは参照用。新規DBでの空からの再構築とマスターデータ整合性テストが必要 |
| RLS/GRANT監査 | `supabase/security/production_rls_audit.sql` | 全公開テーブルのRLS、明示GRANT、関数EXECUTE、ビューのsecurity_invoker、他ユーザーアクセス拒否 |
| Supabaseソースガード | `scripts/check_supabase_security_source.py`; `.github/workflows/supabase-security-source-check.yml` | 固定キーの再混入、auto-exposure、欠落seed、参加RPCの権限要件を静的検査 |


## 2026-10-10 年代ベースのイベントおすすめ統合

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| イベントおすすめ | lib/services/event_recommendation_service.dart, lib/widgets/recommended_events_card.dart, lib/widgets/event_recommendation_section.dart | 未参加イベントのみ、属性集団5人以上、個人情報を返さない |
| 年代プロフィール | lib/widgets/profile_page.dart | 旧値 10代以下 の互換読込と新値 10代 の保存 |
| 推薦RPC | supabase/migrations/20261007211445_event_demographic_recommendations.sql, supabase/migrations/20261010120000_fix_event_recommendation_null_gender.sql | 年代のみ・性別NULLでも集計できること、「回答しない」を年代属性として扱わないこと、認証済みEXECUTEのみ |
