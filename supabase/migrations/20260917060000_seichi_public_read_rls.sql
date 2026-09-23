-- 聖地クエスト: seichi テーブルの公開読み取り制御
--
-- seichi はアプリから参照するコンテンツ。
-- RLS により、有効な聖地だけをクライアントから SELECT 可能にする。
--
-- INSERT / UPDATE / DELETE のクライアント権限は追加しない。
--
-- 現行アプリは起動時に匿名サインインを行うため、
-- 通常のアプリ利用者は authenticated ロールでアクセスする。
--
-- anon にも SELECT policy を設定しておくことで、
-- 認証前に公開コンテンツを取得する処理を将来追加した場合にも、
-- is_active = true の行だけを公開する。

alter table public.seichi
enable row level security;

drop policy if exists "Allow anonymous read seichi"
on public.seichi;

drop policy if exists "Allow authenticated read seichi"
on public.seichi;

drop policy if exists "seichi_public_read"
on public.seichi;

create policy "seichi_public_read"
on public.seichi
for select
to anon, authenticated
using (is_active = true);
