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
| Privacy / account deletion | `privacy/index.html`, `account-deletion/index.html`, `lib/widgets/account_page.dart` | privacy policy, web deletion flow, production Supabase `delete-account` Edge Function |

| リリース・採番 | `.github/workflows/google-play-test-release.yml`, `pubspec.yaml` | Google Play Android Publisher API（既存Bundle最大versionCode + 1） |
| 仕様更新ゲート | `.github/workflows/specification-update-gate.yml` | PRの変更ファイルを検査し、実装・DB・CI/CD変更時の仕様書更新を要求 |

## 表示仕様: かるた札画像

絵札 (`picture_card`) と読み札 (`reading_card`) は同じ縦長フレーム比率 `730:909` で表示し、両方に `BoxFit.fill` を適用してフレーム全体を同じ寸法で埋める。元画像ごとの縦横比の違いで札の見える大きさが変わることを防ぐ。札画像は縦横比がわずかに変形する場合があるが、フレーム内で一方だけ小さく見えたり、余白が発生したりしないことを優先する。

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
| 推薦RPC | supabase/migrations/20261007211445_event_demographic_recommendations.sql, supabase/migrations/20261010181426_fix_event_recommendation_null_gender.sql | 年代のみ・性別NULLでも集計できること、「回答しない」を年代属性として扱わないこと、認証済みEXECUTEのみ |


## 2026-10-10 profile demographic fields

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| プロフィール属性 | `lib/widgets/profile_page.dart` → 4引数 `save_my_profile` RPC。既存3引数RPCは後方互換のため維持 | 性別は任意、許可値のみ保存、プロフィールを他ユーザーが変更できない |
| 推薦のプライバシー | `supabase/migrations/20261010181454_profile_gender_recommendation_rpc.sql` | 年代「回答しない」を属性集団にしない、性別未設定の利用者も利用可能 |
| プライバシーポリシー | `privacy/index.html` | 公開ページの内容とアプリ内の削除手順が一致すること。Web削除ページは本番SupabaseのURLとpublishable keyを使用し、テスト環境を参照しないこと |


## 2026-10-11 production profile RPC reconciliation

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| 本番プロフィールRPC追随 | `supabase/migrations/20261010231050_reconcile_profile_gender_recommendation_rpc.sql` | 本番DBで4引数 `save_my_profile` とNULL性別対応の `get_event_recommendations` を確認。3引数RPCの後方互換とauthenticated-only EXECUTEを維持 |


## 2026-10-11 PostGIS API hardening follow-up

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| PostGIS extent RPC | `supabase/migrations/20261010231230_restrict_public_postgis_extent_rpc.sql` | 管理対象の拡張関数は所有者権限によりACL変更が拒否される場合があるため、`has_function_privilege` と Security Advisor の再確認を必須とする。失敗時に権限変更済みとみなさない |


## 2026-10-11 production ranking RPC grants

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| 公開ランキングRPC | `supabase/migrations/20261011090000_restrict_public_ranking_to_authenticated.sql` | `PUBLIC` と `anon` のEXECUTEを剥奪し、`authenticated` と `service_role` を維持。未認証の直接RPC呼出しは拒否し、匿名サインイン済みアプリセッションではランキング表示を維持する |


## 2026-10-11 production SECURITY DEFINER RPC isolation

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| 特権RPCの分離 | `supabase/migrations/20261010233406_move_security_definer_rpcs_to_private_wrappers.sql` | 14個の実装を非公開の `private` スキーマへ移し、`public` は `SECURITY INVOKER` ラッパーに限定。アプリ向け引数・戻り値・authenticated実行権限を維持し、`anon` と `PUBLIC` の実行を拒否 |
| 内部セキュリティテーブル | `event_collection_resets`, `location_security_events`, `location_security_states`, `roadside_station_registry` | RLS有効、APIロールへの直接テーブル権限なし。RLSポリシーなしは意図的なdeny-by-defaultとして扱い、警告を消すための公開ポリシー追加は行わない |


## 2026-10-11 production internal-table deny policies

| 領域 | 主な実装・仕様 | 必須検証 |
|---|---|---|
| 内部テーブルの直接アクセス防止 | `supabase/migrations/20261010233558_add_explicit_deny_policies_to_internal_tables.sql` | 運用テーブル4件と `private.admin_users` に `anon` / `authenticated` 向けの明示的な拒否ポリシーを設定。既存の特権RPCの処理権限と直接テーブル権限の不存在を確認 |
| 匿名サインインに関するAdvisor通知 | `authenticated` ロールを使う匿名サインイン方式と公開コンテンツの読み取りポリシー | 自分の履歴のみ読める制約と公開コンテンツの読み取りを維持。通知を消す目的で匿名サインインや必要な読み取りを無効化しない |
