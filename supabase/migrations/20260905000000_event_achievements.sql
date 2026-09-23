-- 聖地クエスト
-- イベントごとのチャレンジを管理するための基盤。

create table if not exists public.achievements (
  id text primary key,
  title text not null,
  description text not null,
  icon text not null,
  required_count integer not null check (required_count >= 0)
);

comment on table public.achievements is
  '聖地クエストのチャレンジ定義。イベントをまたいで再利用できる。';

insert into public.achievements (
  id,
  title,
  description,
  icon,
  required_count
)
values
  ('first_step', 'はじめの一歩', '最初の聖地を獲得する', '🌱', 1),
  ('gunma_beginner', '群馬ビギナー', '5個の聖地を獲得する', '🗺️', 5),
  ('collector', 'コレクター', '10個の聖地を獲得する', '🎒', 10),
  ('gunma_explorer', '群馬探訪者', '20個の聖地を獲得する', '🚗', 20),
  ('gunma_master', '群馬マスター', '30個の聖地を獲得する', '🏔️', 30),
  ('gunma_conqueror', '群馬制覇', '44個すべての聖地を獲得する', '👑', 44)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  icon = excluded.icon,
  required_count = excluded.required_count;

create table if not exists public.event_achievements (
  event_id uuid not null,
  achievement_id text not null,
  sort_order integer not null default 0,
  primary key (event_id, achievement_id),
  foreign key (event_id)
    references public.events(id)
    on delete restrict,
  foreign key (achievement_id)
    references public.achievements(id)
    on delete restrict
);

comment on table public.event_achievements is
  'イベントごとに利用するチャレンジと表示順。';

create index if not exists event_achievements_event_sort_idx
  on public.event_achievements(event_id, sort_order);

insert into public.event_achievements (
  event_id,
  achievement_id,
  sort_order
)
select
  e.id,
  a.id,
  case a.id
    when 'first_step' then 1
    when 'gunma_beginner' then 2
    when 'collector' then 3
    when 'gunma_explorer' then 4
    when 'gunma_master' then 5
    when 'gunma_conqueror' then 6
  end
from public.events e
cross join public.achievements a
where e.slug = 'jomo-karuta-gunma'
  and a.id in (
    'first_step',
    'gunma_beginner',
    'collector',
    'gunma_explorer',
    'gunma_master',
    'gunma_conqueror'
  )
on conflict (event_id, achievement_id) do update set
  sort_order = excluded.sort_order;

alter table public.achievements enable row level security;
alter table public.event_achievements enable row level security;

drop policy if exists "achievements_select_authenticated"
  on public.achievements;

create policy "achievements_select_authenticated"
on public.achievements
for select
to authenticated
using (true);

drop policy if exists "event_achievements_select_authenticated"
  on public.event_achievements;

create policy "event_achievements_select_authenticated"
on public.event_achievements
for select
to authenticated
using (true);

grant select on public.achievements to authenticated;
grant select on public.event_achievements to authenticated;