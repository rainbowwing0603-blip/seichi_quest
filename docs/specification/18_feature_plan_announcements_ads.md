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
2. Release初期値を起動後3分、Interstitial間15分、スタンプ後2分、対象画面10秒に再構成
3. セッション最大回数は設けず、自然な区切りを必須条件にする
4. Banner/Inline/Interstitialを独立した3層として管理
5. 既存Bannerを邪魔にならない画面で維持し、Adaptive Bannerを将来候補とする
6. スクロール画面用Inline広告Widgetを追加
7. まず少数配置で実測し、問題がなければランキング/イベント探索等へ段階展開

## Phase 3 運用
管理画面からお知らせ作成・予約公開・停止を可能にする。イベントend_at連動の終了間近通知は、手動運用が安定した後に自動化する。

## リリース判定
flutter analyze / flutter test、匿名ユーザーでのRLS、複数未読、期限切れ、イベントなし一般通知、広告ロード失敗、広告禁止ゾーン、オフライン時の表示を確認する。

広告については短時間/長時間セッションの両方を検証し、Interstitialが出なさすぎる状態と、自然な区切りを越えて過剰表示される状態の双方を確認する。
