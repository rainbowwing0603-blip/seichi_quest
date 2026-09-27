# 既知差異・未決事項・判断記録

## 1. Production migration drift
**回収済み / 継続確認** 本番migration履歴の末尾2件 `20260926225137_harden_public_postgis_api_surface` と `20260926225451_add_app_release_policy` は2026-09-27にGitへ回収した。app_release_policiesは本番テーブル形状も照合済み。PostGIS側は本番migrationの完全SQL本文を直接取得できないため、Git回収版は権限hardeningの再現用として保持し、fresh環境での適用検証を残す。

## 2. spatial_ref_sys / PostGIS
**要確認** `public.spatial_ref_sys` はRLS無効でSecurity Advisor ERROR。PostGIS extensionもpublic schema配置として警告される。PostGIS互換を壊す可能性があるため、自動でRLS有効化やextension移動をしない。公開権限とAPI露出を検証して判断する。

## 3. Security Advisor
**要確認** policy無しRLSテーブル、意図確認が必要なSECURITY DEFINER RPC実行権限、匿名サインインに伴うRLS警告、Leaked Password Protection無効が報告されている。匿名利用をアプリ要件としているため、警告を一括排除せず「意図した公開」と「不要な権限」を分ける。

## 4. Edge Functions drift
**一部回収済み / 継続確認** 本番5 Functionsを取得し、delete-account version 5はGitと本文一致を確認した。import-roadside-station-registryとverify-roadside-station-gsiはGitへ回収済み。残るGPS enrichment/reconcile Functionsは安全チェックにより自動書込みが途中停止したため未回収。reconcile-roadside-station-gpsはverify_jwt=falseだが固定運用キーを要求する実装。本番ソースには固定キー文字列が含まれるため、Gitへそのまま公開せずSecret化してから回収する。

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


## 2026-09-27 security / media audit follow-up

- Supabase Security Advisor was re-run after backend reconciliation.
- RLS-enabled/no-policy findings for private.admin_users, event_collection_resets, location_security_events, location_security_states, and roadside_station_registry are treated as deny-by-default internal tables unless a future client use case explicitly requires a policy.
- Anonymous-access warnings are expected where the product intentionally supports anonymous Auth sessions; do not remove these mechanically.
- PostGIS findings for spatial_ref_sys / st_estimatedextent are extension-surface findings. Keep explicit privilege hardening and avoid ad-hoc RLS changes to extension-owned objects.
- SECURITY DEFINER RPC exposure must remain allowlisted by product use case. Public ranking is intentionally public; user-owned history, rank, reset, integrity, and collection RPCs require authenticated callers.
- Production roadside-station maintenance Functions contain embedded maintenance keys. Do not copy those keys into Git. Move maintenance authentication to Supabase-managed secrets or named secret-key auth before source parity is considered complete.
- Source audit found no literal TEST IMAGE / test image / placeholder-image marker in the Flutter repository.
- content_blocks currently has 44 picture_card blocks and no test-like strings in title/body/media_path. Their media_path values point at the public event-card-images/jomo-karuta objects. Therefore any visible TEST IMAGE artwork is in the stored object bytes themselves, not a Flutter placeholder string or content_blocks label.
- Do not replace the 44 stored card assets with official/copyrighted artwork until usage permission is confirmed.
