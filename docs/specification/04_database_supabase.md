# Database / Supabase仕様

## 本番確認値 2026-09-27
主要行数: profiles 114、collection_history 14、events 4、achievements 18、event_achievements 18、places 1328、contents 1311、event_contents 1311、place_visits 8、user_event_preferences 104、user_event_participations 101、user_event_favorites 1、content_blocks 292、announcements 3、announcement_reads 15、roadside_station_registry 1234、geo_regions 57、geo_region_prefectures 141、collection_series 1、collection_series_places 1231、collection_series_regions 57、location_security_states 2、location_security_events 3、app_release_policies 1。

旧 `seichi` テーブルは本番に存在しない。

## 現行migration
本番migrationは、2026-09-26後半のapp release policy関連までGitへ回収済み。さらにStory Preview用 `20261005231529_story_preview_server_time.sql` をGit管理下へ追加済み。productionへの適用状態はSupabase migration履歴を正本として確認し、Gitにあることだけで本番適用済みとは判定しない。

## Edge Functions
本番確認:
- `delete-account` version 5 / ACTIVE / verify_jwt=false
- `import-roadside-station-registry` version 11 / ACTIVE / verify_jwt=true
- `enrich-roadside-station-gps` version 15 / ACTIVE / verify_jwt=true
- `reconcile-roadside-station-gps` version 1 / ACTIVE / verify_jwt=false
- `verify-roadside-station-gsi` version 2 / ACTIVE / verify_jwt=true

verify_jwt=falseだけで安全/危険を断定せず、Function内部の認証・呼出し経路を個別レビューする。

## RLS / Security Advisor
主要アプリテーブルはRLS有効。2026-09-27時点で `public.spatial_ref_sys` はRLS無効としてAdvisor ERROR。PostGIS由来のため、単純にRLSをONにせずPostGIS互換と公開権限を検証する。

Advisorは、policy無しRLSテーブル、public schemaのPostGIS extension、SECURITY DEFINER RPCの実行権限、匿名サインインに伴う警告、Leaked Password Protection無効も報告している。意図した公開APIと不要な権限を区別して是正する。

## 変更原則
DDLはmigrationとして管理し、適用後は本番migration履歴・RLS・RPC・アプリ互換を確認する。productionへ手作業で先行変更した場合は必ずGitへ回収する。ユーザー向けデータと、location_source / confidence / security metadata等の内部運用データを表示層で混同しない。



## 2026-10-08差分反映
- Story Preview用の `public.story_preview_server_time()` RPCを追加。authenticatedのみexecute可能で、collection/content/reward recordは変更しない。
- Version 17のStory Previewはこのserver clockを基準に1時間期限を判定する。
- `app_release_policies` はアプリ更新判定の正本。Play配信状態と先行して矛盾させない。
- 本番Edge Functionのaccount deletionは内部認証を要求したうえでadmin API削除を行う仕様を正本とする。
