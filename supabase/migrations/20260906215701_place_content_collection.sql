-- ============================================================
-- 聖地クエスト：物理地点・コンテンツ・イベント紐付け基盤
-- ============================================================
--
-- places
--   実在する物理地点
--
-- contents
--   収集対象となるコンテンツ
--
-- event_contents
--   どのイベントで、どのコンテンツを、どの地点で獲得できるか
--
-- place_visits
--   ユーザーが物理地点を訪問した事実
--
-- collection_history
--   サーバーが判定した実際の獲得結果
--
-- 既存 seichi は移行期間中の互換用として残す。
-- ============================================================


-- ============================================================
-- 1. places
-- ============================================================

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  radius_meters integer not null default 200,
  location geography(point, 4326),
  address text,
  prefecture text,
  city text,
  category text,
  description text,
  icon text,
  image_url text,
  official_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint places_latitude_check
    check (latitude between -90 and 90),

  constraint places_longitude_check
    check (longitude between -180 and 180),

  constraint places_radius_check
    check (radius_meters between 50 and 1000)
);

create index if not exists places_location_gix
  on public.places
  using gist (location);

create index if not exists places_is_active_idx
  on public.places (is_active);


-- ============================================================
-- 2. places.location を座標から生成
-- ============================================================

update public.places
set location =
  st_setsrid(
    st_makepoint(longitude, latitude),
    4326
  )::geography
where location is null;


-- ============================================================
-- 3. places.updated_at
-- ============================================================

create or replace function public.set_places_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  new.location =
    st_setsrid(
      st_makepoint(new.longitude, new.latitude),
      4326
    )::geography;
  return new;
end;
$$;

drop trigger if exists places_set_updated_at
  on public.places;

create trigger places_set_updated_at
before insert or update of latitude, longitude, name, radius_meters,
  address, prefecture, city, category, description, icon,
  image_url, official_url, is_active
on public.places
for each row
execute function public.set_places_updated_at();


-- ============================================================
-- 4. contents
-- ============================================================

create table if not exists public.contents (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'stamp',
  content_key text not null,
  title text not null,
  description text,
  image_url text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint contents_type_content_key_unique
    unique (type, content_key)
);

create index if not exists contents_is_active_idx
  on public.contents (is_active);


-- ============================================================
-- 5. event_contents
-- ============================================================

create table if not exists public.event_contents (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null
    references public.events(id)
    on delete restrict,
  content_id uuid not null
    references public.contents(id)
    on delete restrict,
  place_id uuid not null
    references public.places(id)
    on delete restrict,
  display_order integer not null default 0,
  start_at timestamptz,
  end_at timestamptz,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint event_contents_period_check
    check (
      end_at is null
      or start_at is null
      or start_at < end_at
    ),

  constraint event_contents_unique
    unique (event_id, content_id, place_id)
);

create index if not exists event_contents_event_idx
  on public.event_contents (event_id);

create index if not exists event_contents_content_idx
  on public.event_contents (content_id);

create index if not exists event_contents_place_idx
  on public.event_contents (place_id);

create index if not exists event_contents_active_idx
  on public.event_contents (is_active);


-- ============================================================
-- 6. place_visits
-- ============================================================

create table if not exists public.place_visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references auth.users(id)
    on delete cascade,
  place_id uuid not null
    references public.places(id)
    on delete restrict,

  client_visit_id uuid not null,
  visited_at timestamptz not null,

  latitude double precision not null,
  longitude double precision not null,
  accuracy_meters double precision,

  source text not null default 'gps',
  metadata jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),

  constraint place_visits_latitude_check
    check (latitude between -90 and 90),

  constraint place_visits_longitude_check
    check (longitude between -180 and 180),

  constraint place_visits_accuracy_check
    check (
      accuracy_meters is null
      or accuracy_meters >= 0
    ),

  constraint place_visits_user_client_unique
    unique (user_id, client_visit_id)
);

create index if not exists place_visits_user_idx
  on public.place_visits (user_id);

create index if not exists place_visits_place_idx
  on public.place_visits (place_id);

create index if not exists place_visits_visited_at_idx
  on public.place_visits (visited_at);


-- ============================================================
-- 7. collection_history に新構造を追加
-- ============================================================

alter table public.collection_history
  add column if not exists content_id uuid
    references public.contents(id)
    on delete restrict;

alter table public.collection_history
  add column if not exists event_content_id uuid
    references public.event_contents(id)
    on delete restrict;

alter table public.collection_history
  add column if not exists place_id uuid
    references public.places(id)
    on delete restrict;

alter table public.collection_history
  add column if not exists place_visit_id uuid
    references public.place_visits(id)
    on delete restrict;


create index if not exists collection_history_content_idx
  on public.collection_history (content_id);

create index if not exists collection_history_event_content_idx
  on public.collection_history (event_content_id);

create index if not exists collection_history_place_idx
  on public.collection_history (place_id);

create index if not exists collection_history_place_visit_idx
  on public.collection_history (place_visit_id);


-- ============================================================
-- 8. 現在の seichi → places 移行
--    同一座標は1物理地点に統合
-- ============================================================

insert into public.places (
  name,
  latitude,
  longitude,
  radius_meters,
  location,
  description,
  icon,
  is_active
)
select
  min(s.name) as name,
  s.latitude,
  s.longitude,
  max(s.stamp_radius_meters) as radius_meters,
  st_setsrid(
    st_makepoint(s.longitude, s.latitude),
    4326
  )::geography as location,
  min(s.description) as description,
  min(s.icon) as icon,
  bool_or(s.is_active) as is_active
from public.seichi s
group by s.latitude, s.longitude
on conflict do nothing;


-- ============================================================
-- 9. 現在の seichi → contents 移行
-- ============================================================

insert into public.contents (
  type,
  content_key,
  title,
  description,
  metadata,
  is_active
)
select
  'jomo_karuta_stamp',
  s.card,
  s.name,
  s.description,
  jsonb_build_object(
    'card', s.card,
    'reading', s.reading,
    'legacy_seichi_id', s.id::text
  ),
  s.is_active
from public.seichi s
on conflict (type, content_key) do update
set
  title = excluded.title,
  description = excluded.description,
  metadata = excluded.metadata,
  is_active = excluded.is_active;


-- ============================================================
-- 10. 現在の seichi → event_contents 移行
-- ============================================================

insert into public.event_contents (
  event_id,
  content_id,
  place_id,
  display_order,
  is_active
)
select
  s.event_id,
  c.id,
  p.id,
  row_number() over (
    partition by s.event_id
    order by s.card
  ),
  s.is_active
from public.seichi s
join public.contents c
  on c.type = 'jomo_karuta_stamp'
 and c.content_key = s.card
join public.places p
  on p.latitude = s.latitude
 and p.longitude = s.longitude
on conflict (event_id, content_id, place_id) do update
set
  is_active = excluded.is_active;


-- ============================================================
-- 11. 既存 collection_history を新構造へ対応
-- ============================================================

update public.collection_history ch
set
  content_id = c.id,
  event_content_id = ec.id,
  place_id = p.id
from public.seichi s
join public.contents c
  on c.type = 'jomo_karuta_stamp'
 and c.content_key = s.card
join public.places p
  on p.latitude = s.latitude
 and p.longitude = s.longitude
join public.event_contents ec
  on ec.content_id = c.id
 and ec.place_id = p.id
where ch.seichi_id = s.id
  and ec.event_id = ch.event_id
  and (
    ch.content_id is null
    or ch.event_content_id is null
    or ch.place_id is null
  );


-- ============================================================
-- 12. RLS
-- ============================================================

alter table public.places enable row level security;
alter table public.contents enable row level security;
alter table public.event_contents enable row level security;
alter table public.place_visits enable row level security;


drop policy if exists "places_select_active"
  on public.places;

create policy "places_select_active"
on public.places
for select
to authenticated
using (is_active = true);


drop policy if exists "contents_select_active"
  on public.contents;

create policy "contents_select_active"
on public.contents
for select
to authenticated
using (is_active = true);


drop policy if exists "event_contents_select_active"
  on public.event_contents;

create policy "event_contents_select_active"
on public.event_contents
for select
to authenticated
using (is_active = true);


drop policy if exists "place_visits_select_own"
  on public.place_visits;

create policy "place_visits_select_own"
on public.place_visits
for select
to authenticated
using (auth.uid() = user_id);


-- place_visits の直接INSERTは許可しない。
-- collection_history の直接INSERT/UPDATEも後続migrationでRPC専用にする。


-- ============================================================
-- 13. 権限
-- ============================================================

revoke all on public.places from anon, authenticated;
revoke all on public.contents from anon, authenticated;
revoke all on public.event_contents from anon, authenticated;
revoke all on public.place_visits from anon, authenticated;

grant select on public.places to authenticated;
grant select on public.contents to authenticated;
grant select on public.event_contents to authenticated;
grant select on public.place_visits to authenticated;


-- ============================================================
-- 14. コメント
-- ============================================================

comment on table public.places is
  '聖地クエストの実在する物理地点。複数のコンテンツが同一地点に紐付く。';

comment on table public.contents is
  '聖地クエストで収集可能なコンテンツ。イベントには直接所属しない。';

comment on table public.event_contents is
  'イベント・コンテンツ・物理地点の組み合わせ。開催期間や公開状態もここで管理する。';

comment on table public.place_visits is
  'ユーザーが物理地点を訪問した事実。訪問時刻は同期時刻ではなくvisited_atを保持する。';

comment on table public.collection_history is
  'サーバー判定によって成立したコンテンツ獲得履歴。';


-- ============================================================
-- END
-- ============================================================