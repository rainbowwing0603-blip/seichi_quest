-- 聖地クエスト
-- collection_history の重複RLSポリシーを整理する

drop policy if exists "Users can read own collection history"
  on public.collection_history;

drop policy if exists "Users can insert own collection history"
  on public.collection_history;

drop policy if exists "Users can update own collection history"
  on public.collection_history;
