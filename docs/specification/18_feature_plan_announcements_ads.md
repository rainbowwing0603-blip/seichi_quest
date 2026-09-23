# お知らせ＋広告改善 実装計画

## Phase 1 お知らせ基盤
1. announcements / announcement_reads migration
2. RLS・index・updated_at
3. Announcement model / service
4. 未読取得・既読化テスト
5. 起動時モーダル
6. MyPage入口・未読バッジ・一覧/詳細
7. event_id導線

## Phase 2 広告Policy
1. AdPlacementPolicyを純粋ロジックとして追加
2. 起動・お知らせ・スタンプ・画面滞在の保護条件をテスト
3. スクロール画面用インライン広告Widget
4. まず1〜2配置で実測
5. 問題がなければランキング/イベント探索等へ段階展開

## Phase 3 運用
管理画面からお知らせ作成・予約公開・停止を可能にする。イベントend_at連動の終了間近通知は、手動運用が安定した後に自動化する。

## リリース判定
flutter analyze / flutter test、匿名ユーザーでのRLS、複数未読、期限切れ、イベントなし一般通知、広告ロード失敗、広告禁止ゾーン、オフライン時の表示を確認する。
