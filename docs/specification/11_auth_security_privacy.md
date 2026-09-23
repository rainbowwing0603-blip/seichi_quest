# 認証・セキュリティ・プライバシー

## Auth
Supabase Authを利用する。`SessionService.ensureCloudUser` は既存ユーザーが無ければ `signInAnonymously()` を実行する。したがって本番Authでは匿名サインインが利用可能である必要がある。Gitの `supabase/config.toml` はlocal設定であり、本番dashboard設定の正本とは限らない。

## Account deletion
本番Edge Function `delete-account` version 4は設定上 `verify_jwt=false`。ただし基準コードのFunction内部では `createSupabaseContext(req, { auth: "user" })` によるユーザー認証を要求し、認証済みuserClaims.idのユーザーだけをadmin APIで削除する。認証失敗またはuser id不在時は401系で終了する。

したがって「verify_jwt=false = 無認証削除」ではない。今後Function実装またはSupabase server helperを変更した場合は、この内部認証保証を再レビューする。

## RLS
主要アプリテーブルはRLSを使用する。Security Definer関数やsearch_pathはmigrationで継続的にhardeningしている。

## 位置情報
collection_history/place_visitsには訪問時刻・緯度経度・精度等が保存され得る。公開プロフィール情報より高い慎重さで扱い、バックアップを公開場所へ置かない。

## 秘密情報
Gitへ入れないもの: Android upload keystore、key.propertiesのpassword類、service_role/secret key、DB password、OAuth provider secret、本番ユーザーデータdump。Supabase publishable keyはクライアント利用前提だが、権限制御はRLS/RPC側で成立させる。

## Privacy
公開プライバシーポリシーは `docs/privacy/index.html` 等で管理する。収集データ、第三者SDK、アカウント削除、位置情報の扱いを変更した場合はポリシーも同じ変更単位でレビューする。
