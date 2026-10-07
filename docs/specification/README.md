# 聖地クエスト 仕様書インデックス

基準日: 2026-10-08  
基準コード: `8d1badbd75a489b8b03d478270f85f3dd21dbccb`  
アプリ版: `1.0.0+17`  
配布状態: Version 17はリリース準備済み。Google Playへの実配布完了は未確認で、Play Consoleを正本として確認する。

このディレクトリは、聖地クエストの実装・運用・復旧をコードと本番Supabaseから逆引きできる正本として管理する。記述は原則として **実装済み / 一部実装 / 将来構想 / 要確認** を区別する。

## 現行ベースライン
- Flutter/Dart 3.47.1 / 3.13.1、Android中心。applicationIdは `jp.seichiquest.app`。
- Event / Content / Place / EventContent / ContentBlock を中心とする汎用イベント基盤。
- 旧 `seichi` テーブルは2026-09-25のmigrationで廃止済み。獲得履歴はevent_contentを正規IDとする。
- 地図はズームに応じて spot / cluster / regional progress を切替。
- NEXT、獲得範囲、ソナー、heading-up、天候・季節・時間帯、太陽方位に連動する視覚効果を持つ。
- 位置不正対策は端末側mock判定とサーバー側状態/cooldown、サーバー時刻を組み合わせる。
- お知らせ、広告配置Policy、アプリ更新Policyを共通基盤として持つ。
- Rewarded Adによる物語1時間プレビューを実装。Release Android buildではRewarded ad unit IDをビルド時に注入する。
- 2026-10-08時点のmain HEADは `8d1badbd75a489b8b03d478270f85f3dd21dbccb`、versionCodeは17。

## 文書一覧
1. [01_product_overview.md](01_product_overview.md) プロダクト概要
2. [02_architecture.md](02_architecture.md) システム構成
3. [03_domain_model.md](03_domain_model.md) ドメインモデル
4. [04_database_supabase.md](04_database_supabase.md) DB / Supabase
5. [05_gps_collection.md](05_gps_collection.md) GPS・獲得判定
6. [06_sync_offline.md](06_sync_offline.md) 同期・オフライン
7. [07_ui_navigation.md](07_ui_navigation.md) UI・画面遷移
8. [08_content_platform.md](08_content_platform.md) 汎用コンテンツ基盤
9. [09_progression_ranking.md](09_progression_ranking.md) 実績・ランキング
10. [10_ads_notifications.md](10_ads_notifications.md) 広告・通知
11. [11_auth_security_privacy.md](11_auth_security_privacy.md) 認証・セキュリティ・プライバシー
12. [12_release_operations.md](12_release_operations.md) リリース・運用
13. [13_disaster_recovery.md](13_disaster_recovery.md) バックアップ・復旧
14. [14_traceability.md](14_traceability.md) 仕様↔コード対応表
15. [15_known_gaps_and_decisions.md](15_known_gaps_and_decisions.md) 差異・未決事項・判断記録
16. [16_announcements.md](16_announcements.md) お知らせ
17. [17_ad_placement_policy.md](17_ad_placement_policy.md) 広告配置Policy
18. [18_feature_plan_announcements_ads.md](18_feature_plan_announcements_ads.md) お知らせ・広告改善計画
19. [19_current_baseline_20260927.md](19_current_baseline_20260927.md) 2026-09-27時点の履歴ベースライン
20. [20_current_baseline_20261008.md](20_current_baseline_20261008.md) 現行ベースライン

補助資料:
- [../story_rewarded_ads.md](../story_rewarded_ads.md) Rewarded Ad物語プレビュー仕様

## 更新ルール
機能変更時はコードだけでなく、該当仕様書と `14_traceability.md` を同じPRで更新する。DB変更はmigration、RLS、RPC、Storage、Edge Functionへの影響を記録する。将来案は実装済みと混在させない。秘密情報、DBダンプ、認証ユーザーデータ、署名鍵、API秘密鍵、許諾前画像のバックアップはこの公開可能な文書群へ格納しない。
