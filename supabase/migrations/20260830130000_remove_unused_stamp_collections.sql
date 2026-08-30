-- 聖地クエスト
-- 現行Flutter実装から参照されていない旧スタンプテーブルを廃止する。
--
-- 確認済み:
-- ・Flutterコードから stamp_collections の参照なし
-- ・Git履歴に stamp_collections の作成/利用履歴なし
-- ・Remote stamp_collections のデータ件数 0
-- ・現行の獲得履歴は collection_history を使用
--
-- profiles / seichi / collection_history は削除しない。

drop table if exists public.stamp_collections;