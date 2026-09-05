-- 聖地クエスト
-- イベント単位で聖地・獲得履歴を管理するための基盤。
--
-- 現在の「上毛かるた×群馬」を最初のイベントとして登録する。
-- 既存のcollection_historyは削除せず、すべて群馬イベントへ移行する。

-- ============================================================
-- 1. イベント
-- ============================================================

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.events is
  '聖地クエストのイベント定義。上毛かるた×群馬、将来の埼玉などをイベント単位で管理する。';

-- ============================================================
-- 2. 現在のイベント「上毛かるた×群馬」
-- ============================================================

insert into public.events (
  slug,
  name,
  description
)
values (
  'jomo-karuta-gunma',
  '上毛かるた×群馬',
  '上毛かるた44札の聖地巡礼'
)
on conflict (slug) do nothing;

-- ============================================================
-- 3. seichi に event_id を追加
-- ============================================================

alter table public.seichi
  add column if not exists event_id uuid;

-- 現在登録されている聖地はすべて
-- 「上毛かるた×群馬」イベントに所属させる。
update public.seichi
set event_id = (
  select id
  from public.events
  where slug = 'jomo-karuta-gunma'
)
where event_id is null;

-- 既存データ移行後は必須項目にする。
alter table public.seichi
  alter column event_id set not null;

-- eventsへの参照整合性。
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'seichi_event_id_fkey'
      and conrelid = 'public.seichi'::regclass
  ) then
    alter table public.seichi
      add constraint seichi_event_id_fkey
      foreign key (event_id)
      references public.events(id)
      on delete restrict;
  end if;
end
$$;

create index if not exists seichi_event_id_idx
  on public.seichi(event_id);

-- ============================================================
-- 4. collection_history に event_id を追加
-- ============================================================

alter table public.collection_history
  add column if not exists event_id uuid;

-- 既存履歴は、そのseichiが所属するイベントから移行する。
update public.collection_history ch
set event_id = s.event_id
from public.seichi s
where ch.seichi_id = s.id
  and ch.event_id is null;

-- 既存データが正しく移行できていることを確認する。
do $$
begin
  if exists (
    select 1
    from public.collection_history
    where event_id is null
  ) then
    raise exception
      'collection_history.event_id の移行に失敗しました。NULLの履歴が残っています。';
  end if;
end
$$;

alter table public.collection_history
  alter column event_id set not null;

-- eventsへの参照整合性。
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'collection_history_event_id_fkey'
      and conrelid = 'public.collection_history'::regclass
  ) then
    alter table public.collection_history
      add constraint collection_history_event_id_fkey
      foreign key (event_id)
      references public.events(id)
      on delete restrict;
  end if;
end
$$;

create index if not exists collection_history_user_event_idx
  on public.collection_history(user_id, event_id);

create index if not exists collection_history_event_collected_at_idx
  on public.collection_history(event_id, collected_at desc);

-- ============================================================
-- 5. スタンプの一意性をイベント単位へ変更
-- ============================================================

-- 現在は user_id + seichi_id で一意。
-- 将来、同じseichi_idが別イベントに存在しても
-- 別イベントとして扱えるようにする。

alter table public.collection_history
  drop constraint if exists collection_history_user_id_seichi_id_key;

alter table public.collection_history
  add constraint collection_history_user_event_seichi_unique
  unique (user_id, event_id, seichi_id);

-- ============================================================
-- 6. events のRLS
-- ============================================================

alter table public.events enable row level security;

drop policy if exists "events_select_active"
  on public.events;

create policy "events_select_active"
on public.events
for select
to authenticated
using (is_active = true);

-- ============================================================
-- 7. seichi のイベントコメント
-- ============================================================

comment on column public.seichi.event_id is
  'この聖地が所属するイベント。';

comment on column public.collection_history.event_id is
  'このスタンプ獲得が所属するイベント。';