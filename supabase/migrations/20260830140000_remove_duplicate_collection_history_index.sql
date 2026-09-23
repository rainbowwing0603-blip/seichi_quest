-- 聖地クエスト
-- collection_history の重複ユニークインデックスを削除する。
--
-- collection_history_user_id_seichi_id_key は
-- UNIQUE (user_id, seichi_id) 制約によって必要な一意性を保証している。
-- collection_history_user_seichi_unique は同じ列組み合わせを重複して
-- UNIQUE INDEX として保持しているため不要。

drop index if exists public.collection_history_user_seichi_unique;