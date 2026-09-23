-- 聖地クエスト: 獲得履歴
--
-- 端末側のSharedPreferencesを一次保存先として使い、通信復旧後にこのテーブルへ同期する。
-- user_id は Supabase Auth のユーザーIDに限定する。

create table if not exists public.collection_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  seichi_id uuid not null references public.seichi(id) on delete cascade,
  collected_at timestamptz not null default now(),
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create unique index if not exists collection_history_user_seichi_unique
  on public.collection_history(user_id, seichi_id);

create index if not exists collection_history_user_collected_at_idx
  on public.collection_history(user_id, collected_at desc);

alter table public.collection_history enable row level security;

-- 自分の履歴だけ参照可能
create policy "collection_history_select_own"
on public.collection_history
for select
to authenticated
using ((select auth.uid()) = user_id);

-- 自分の履歴だけ追加可能
create policy "collection_history_insert_own"
on public.collection_history
for insert
to authenticated
with check ((select auth.uid()) = user_id);

-- アプリから履歴を変更・削除する機能は現時点では持たせない。
-- duplicate は unique index + upsert で安全に無視する。

comment on table public.collection_history is
  '聖地クエストのユーザー別スタンプ獲得履歴。端末オフライン時はアプリ側で保留し、通信復旧時に同期する。';
