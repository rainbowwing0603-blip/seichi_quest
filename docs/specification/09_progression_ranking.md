# 実績・ランキング

## Achievement
`achievements` は実績定義、`event_achievements` がイベントとの対応と表示順を持つ。Flutterの `ProgressionService.loadEventAchievements` は event_achievements から achievements をjoinして読み込む。

基準コード内の代表定義は first_step=1、gunma_beginner=5、collector=10、gunma_explorer=20、gunma_master=30、gunma_conqueror=44。解除状態を別保存する旧方式ではなく、獲得数から進捗を判定する考え方を持つ。

## Level
`ProgressionService.loadLevelProgress` は全獲得数を読み、LevelServiceでXPとレベル進捗へ変換する。

## Ranking
`RankingPage` は `get_public_ranking(p_event_id, p_limit=50)` RPCを利用する。`ProgressionService.loadMyEventRank` は `get_my_event_rank(p_event_id)` を利用する。

UI上、表示名を設定し、対象イベントで聖地を1つ以上獲得したユーザーをランキング参加者として扱う。最大50件を画面取得する現行実装である。

## 原則
ランキング値は端末の自己申告だけを正本にしない。サーバー側獲得履歴を基礎に集計する。参加条件や同順位規則等を変更する場合はRPCとUI説明を同時に更新する。

## 将来
期間ランキングや複数スコア軸を追加する場合も、既存collection_historyを破壊せず派生集計として設計する。
