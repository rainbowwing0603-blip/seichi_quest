-- ============================================================
-- ユーザーごとのイベントお気に入り
-- ============================================================

create table if not exists public.user_event_favorites (
  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  event_id uuid not null
    references public.events(id)
    on delete cascade,

  created_at timestamptz not null default now(),

  primary key (
    user_id,
    event_id
  )
);

alter table public.user_event_favorites
  enable row level security;

-- ============================================================
-- RLS
-- 本人のお気に入りだけ読み書き可能
-- ============================================================

create policy "user_event_favorites_select_own"
on public.user_event_favorites
for select
to authenticated
using (
  auth.uid() = user_id
);

create policy "user_event_favorites_insert_own"
on public.user_event_favorites
for insert
to authenticated
with check (
  auth.uid() = user_id
);

create policy "user_event_favorites_delete_own"
on public.user_event_favorites
for delete
to authenticated
using (
  auth.uid() = user_id
);

grant select, insert, delete
on public.user_event_favorites
to authenticated;

create index if not exists
  user_event_favorites_event_idx
on public.user_event_favorites (
  event_id
);

comment on table public.user_event_favorites is
  'ユーザーごとのイベントお気に入りを保存する。';