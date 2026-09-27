# 既知差異・未決事項・判断記録

## 1. Production migration drift
**要対応** 2026-09-27の本番migration履歴は `20260926225451_add_app_release_policy` まで進んでいるが、確認したGitツリーは `20260926122330_use_server_time_for_collection` まで。少なくとも `harden_public_postgis_api_surface` と `add_app_release_policy` をGitへ回収し、実体一致を確認する。

## 2. spatial_ref_sys / PostGIS
**要確認** `public.spatial_ref_sys` はRLS無効でSecurity Advisor ERROR。PostGIS extensionもpublic schema配置として警告される。PostGIS互換を壊す可能性があるため、自動でRLS有効化やextension移動をしない。公開権限とAPI露出を検証して判断する。

## 3. Security Advisor
**要確認** policy無しRLSテーブル、意図確認が必要なSECURITY DEFINER RPC実行権限、匿名サインインに伴うRLS警告、Leaked Password Protection無効が報告されている。匿名利用をアプリ要件としているため、警告を一括排除せず「意図した公開」と「不要な権限」を分ける。

## 4. Edge Functions drift
**要対応** 本番には5 Functionsがあり、delete-accountはversion 5。仕様書の旧version 4記述を更新した。各Functionの本番ソースとGit側ソースの一致は別途確認する。verify_jwt=falseのFunctionは内部認証/運用専用経路をレビューする。

## 5. 旧seichi
**解消済み** 旧 `seichi` テーブルは2026-09-25 migrationで廃止済み。event_contentベースの汎用収集モデルを正本とする。

## 6. 上毛かるた画像
**運用要確認** Storageやmedia_pathが存在しても、それだけで利用許諾済みとは扱わない。許諾前は公開可否を権利確認に従う。TEST IMAGE等のフォールバック表示についてはアプリ側media/fallback経路の最終確認が必要。

## 7. Release / Play
**要確認** ソースは `1.0.0+12`。Supabase release policyはAndroid build 11をlatest/minimumとしている。Play Consoleの実配布buildはPlay Consoleで照合し、+12提出前にversionCodeとAABを固定する。

## 8. main統合
**要対応** 2026-09-27確認時、`fix/destination-range-and-float` はmainより24 commits ahead / 0 behind、open PRは0。品質ゲートとdrift回収後にPR→mainとする。

## 9. iOS
**将来構想/一部雛形** iOSディレクトリとSign in with Apple依存は存在するが、Androidと同等の本番リリース完了を意味しない。

## 10. 復旧テスト
**未実施** 別Supabase環境への完全restore rehearsalは未実施。バックアップの存在と復元可能性は別事実として扱う。

## 11. しるべ / ストーリー
**次期構想** キャラクター「しるべ」と長期ストーリーシステムは、現行ベースライン固定後に設計・実装する。現在のコードへ先行混入させない。

## 12. 文書の位置づけ
この仕様書は2026-09-27時点のGitHub `3e4b1a8` と本番Supabase確認結果を基準とする。未確認事項を推測で「実装済み」に昇格させない。
