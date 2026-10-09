# Database / Supabase仕様

## 本番確認値 2026-09-27
主要行数: profiles 114、collection_history 14、events 4、achievements 18、event_achievements 18、places 1328、contents 1311、event_contents 1311、place_visits 8、user_event_preferences 104、user_event_participations 101、user_event_favorites 1、content_blocks 292、announcements 3、announcement_reads 15、roadside_station_registry 1234、geo_regions 57、geo_region_prefectures 141、collection_series 1、collection_series_places 1231、collection_series_regions 57、location_security_states 2、location_security_events 3、app_release_policies 1。

旧 `seichi` テーブルは本番に存在しない。

## 現行migration
本番履歴は2026-09-27確認時点で `20260926225451_add_app_release_policy` まで適用済み。Git側には2026-09-26時点の最新コードツリーで `20260926122330_use_server_time_for_collection` までが確認できるため、**20260926後半の本番migrationをGitへ回収することが要確認事項**。

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


## 再構築方針 2026-10-09

2026-09-27の行数・migration履歴は過去のスナップショットであり、現在値として扱わない。2026-10-09にクローズドテストDBのカタログ定義を取得し、別途 `docs/production-schema-target.md` に新しい本番モデルと権限設計を記録した。

本番DBは旧テーブル構成を丸ごと複製せず、現行アプリ契約に必要な汎用 `events / places / contents / event_contents / content_blocks` モデルを中心に構築する。廃止済み `public.seichi`、一時的なCodeMagic bridge、ユーザー履歴・プロフィール等のテストDBデータは本番初期データに含めない。

## RLS / GRANT / RPCの必須ルール

- API公開スキーマ内のアプリテーブルはRLSを有効にし、テーブルGRANTと行ポリシーを別々に最小権限で設定する。
- クライアントに不要な内部・管理・位置情報セキュリティテーブルには、`anon` / `authenticated` の直接アクセス権を与えない。
- Supabase匿名認証ユーザーもPostgresの `authenticated` ロールを持つため、ロール判定だけで本人性を判断しない。所有行は `auth.uid()` によって制限する。
- スタンプ獲得と訪問記録は検証済みRPC経由とし、履歴テーブルへの直接INSERT/UPDATE/DELETEで検証を迂回できないようにする。
- SECURITY DEFINER関数は個別レビュー、固定search_path、明示的EXECUTE権限、匿名・他ユーザーによる拒否テストを必須とする。
- 新規テーブルの自動公開を前提にせず、必要なGRANTを明示する。
- Storageは承認済みアセットのみを移行し、バケット公開範囲とオブジェクトパス単位のポリシーを確認する。

## ソース側の安全策

`supabase/config.toml` で新規テーブルの自動公開を無効化し、存在しない `supabase/seed.sql` を参照していたseed処理を無効化した。道の駅レジストリ取込Functionの固定キーはソースから除去し、環境変数参照へ変更した。旧キーがGit履歴やデプロイ済みFunctionに残っている可能性があるため、旧キーの失効・ローテーションは別途必須。レジストリ取込は現在も削除後に再投入する非原子的処理が残るため、本番へデプロイしない。

読み取り専用の `supabase/security/production_rls_audit.sql` と、静的ガード `scripts/check_supabase_security_source.py` を追加した。PRではSupabaseセキュリティソースチェックを実行する。


### イベント参加状態の書き込み

クライアントから `user_event_participations` へ直接INSERT/UPDATEせず、`ensure_event_participation(p_event_id)` / `leave_event_participation(p_event_id)` RPCを使う。RPCは `auth.uid()` からユーザーを確定し、イベントの有効性を検証して、`joined_at` / `updated_at` をDB時刻で設定する。クライアントには当該テーブルの直接INSERT/UPDATE/DELETE権限を付与しない。

この変更はGit上にmigrationとFlutter側の呼び出し変更を用意した段階であり、テストDBへmigrationを適用していない。配布ビルドに含める前にmigration適用とRPCの実機検証が必要。


参加状態のテストでは、テストDB上で両RPCを認証済みロールから呼び出し、参加状態の有効化・解除とサーバー時刻設定を確認した後、トランザクションをロールバックした。DBへの永続適用はしていない。
