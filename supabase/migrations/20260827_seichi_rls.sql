-- 聖地クエスト: seichi テーブルの公開アクセス制御
--
-- seichi はアプリが参照する公開コンテンツだが、
-- INSERT / UPDATE / DELETE をクライアントへ許可してはいけない。
-- 有効な聖地だけを anon / authenticated から SELECT 可能にする。

alter table public.seichi enable row level security;

drop policy if exists "seichi_public_read" on public.seichi;

create policy "seichi_public_read"
on public.seichi
for select
to anon, authenticated
using (is_active = true);
