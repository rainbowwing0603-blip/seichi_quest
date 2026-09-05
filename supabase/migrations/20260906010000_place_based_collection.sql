-- 聖地クエスト
-- 物理地点を正規化し、1回の訪問で同一地点の複数札・複数イベントを
-- 訪問時点の開催期間に基づいて獲得できるようにする。

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now()
);

comment on table public.places is
  '物理的な訪問先。複数イベント・複数の上毛かるた札から共有される。';

comment on column public.places.name is
  '物理地点の正式名称。';

comment on column public.places.latitude is
  '物理地点の代表緯度。';

comment on column public.places.longitude is
  '物理地点の代表経度。';

create unique index if not exists places_latitude_longitude_unique
  on public.places (latitude, longitude);

-- 既存データから物理地点を作成する。
insert into public.places (name, latitude, longitude)
select distinct on (s.latitude, s.longitude)
  s.name,
  s.latitude,
  s.longitude
from public.seichi s
where s.latitude <> 0
  and s.longitude <> 0
order by s.latitude, s.longitude, s.created_at nulls last, s.id;

alter table public.seichi
  add column if not exists place_id uuid;

update public.seichi s
set place_id = p.id
from public.places p
where s.place_id is null
  and s.latitude = p.latitude
  and s.longitude = p.longitude;

-- 既存の有効な聖地は上記バックフィルで全て地点に紐づくことを前提とする。
alter table public.seichi
  alter column place_id set not null;

alter table public.seichi
  drop constraint if exists seichi_place_id_fkey;

alter table public.seichi
  add constraint seichi_place_id_fkey
  foreign key (place_id) references public.places(id);

create index if not exists seichi_place_id_idx
  on public.seichi (place_id);

alter table public.places enable row level security;

revoke all on table public.places from anon, authenticated;
grant select on table public.places to authenticated;

drop policy if exists places_select_authenticated on public.places;

create policy places_select_authenticated
on public.places
for select
to authenticated
using (true);

-- 訪問時点で有効な全イベントの同一地点の札を一括獲得する。
-- start_at / end_at が NULL の場合は、既存仕様どおり期間指定なしとして扱う。
create or replace function public.record_place_visit(
  p_seichi_id uuid,
  p_collected_at timestamptz,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns table (
  event_id uuid,
  seichi_id uuid,
  place_id uuid,
  collected_at timestamptz,
  event_name text,
  card text,
  seichi_name text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_place_id uuid;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'authenticated user is required';
  end if;

  select s.place_id
    into v_place_id
  from public.seichi s
  where s.id = p_seichi_id
    and s.is_active = true;

  if v_place_id is null then
    raise exception 'active seichi was not found';
  end if;

  return query
  with inserted as (
    insert into public.collection_history (
      user_id,
      event_id,
      seichi_id,
      collected_at,
      latitude,
      longitude
    )
    select
      v_user_id,
      s.event_id,
      s.id,
      p_collected_at,
      p_latitude,
      p_longitude
    from public.seichi s
    join public.events e
      on e.id = s.event_id
    where s.place_id = v_place_id
      and s.is_active = true
      and e.is_active = true
      and (e.start_at is null or p_collected_at >= e.start_at)
      and (e.end_at is null or p_collected_at <= e.end_at)
    on conflict (user_id, event_id, seichi_id) do nothing
    returning
      collection_history.event_id,
      collection_history.seichi_id,
      collection_history.collected_at
  )
  select
    i.event_id,
    i.seichi_id,
    v_place_id,
    i.collected_at,
    e.name,
    s.card,
    s.name
  from inserted i
  join public.events e
    on e.id = i.event_id
  join public.seichi s
    on s.id = i.seichi_id
  order by s.card;
end;
$$;

revoke execute on function public.record_place_visit(uuid, timestamptz, double precision, double precision) from public;
revoke execute on function public.record_place_visit(uuid, timestamptz, double precision, double precision) from anon;
grant execute on function public.record_place_visit(uuid, timestamptz, double precision, double precision) to authenticated;

comment on function public.record_place_visit(uuid, timestamptz, double precision, double precision) is
  '訪問時点で開催中の全イベントについて、同一物理地点に紐づく未獲得札を一括記録する。';
