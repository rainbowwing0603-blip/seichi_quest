-- ============================================================
-- ユーザーごとのイベント参加状態
-- ============================================================

create table if not exists public.user_event_participations (
  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  event_id uuid not null
    references public.events(id)
    on delete cascade,

  joined_at timestamptz not null default now(),

  is_active boolean not null default true,

  left_at timestamptz,

  updated_at timestamptz not null default now(),

  primary key (
    user_id,
    event_id
  )
);

alter table public.user_event_participations
  enable row level security;

-- ============================================================
-- RLS
-- 本人の参加状態だけ読み書き可能
-- ============================================================

create policy "user_event_participations_select_own"
on public.user_event_participations
for select
to authenticated
using (
  auth.uid() = user_id
);

create policy "user_event_participations_insert_own"
on public.user_event_participations
for insert
to authenticated
with check (
  auth.uid() = user_id
);

create policy "user_event_participations_update_own"
on public.user_event_participations
for update
to authenticated
using (
  auth.uid() = user_id
)
with check (
  auth.uid() = user_id
);

create policy "user_event_participations_delete_own"
on public.user_event_participations
for delete
to authenticated
using (
  auth.uid() = user_id
);

grant select, insert, update, delete
on public.user_event_participations
to authenticated;

create index if not exists
  user_event_participations_event_active_idx
on public.user_event_participations (
  event_id,
  is_active
);

comment on table public.user_event_participations is
  'ユーザーごとのイベント参加・離脱状態を保存する。';