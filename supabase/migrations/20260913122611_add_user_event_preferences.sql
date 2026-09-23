-- ============================================================
-- ユーザーごとの現在選択中クエスト
-- ============================================================

create table if not exists public.user_event_preferences (
  user_id uuid primary key
    references auth.users(id)
    on delete cascade,

  current_event_id uuid not null
    references public.events(id)
    on delete cascade,

  updated_at timestamptz not null default now()
);

alter table public.user_event_preferences
  enable row level security;

-- ============================================================
-- RLS
-- 本人の設定だけ読み書き可能
-- ============================================================

create policy "user_event_preferences_select_own"
on public.user_event_preferences
for select
to authenticated
using (
  auth.uid() = user_id
);

create policy "user_event_preferences_insert_own"
on public.user_event_preferences
for insert
to authenticated
with check (
  auth.uid() = user_id
);

create policy "user_event_preferences_update_own"
on public.user_event_preferences
for update
to authenticated
using (
  auth.uid() = user_id
)
with check (
  auth.uid() = user_id
);

create policy "user_event_preferences_delete_own"
on public.user_event_preferences
for delete
to authenticated
using (
  auth.uid() = user_id
);

grant select, insert, update, delete
on public.user_event_preferences
to authenticated;

comment on table public.user_event_preferences is
  'ユーザーごとの現在選択中クエストを保存する。';