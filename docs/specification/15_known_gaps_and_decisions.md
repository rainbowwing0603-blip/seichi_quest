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
**運用要確認** Storageやmedia_pathが存在しても、それだけで利用許諾済みとは扱わない。許諾前は公開可否を権利確認に従う。

## 7. Release / Play
**更新済み / 継続確認** Version 16はPlay Alphaへ配信済み。Version 16ではRelease buildへRewarded story ad unit IDが注入されず、Rewarded Story Previewボタンが非表示になることを確認した。Version 17ではGitHub Actionsのbuild処理を修正し、Rewarded IDの空値をbuild時に検出する。Version 17のPlay配信と実機検証は未完了。

## 8. main統合
**解消済み** PR #21はmainへ統合済み。Rewarded Story Previewと広告表示タイミング改善をmainへ反映した。現在のmainはVersion 17準備状態。

## 9. iOS
**将来構想/一部雛形** iOSディレクトリとSign in with Apple依存は存在するが、Androidと同等の本番リリース完了を意味しない。Codemagic unsigned checkは通過済み。

## 10. 復旧テスト
**未実施** 別Supabase環境への完全restore rehearsalは未実施。バックアップの存在と復元可能性は別事実として扱う。

## 11. しるべ / ストーリー
**一部実装** 長期ストーリーシステム全体は将来構想だが、現行では既存ContentBlockのstory/history/field_guide等を対象とした1時間Rewarded Previewを実装済み。キャラクター「しるべ」や長期ストーリー状態機械は未実装。

## 12. 文書の位置づけ
2026-09-27の `19_current_baseline_20260927.md` は履歴資料として保持する。現在の正本は `20_current_baseline_20261008.md` とし、未確認事項を推測で「実装済み」に昇格させない。

## 2026-10-08 release / rewarded-ad audit
- Version 16でRewarded Story Previewボタンが表示されなかった原因は、GitHub Actions build logの `STORY_REWARDED_AD_UNIT_ID` が空だったこと。
- Version 17のworkflowでは `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID` をGitHub variable/secretから取得し、未設定時は既知のAndroid Rewarded unitへフォールバックし、最終的に空ならbuildを失敗させる。
- Version 17のソース側では `StoryRewardedAdService.available` がReleaseのRewarded ID有無をUI表示条件としているため、ID無しReleaseではボタン非表示が仕様どおり。
- 次の確認はVersion 17 AAB build成功、Play Alpha配信、対象未獲得spotでのボタン表示、Rewarded Ad表示、報酬コールバック、1時間期限の実機確認。
