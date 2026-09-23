-- 聖地クエスト: 獲得履歴
-- オフライン獲得後の同期先となるSupabaseテーブル

create table if not exists public.collection_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  seichi_id text not null,
  collected_at timestamptz not null default now(),
  synced_at timestamptz,
  unique (user_id, seichi_id)
);

alter table public.collection_history enable row level security;

create policy "Users can read own collection history"
on public.collection_history
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own collection history"
on public.collection_history
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own collection history"
on public.collection_history
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create index if not exists collection_history_user_id_idx
  on public.collection_history(user_id);

create index if not exists collection_history_collected_at_idx
  on public.collection_history(collected_at desc);
