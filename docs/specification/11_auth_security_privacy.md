# 認証・セキュリティ・プライバシー

## Auth
Supabase Authを利用。アプリはSessionService等でクラウドユーザーを確保する。プロフィールはauth.usersとUUIDで対応する。

## Account deletion
本番Edge Function `delete-account` version 4が存在し、設定上 `verify_jwt=false`。この値だけでは認証なし削除可能とは断定しない。関数内部でJWT/ユーザーを検証しているかをレビュー対象とする。

## RLS
主要アプリテーブルはRLSを使用する。Security Definer関数やsearch_pathはmigrationで継続的にhardeningしている。

## 位置情報
位置情報はスタンプ成立の中核データ。collection_history/place_visitsには緯度経度等が保存され得るため、公開プロフィール情報と同列に扱わない。

## 秘密情報
以下はGitへ入れない。
- Android upload keystore
- key.properties内のpassword類
- service_role / secret key
- DB password
- OAuth provider secret
- 本番ユーザーデータのdump

Supabase publishable keyはクライアント利用前提だが、権限制御はRLS/RPC側で成立させる。

## Privacy
公開プライバシーポリシーは `docs/privacy/index.html` 等で管理される。実際に収集・保存するデータ項目が変わった場合、コード/DBだけでなくポリシー記述も同時に見直す。
