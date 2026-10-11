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


## 2026-10-11 本番Supabaseソース同期

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| migration parity | `supabase/ENVIRONMENT_SYNC_STATUS.md`、`supabase/migrations/*.sql` | mainのデプロイ用ソースと本番履歴を94件で一致させる。既存関数定義と権限を照合した履歴補正のみを行い、適用済みSQLを再実行しない |
| 本番DBセキュリティ | `supabase/migrations/20261010233406_move_security_definer_rpcs_to_private_wrappers.sql`, `20261010233558_add_explicit_deny_policies_to_internal_tables.sql`, `20261011093000_harden_admin_policies_against_anonymous_auth.sql` | 特権RPCはprivate実装＋public invoker wrapper、内部テーブルはdeny-by-default、管理操作は非匿名管理者のみ。Security Source Checkを必須とする |
| 環境同期 | `supabase/config.toml`, `supabase/functions/`, `supabase/seed/production_master_data/` | 本番の関数実装・設定・マスターデータ復旧資材をソース管理し、秘密情報とユーザー所有データをコミットしない |

## 2026-10-11 build-time Supabase environment selection

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| Supabase環境の選択・Webアカウント削除 | `lib/main.dart`; `.github/workflows/production-android-build.yml`; `.github/workflows/google-play-test-release.yml`; `account-deletion/index.html`; `docs/account-deletion/index.html` | 本番AABは `APP_ENV=production` と本番 `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` をビルド時に注入し、承認済み本番URL以外なら起動を拒否する。Google Playのテスト配信は `APP_ENV=closed_test` を明示する。Webアカウント削除ページは通常版 / クローズドテスト版を明示選択し、選択した環境のURLとPublishable Keyだけを認証・削除要求に使う。CIのソースガードでコード・workflow・Webページの整合性を確認する |

## 2026-10-11 本番AAB workflowのソースブランチ固定

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| 本番AAB生成元 | `.github/workflows/production-android-build.yml` | 本番AABはレビュー済み `main` からのみ生成する。クローズドテスト配信は `feature/android-next-release` の専用workflowを使用し、本番workflowと混同しない。workflowは成果物生成のみを行い、Google Playへのアップロード・公開は行わない |
