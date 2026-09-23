# バックアップ・災害復旧

## 2026-09-23 Supabaseバックアップ
ローカルバックアップとしてroles/schema/data dump、Storage実体45ファイル、functionsローカルソース、config、SHA-256 manifest、RESTORE.mdを作成済み。作成時manifestは53 entries、検証failure 0。

## 重要な限界
- Edge Functionの「本番デプロイ実体」とローカルコピーの完全同一性は独立検証未完了。
- Supabase dashboard上の秘密値、OAuth secrets等はDB dumpに含まれない。
- 実際の別Supabase projectへのフルrestore rehearsalは未実施。
- Git migrationと本番migration履歴にdriftがある。
したがって「全環境を完全自動で同一復元できる」とはまだ扱わない。

## 復旧順序
1. Gitの既知タグ/commitからアプリ・migration・functionソースを確保
2. 新規/検証用Supabaseへschema/roles/dataを復元
3. Storage bucket設定を確認し、object実体を復元
4. Edge Functionを確認してdeploy
5. Auth/provider/secret等のdashboard設定を安全な記録から再設定
6. RLS/RPC、ユーザー数、主要テーブル件数、Storage件数を照合
7. 検証用アプリからログイン、イベント取得、GPS獲得、同期をE2E確認
8. 本番切替

## オフサイト
Cドライブだけでは物理故障に弱い。別物理ディスクFドライブ等へ暗号化した第二コピーを持つ。Gitは `git bundle --all` で履歴・タグをオフライン保存可能。

## 署名鍵
Android upload keystoreはコード以上に重要。秘密鍵そのものとpasswordは分離して安全に保管し、チャットやGitへ貼らない。
