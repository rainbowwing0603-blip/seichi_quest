# 既知差異・未決事項・判断記録

## 1. Migration drift
**要確認** Gitに `20260919195000_restrict_internal_security_definer_functions.sql` があるが、本番migration履歴では確認できない。自動適用しない。内容・後続migrationとの重複を調べてから判断する。

## 2. spatial_ref_sys
**要確認** `public.spatial_ref_sys` はRLS無効。PostGIS由来テーブルなので、一般テーブルと同じ感覚でRLSを有効化しない。実害・公開権限・PostGIS互換を検証する。

## 3. delete-account
**要確認** 本番Functionは `verify_jwt=false`。内部認証をレビューし、意図した設定か確定する。

## 4. Auth local configと本番
**要確認** Gitの `supabase/config.toml` はlocal development設定であり、本番dashboard設定の完全な写しではない。例としてlocal configではanonymous sign-in=falseだが、本番運用値をこれだけから断定しない。

## 5. 旧seichiと汎用モデル
**一部実装** 旧44札モデルとplaces/contents/event_contentsが併存。新規機能は汎用モデル優先とし、旧モデルを消す場合は全参照とデータ移行を完了してから行う。

## 6. 上毛かるた画像
**運用要確認** Storageに関連画像が存在しても、それだけで利用許諾済みとは扱わない。許諾状況を公開可否の判断源とする。

## 7. iOS
**将来構想/一部雛形** iOSディレクトリとSign in with Apple依存は存在するが、Androidと同等の本番リリース完了を意味しない。

## 8. 復旧テスト
**未実施** バックアップのhash整合性確認は済んでいるが、別Supabase環境への完全restore rehearsalは未実施。

## 9. 文書の位置づけ
この仕様書は2026-09-23時点のコード・本番Supabase確認結果を基準とする。未確認事項を推測で「実装済み」に昇格させない。
