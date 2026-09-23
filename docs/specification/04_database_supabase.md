# Database / Supabase仕様

## 本番確認値 2026-09-23
主要行数: seichi 44、profiles 74、collection_history 10、events 2、achievements 6、event_achievements 6、places 41、contents 44、event_contents 44、place_visits 5、user_event_preferences 67、user_event_participations 65、user_event_favorites 1、content_blocks 221。storage.objects 45。

## Storage
- `event-card-images`: public。確認時45 objects。イベントカバー1件と上毛かるた系44画像。
- `content-media`: public。確認時0 objects。10MB制限、jpeg/png/webp/gif。

許諾前・権利確認中の画像はバックアップを私的に保持し、公開リポジトリへ複製しない。

## Edge Function
`delete-account` version 4、ACTIVE、`verify_jwt=false`。これは設定値だけで安全性を断定しない。関数内部の独自認証処理を含めて評価する。

## Migration
本番の最終確認済みmigrationは `20260923004815_harden_trigger_function_search_paths`。

### Drift
Git側には `20260919195000_restrict_internal_security_definer_functions.sql` が存在する一方、本番migration履歴には同名versionが確認できない。適用済みと仮定せず、差異として管理する。

## RLS
主要アプリテーブルはRLS有効。PostGIS由来の `public.spatial_ref_sys` はRLS無効として確認されている。安易にRLSを有効化するとPostGIS利用へ影響し得るため、バックアップとは分離して検証する。

## 変更原則
DDLはmigrationとして管理し、適用後は本番migration履歴・RLS・RPC・アプリ互換を確認する。productionへ手作業で先行変更した場合は必ずGitへ回収する。
