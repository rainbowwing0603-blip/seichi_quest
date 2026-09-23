# 聖地クエスト 仕様書インデックス

基準日: 2026-09-23  
基準コード: main `30346f19e942da6b57f0f51b08aa2437e8f5f967`  
リリース基準: `v1.0.0+8` は `e596314a5afff26c124c1a5317a000da56ad6a0f` を指す。

このディレクトリは、聖地クエストの実装・運用・復旧をコードから逆引きできる正本として管理する。記述は原則として **実装済み / 一部実装 / 将来構想 / 要確認** を区別する。

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

## 更新ルール

機能変更時はコードだけでなく、該当仕様書と `14_traceability.md` を同じPRで更新する。DB変更は migration、RLS、RPC、Storage、Edge Functionへの影響を記録する。将来案は実装済みと混在させない。秘密情報、DBダンプ、認証ユーザーデータ、署名鍵、API秘密鍵、許諾前画像のバックアップはこの公開可能な文書群へ格納しない。

- [16 お知らせ仕様](16_announcements.md)
- [17 広告配置Policy](17_ad_placement_policy.md)
- [18 お知らせ＋広告改善 実装計画](18_feature_plan_announcements_ads.md)
