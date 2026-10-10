-- Reconcile live database drift against the intended application schema.
-- Generated from the production schema plus source-controlled admin/storage policies.
-- User-owned data is deliberately not copied or deleted by this migration.

CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE IF NOT EXISTS private.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE private.admin_users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.admin_users FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from private.admin_users au
      where au.user_id = (select auth.uid())
    );
$function$;
REVOKE ALL ON FUNCTION private.is_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_admin() TO authenticated;

INSERT INTO storage.buckets (id, name, public)
VALUES ('event-card-images', 'event-card-images', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('content-media', 'content-media', true, 10485760,
        ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
    insert into public.profiles (
        id,
        display_name,
        avatar_url
    )
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data ->> 'full_name',
            new.raw_user_meta_data ->> 'name'
        ),
        new.raw_user_meta_data ->> 'avatar_url'
    );

    return new;
end;
$function$;
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands() c
    WHERE c.command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND c.object_type IN ('table', 'partitioned table')
      AND c.schema_name = 'public'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_class rel
        JOIN pg_depend dep
          ON dep.classid = 'pg_class'::regclass
         AND dep.objid = rel.oid
         AND dep.deptype = 'e'
        WHERE rel.oid = c.objid
      )
  LOOP
    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', cmd.objid::regclass);
  END LOOP;
END;
$function$;
DO $postgis$
DECLARE v_postgis_schema text;
BEGIN
 SELECT n.nspname INTO v_postgis_schema FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='postgis';
 IF v_postgis_schema = 'gis' THEN
  EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.get_event_contents_nearby(p_event_id uuid, p_latitude double precision, p_longitude double precision, p_radius_meters double precision DEFAULT 50000, p_limit integer DEFAULT 250)
 RETURNS TABLE(event_content_id uuid, content_id uuid, place_id uuid, content_key text, title text, description text, icon text, image_url text, latitude double precision, longitude double precision, stamp_radius_meters integer, prefecture text, city text, display_order integer, distance_meters double precision, is_collected boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select ec.id,c.id,p.id,c.content_key,c.title,c.description,p.icon,coalesce(c.image_url,p.image_url),
p.latitude,p.longitude,p.radius_meters,p.prefecture,p.city,ec.display_order,
gis.st_distance(gis.st_setsrid(gis.st_makepoint(p.longitude,p.latitude),4326)::gis.geography,
            gis.st_setsrid(gis.st_makepoint(p_longitude,p_latitude),4326)::gis.geography) as distance_meters,
exists(select 1 from public.collection_history ch where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id)
from public.event_contents ec
join public.contents c on c.id=ec.content_id and c.is_active
join public.places p on p.id=ec.place_id and p.is_active
where ec.event_id=p_event_id and ec.is_active
and gis.st_dwithin(gis.st_setsrid(gis.st_makepoint(p.longitude,p.latitude),4326)::gis.geography,
               gis.st_setsrid(gis.st_makepoint(p_longitude,p_latitude),4326)::gis.geography,
               greatest(1000,least(coalesce(p_radius_meters,50000),200000)))
order by gis.st_distance(gis.st_setsrid(gis.st_makepoint(p.longitude,p.latitude),4326)::gis.geography,
            gis.st_setsrid(gis.st_makepoint(p_longitude,p_latitude),4326)::gis.geography)
limit greatest(1,least(coalesce(p_limit,250),1000))
$function$;$ddl$;
  EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.record_place_visit_and_collect(p_place_id uuid, p_client_visit_id uuid, p_visited_at timestamp with time zone, p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision, p_source text DEFAULT 'gps'::text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(collection_history_id uuid, event_id uuid, event_name text, content_id uuid, event_content_id uuid, place_id uuid, card text, content_title text, collected_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_place public.places%rowtype;
  v_existing_visit public.place_visits%rowtype;
  v_place_visit_id uuid;
  v_existing_place_id uuid;
  v_effective_visited_at timestamptz := now();
begin
  -- ----------------------------------------------------------
  -- 認証確認
  -- ----------------------------------------------------------
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception '認証が必要です.';
  end if;

  -- ----------------------------------------------------------
  -- 入力値確認
  -- ----------------------------------------------------------
  if p_place_id is null then
    raise exception 'place_idは必須です.';
  end if;

  if p_client_visit_id is null then
    raise exception 'client_visit_idは必須です.';
  end if;

  if p_visited_at is null then
    raise exception 'visited_atは必須です.';
  end if;

  if p_latitude is null
     or p_latitude < -90
     or p_latitude > 90 then
    raise exception 'latitudeが不正です.';
  end if;

  if p_longitude is null
     or p_longitude < -180
     or p_longitude > 180 then
    raise exception 'longitudeが不正です.';
  end if;

  if p_accuracy_meters is not null
     and (
       p_accuracy_meters < 0
       or p_accuracy_meters > 10000
     ) then
    raise exception 'accuracy_metersが不正です.';
  end if;

  if p_source is null or length(trim(p_source)) = 0 then
    raise exception 'sourceは必須です.';
  end if;

  -- ----------------------------------------------------------
  -- 対象place取得
  -- ----------------------------------------------------------
  select *
    into v_place
  from public.places
  where id = p_place_id
    and is_active = true;

  if not found then
    raise exception '有効な物理地点が見つかりません.';
  end if;

  -- ----------------------------------------------------------
  -- client_visit_id の冪等性確認
  -- ----------------------------------------------------------
  select *
    into v_existing_visit
  from public.place_visits
  where user_id = v_user_id
    and client_visit_id = p_client_visit_id
  for update;

  if found then
    -- --------------------------------------------------------
    -- 既存visit:
    -- 最初に保存した訪問事実を正とする。
    -- --------------------------------------------------------
    v_place_visit_id := v_existing_visit.id;
    v_effective_visited_at := v_existing_visit.created_at;

    if v_existing_visit.place_id <> p_place_id then
      raise exception
        '同じclient_visit_idが別の物理地点に使用されています.';
    end if;

  else
    -- --------------------------------------------------------
    -- 新規visit:
    -- この時点だけGPS距離判定を行う。
    -- --------------------------------------------------------
    if not gis.st_dwithin(
      v_place.location,
      gis.st_setsrid(
        gis.st_makepoint(p_longitude, p_latitude),
        4326
      )::gis.geography,
      v_place.radius_meters
    ) then
      raise exception
        '物理地点の獲得範囲外です.';
    end if;

    insert into public.place_visits (
      user_id,
      place_id,
      client_visit_id,
      visited_at,
      latitude,
      longitude,
      accuracy_meters,
      source,
      metadata
    )
    values (
      v_user_id,
      p_place_id,
      p_client_visit_id,
      v_effective_visited_at,
      p_latitude,
      p_longitude,
      p_accuracy_meters,
      p_source,
      coalesce(p_metadata, '{}'::jsonb)
    )
    on conflict (user_id, client_visit_id)
    do nothing
    returning id into v_place_visit_id;

    if v_place_visit_id is not null then
      -- ------------------------------------------------------
      -- 実際に保存されたvisitを取得する。
      -- collection_historyもこの保存値を使用する。
      -- ------------------------------------------------------
      select *
        into v_existing_visit
      from public.place_visits
      where id = v_place_visit_id
      for update;

      v_effective_visited_at := v_existing_visit.created_at;

    else
      -- ------------------------------------------------------
      -- 同時実行で別トランザクションが先に登録した場合。
      -- ------------------------------------------------------
      select *
        into v_existing_visit
      from public.place_visits
      where user_id = v_user_id
        and client_visit_id = p_client_visit_id
      for update;

      if not found then
        raise exception 'place_visitの保存に失敗しました.';
      end if;

      v_place_visit_id := v_existing_visit.id;
      v_effective_visited_at := v_existing_visit.created_at;

      if v_existing_visit.place_id <> p_place_id then
        raise exception
          '同じclient_visit_idが別の物理地点に使用されています.';
      end if;
    end if;
  end if;

  -- ----------------------------------------------------------
  -- イベント期間と獲得時刻は初回受付時のサーバー時刻で判定する。
  -- 再送時も最初の place_visits.created_at を使用する。
  -- p_visited_at は旧クライアントとの引数互換用で、判定には使わない。
  -- ----------------------------------------------------------
  return query
  with eligible as (
    select
      ec.event_id,
      ec.content_id,
      ec.id as event_content_id,
      ec.place_id
    from public.event_contents ec
    join public.events e
      on e.id = ec.event_id
    join public.contents c
      on c.id = ec.content_id
    where ec.place_id = p_place_id
      and ec.is_active = true
      and c.is_active = true
      and e.is_active = true

      -- 最後のイベントリセット以前の訪問は再獲得に使用しない
      and not exists (
        select 1
        from public.event_collection_resets r
        where r.user_id = v_user_id
          and r.event_id = ec.event_id
          and v_effective_visited_at <= r.reset_at
      )

      -- イベント期間
      and (
        e.start_at is null
        or v_effective_visited_at >= e.start_at
      )
      and (
        e.end_at is null
        or v_effective_visited_at < e.end_at
      )

      -- event_content期間
      and (
        ec.start_at is null
        or v_effective_visited_at >= ec.start_at
      )
      and (
        ec.end_at is null
        or v_effective_visited_at < ec.end_at
      )
  ),
  inserted as (
    insert into public.collection_history as ch (
      user_id,
      event_id,
      content_id,
      event_content_id,
      place_id,
      place_visit_id,
      collected_at,
      synced_at,
      latitude,
      longitude
    )
    select
      v_user_id,
      eligible.event_id,
      eligible.content_id,
      eligible.event_content_id,
      eligible.place_id,
      v_place_visit_id,
      v_effective_visited_at,
      now(),

      -- 重要:
      -- collection_historyのGPSも
      -- 最初に保存されたplace_visitsの事実を使用する。
      v_existing_visit.latitude,
      v_existing_visit.longitude

    from eligible
    on conflict do nothing
    returning
      ch.id,
      ch.event_id,
      ch.content_id,
      ch.event_content_id,
      ch.place_id,
      ch.collected_at
  )
  select
    i.id,
    i.event_id,
    e.name,
    i.content_id,
    i.event_content_id,
    i.place_id,
    c.content_key,
    c.title,
    i.collected_at
  from inserted i
  join public.events e
    on e.id = i.event_id
  join public.contents c
    on c.id = i.content_id
  order by e.name, c.content_key;

end;
$function$;$ddl$;
  EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.set_places_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at = now();
  END IF;

  NEW.location =
    gis.st_setsrid(
      gis.st_makepoint(NEW.longitude, NEW.latitude),
      4326
    )::gis.geography;

  RETURN NEW;
END;
$function$;$ddl$;
 ELSIF v_postgis_schema = 'public' THEN
  EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.get_event_contents_nearby(p_event_id uuid, p_latitude double precision, p_longitude double precision, p_radius_meters double precision DEFAULT 50000, p_limit integer DEFAULT 250)
 RETURNS TABLE(event_content_id uuid, content_id uuid, place_id uuid, content_key text, title text, description text, icon text, image_url text, latitude double precision, longitude double precision, stamp_radius_meters integer, prefecture text, city text, display_order integer, distance_meters double precision, is_collected boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select ec.id,c.id,p.id,c.content_key,c.title,c.description,p.icon,coalesce(c.image_url,p.image_url),
p.latitude,p.longitude,p.radius_meters,p.prefecture,p.city,ec.display_order,
st_distance(st_setsrid(st_makepoint(p.longitude,p.latitude),4326)::geography,
            st_setsrid(st_makepoint(p_longitude,p_latitude),4326)::geography) as distance_meters,
exists(select 1 from public.collection_history ch where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id)
from public.event_contents ec
join public.contents c on c.id=ec.content_id and c.is_active
join public.places p on p.id=ec.place_id and p.is_active
where ec.event_id=p_event_id and ec.is_active
and st_dwithin(st_setsrid(st_makepoint(p.longitude,p.latitude),4326)::geography,
               st_setsrid(st_makepoint(p_longitude,p_latitude),4326)::geography,
               greatest(1000,least(coalesce(p_radius_meters,50000),200000)))
order by st_distance(st_setsrid(st_makepoint(p.longitude,p.latitude),4326)::geography,
            st_setsrid(st_makepoint(p_longitude,p_latitude),4326)::geography)
limit greatest(1,least(coalesce(p_limit,250),1000))
$function$;$ddl$;
  EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.record_place_visit_and_collect(p_place_id uuid, p_client_visit_id uuid, p_visited_at timestamp with time zone, p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision, p_source text DEFAULT 'gps'::text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(collection_history_id uuid, event_id uuid, event_name text, content_id uuid, event_content_id uuid, place_id uuid, card text, content_title text, collected_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_place public.places%rowtype;
  v_existing_visit public.place_visits%rowtype;
  v_place_visit_id uuid;
  v_existing_place_id uuid;
  v_effective_visited_at timestamptz := now();
begin
  -- ----------------------------------------------------------
  -- 認証確認
  -- ----------------------------------------------------------
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception '認証が必要です.';
  end if;

  -- ----------------------------------------------------------
  -- 入力値確認
  -- ----------------------------------------------------------
  if p_place_id is null then
    raise exception 'place_idは必須です.';
  end if;

  if p_client_visit_id is null then
    raise exception 'client_visit_idは必須です.';
  end if;

  if p_visited_at is null then
    raise exception 'visited_atは必須です.';
  end if;

  if p_latitude is null
     or p_latitude < -90
     or p_latitude > 90 then
    raise exception 'latitudeが不正です.';
  end if;

  if p_longitude is null
     or p_longitude < -180
     or p_longitude > 180 then
    raise exception 'longitudeが不正です.';
  end if;

  if p_accuracy_meters is not null
     and (
       p_accuracy_meters < 0
       or p_accuracy_meters > 10000
     ) then
    raise exception 'accuracy_metersが不正です.';
  end if;

  if p_source is null or length(trim(p_source)) = 0 then
    raise exception 'sourceは必須です.';
  end if;

  -- ----------------------------------------------------------
  -- 対象place取得
  -- ----------------------------------------------------------
  select *
    into v_place
  from public.places
  where id = p_place_id
    and is_active = true;

  if not found then
    raise exception '有効な物理地点が見つかりません.';
  end if;

  -- ----------------------------------------------------------
  -- client_visit_id の冪等性確認
  -- ----------------------------------------------------------
  select *
    into v_existing_visit
  from public.place_visits
  where user_id = v_user_id
    and client_visit_id = p_client_visit_id
  for update;

  if found then
    -- --------------------------------------------------------
    -- 既存visit:
    -- 最初に保存した訪問事実を正とする。
    -- --------------------------------------------------------
    v_place_visit_id := v_existing_visit.id;
    v_effective_visited_at := v_existing_visit.created_at;

    if v_existing_visit.place_id <> p_place_id then
      raise exception
        '同じclient_visit_idが別の物理地点に使用されています.';
    end if;

  else
    -- --------------------------------------------------------
    -- 新規visit:
    -- この時点だけGPS距離判定を行う。
    -- --------------------------------------------------------
    if not public.st_dwithin(
      v_place.location,
      public.st_setsrid(
        public.st_makepoint(p_longitude, p_latitude),
        4326
      )::public.geography,
      v_place.radius_meters
    ) then
      raise exception
        '物理地点の獲得範囲外です.';
    end if;

    insert into public.place_visits (
      user_id,
      place_id,
      client_visit_id,
      visited_at,
      latitude,
      longitude,
      accuracy_meters,
      source,
      metadata
    )
    values (
      v_user_id,
      p_place_id,
      p_client_visit_id,
      v_effective_visited_at,
      p_latitude,
      p_longitude,
      p_accuracy_meters,
      p_source,
      coalesce(p_metadata, '{}'::jsonb)
    )
    on conflict (user_id, client_visit_id)
    do nothing
    returning id into v_place_visit_id;

    if v_place_visit_id is not null then
      -- ------------------------------------------------------
      -- 実際に保存されたvisitを取得する。
      -- collection_historyもこの保存値を使用する。
      -- ------------------------------------------------------
      select *
        into v_existing_visit
      from public.place_visits
      where id = v_place_visit_id
      for update;

      v_effective_visited_at := v_existing_visit.created_at;

    else
      -- ------------------------------------------------------
      -- 同時実行で別トランザクションが先に登録した場合。
      -- ------------------------------------------------------
      select *
        into v_existing_visit
      from public.place_visits
      where user_id = v_user_id
        and client_visit_id = p_client_visit_id
      for update;

      if not found then
        raise exception 'place_visitの保存に失敗しました.';
      end if;

      v_place_visit_id := v_existing_visit.id;
      v_effective_visited_at := v_existing_visit.created_at;

      if v_existing_visit.place_id <> p_place_id then
        raise exception
          '同じclient_visit_idが別の物理地点に使用されています.';
      end if;
    end if;
  end if;

  -- ----------------------------------------------------------
  -- イベント期間と獲得時刻は初回受付時のサーバー時刻で判定する。
  -- 再送時も最初の place_visits.created_at を使用する。
  -- p_visited_at は旧クライアントとの引数互換用で、判定には使わない。
  -- ----------------------------------------------------------
  return query
  with eligible as (
    select
      ec.event_id,
      ec.content_id,
      ec.id as event_content_id,
      ec.place_id
    from public.event_contents ec
    join public.events e
      on e.id = ec.event_id
    join public.contents c
      on c.id = ec.content_id
    where ec.place_id = p_place_id
      and ec.is_active = true
      and c.is_active = true
      and e.is_active = true

      -- 最後のイベントリセット以前の訪問は再獲得に使用しない
      and not exists (
        select 1
        from public.event_collection_resets r
        where r.user_id = v_user_id
          and r.event_id = ec.event_id
          and v_effective_visited_at <= r.reset_at
      )

      -- イベント期間
      and (
        e.start_at is null
        or v_effective_visited_at >= e.start_at
      )
      and (
        e.end_at is null
        or v_effective_visited_at < e.end_at
      )

      -- event_content期間
      and (
        ec.start_at is null
        or v_effective_visited_at >= ec.start_at
      )
      and (
        ec.end_at is null
        or v_effective_visited_at < ec.end_at
      )
  ),
  inserted as (
    insert into public.collection_history as ch (
      user_id,
      event_id,
      content_id,
      event_content_id,
      place_id,
      place_visit_id,
      collected_at,
      synced_at,
      latitude,
      longitude
    )
    select
      v_user_id,
      eligible.event_id,
      eligible.content_id,
      eligible.event_content_id,
      eligible.place_id,
      v_place_visit_id,
      v_effective_visited_at,
      now(),

      -- 重要:
      -- collection_historyのGPSも
      -- 最初に保存されたplace_visitsの事実を使用する。
      v_existing_visit.latitude,
      v_existing_visit.longitude

    from eligible
    on conflict do nothing
    returning
      ch.id,
      ch.event_id,
      ch.content_id,
      ch.event_content_id,
      ch.place_id,
      ch.collected_at
  )
  select
    i.id,
    i.event_id,
    e.name,
    i.content_id,
    i.event_content_id,
    i.place_id,
    c.content_key,
    c.title,
    i.collected_at
  from inserted i
  join public.events e
    on e.id = i.event_id
  join public.contents c
    on c.id = i.content_id
  order by e.name, c.content_key;

end;
$function$;$ddl$;
  EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.set_places_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at = now();
  END IF;

  NEW.location =
    public.st_setsrid(
      public.st_makepoint(NEW.longitude, NEW.latitude),
      4326
    )::public.geography;

  RETURN NEW;
END;
$function$;$ddl$;
 ELSE
  RAISE EXCEPTION 'Unsupported PostGIS schema: %', v_postgis_schema;
 END IF;
END;
$postgis$;

DROP FUNCTION IF EXISTS public.get_my_admin_status();

-- Apply production function ACLs, preserving authenticated grants explicitly
-- required by source migrations for event counts, recommendations, and server time.
REVOKE ALL ON FUNCTION public."enforce_location_collection_cooldown"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."enforce_location_collection_cooldown"() TO "service_role";
REVOKE ALL ON FUNCTION public."ensure_event_participation"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."ensure_event_participation"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."ensure_event_participation"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."get_collection_series_progress"(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_collection_series_progress"(text) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_collection_counts"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_collection_counts"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_collection_counts"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_contents_by_ids"(uuid, uuid[]) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_contents_by_ids"(uuid, uuid[]) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_contents_by_ids"(uuid, uuid[]) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_contents_by_region"(uuid, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_contents_by_region"(uuid, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_contents_by_region"(uuid, text) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_contents_in_bounds"(uuid, double precision, double precision, double precision, double precision, integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_contents_in_bounds"(uuid, double precision, double precision, double precision, double precision, integer) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_contents_in_bounds"(uuid, double precision, double precision, double precision, double precision, integer) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_contents_nearby"(uuid, double precision, double precision, double precision, integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_contents_nearby"(uuid, double precision, double precision, double precision, integer) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_contents_nearby"(uuid, double precision, double precision, double precision, integer) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_contents_page"(uuid, integer, integer, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_contents_page"(uuid, integer, integer, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_contents_page"(uuid, integer, integer, text) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_geo_scopes"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_geo_scopes"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_geo_scopes"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_progress_summary"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_progress_summary"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_progress_summary"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_recommendations"(integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_recommendations"(integer) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_recommendations"(integer) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_regional_map_progress"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_regional_map_progress"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_regional_map_progress"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."get_event_social_stats"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_event_social_stats"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_event_social_stats"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."get_my_collection_history"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_my_collection_history"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_my_collection_history"() TO "service_role";
REVOKE ALL ON FUNCTION public."get_my_event_rank"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_my_event_rank"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_my_event_rank"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."get_my_location_security_state"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_my_location_security_state"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_my_location_security_state"() TO "service_role";
REVOKE ALL ON FUNCTION public."get_public_ranking"(uuid, integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."get_public_ranking"(uuid, integer) TO "anon";
GRANT EXECUTE ON FUNCTION public."get_public_ranking"(uuid, integer) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."get_public_ranking"(uuid, integer) TO "service_role";
REVOKE ALL ON FUNCTION public."handle_new_user"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."handle_new_user"() TO "service_role";
REVOKE ALL ON FUNCTION public."leave_event_participation"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."leave_event_participation"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."leave_event_participation"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."record_place_visit_and_collect"(uuid, uuid, timestamp with time zone, double precision, double precision, double precision, text, jsonb) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."record_place_visit_and_collect"(uuid, uuid, timestamp with time zone, double precision, double precision, double precision, text, jsonb) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."record_place_visit_and_collect"(uuid, uuid, timestamp with time zone, double precision, double precision, double precision, text, jsonb) TO "service_role";
REVOKE ALL ON FUNCTION public."replace_roadside_station_registry"(jsonb) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."replace_roadside_station_registry"(jsonb) TO "service_role";
REVOKE ALL ON FUNCTION public."report_location_integrity_violation"(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."report_location_integrity_violation"(text) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."report_location_integrity_violation"(text) TO "service_role";
REVOKE ALL ON FUNCTION public."reset_event_collection_history"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."reset_event_collection_history"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."reset_event_collection_history"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."rls_auto_enable"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."rls_auto_enable"() TO "service_role";
REVOKE ALL ON FUNCTION public."save_my_profile"(text, text, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."save_my_profile"(text, text, text) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."save_my_profile"(text, text, text) TO "service_role";
REVOKE ALL ON FUNCTION public."set_current_event_preference"(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."set_current_event_preference"(uuid) TO "authenticated";
GRANT EXECUTE ON FUNCTION public."set_current_event_preference"(uuid) TO "service_role";
REVOKE ALL ON FUNCTION public."set_events_updated_at"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."set_events_updated_at"() TO "service_role";
REVOKE ALL ON FUNCTION public."set_places_updated_at"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."set_places_updated_at"() TO "service_role";
REVOKE ALL ON FUNCTION public."set_updated_at"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."set_updated_at"() TO "service_role";
REVOKE ALL ON FUNCTION public."story_preview_server_time"() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public."story_preview_server_time"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."story_preview_server_time"() TO "service_role";

-- RPC-managed tables: remove both table-level and column-level direct writes.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.profiles FROM anon, authenticated;
REVOKE INSERT (id, display_name, avatar_url, age_group, gender, is_active, created_at, updated_at, avatar_key) ON TABLE public.profiles FROM anon, authenticated;
REVOKE UPDATE (id, display_name, avatar_url, age_group, gender, is_active, created_at, updated_at, avatar_key) ON TABLE public.profiles FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_participations FROM anon, authenticated;
REVOKE INSERT (user_id, event_id, joined_at, is_active, left_at, updated_at) ON TABLE public.user_event_participations FROM anon, authenticated;
REVOKE UPDATE (user_id, event_id, joined_at, is_active, left_at, updated_at) ON TABLE public.user_event_participations FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_preferences FROM anon, authenticated;
REVOKE INSERT (user_id, current_event_id, updated_at) ON TABLE public.user_event_preferences FROM anon, authenticated;
REVOKE UPDATE (user_id, current_event_id, updated_at) ON TABLE public.user_event_preferences FROM anon, authenticated;

DROP POLICY IF EXISTS user_event_participations_insert_own ON public.user_event_participations;
DROP POLICY IF EXISTS user_event_participations_update_own ON public.user_event_participations;
DROP POLICY IF EXISTS user_event_participations_delete_own ON public.user_event_participations;
DROP POLICY IF EXISTS user_event_preferences_insert_own ON public.user_event_preferences;
DROP POLICY IF EXISTS user_event_preferences_update_own ON public.user_event_preferences;
DROP POLICY IF EXISTS user_event_preferences_delete_own ON public.user_event_preferences;
DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;

-- Admin-only direct editing is intentionally retained for content blocks and event theme fields.
REVOKE ALL ON TABLE public.content_blocks FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.content_blocks TO authenticated;

REVOKE UPDATE ON TABLE public.events FROM anon, authenticated;
REVOKE UPDATE (theme_primary_hex, theme_primary_deep_hex, theme_accent_hex)
  ON TABLE public.events FROM anon, authenticated;
GRANT UPDATE (theme_primary_hex, theme_primary_deep_hex, theme_accent_hex)
  ON TABLE public.events TO authenticated;

REVOKE UPDATE ON TABLE public.places FROM anon, authenticated;
REVOKE UPDATE (latitude, longitude, name, radius_meters)
  ON TABLE public.places FROM anon, authenticated;

REVOKE ALL ON TABLE public.place_visits FROM anon, authenticated;
GRANT SELECT ON TABLE public.place_visits TO authenticated;

-- Rebuild policies from production-secure definitions plus source-controlled
-- admin/own-row policies and Storage policies.
DROP POLICY IF EXISTS "achievements_select_authenticated" ON "public"."achievements";
DROP POLICY IF EXISTS "announcement_reads_insert_own" ON "public"."announcement_reads";
DROP POLICY IF EXISTS "announcement_reads_select_own" ON "public"."announcement_reads";
DROP POLICY IF EXISTS "announcement_reads_update_own" ON "public"."announcement_reads";
DROP POLICY IF EXISTS "announcements_select_published" ON "public"."announcements";
DROP POLICY IF EXISTS "app_release_policies_read_active" ON "public"."app_release_policies";
DROP POLICY IF EXISTS "collection_history_select_own" ON "public"."collection_history";
DROP POLICY IF EXISTS "collection_series_read_active" ON "public"."collection_series";
DROP POLICY IF EXISTS "collection_series_places_read_active" ON "public"."collection_series_places";
DROP POLICY IF EXISTS "collection_series_regions_read_active" ON "public"."collection_series_regions";
DROP POLICY IF EXISTS "content_blocks_select_active" ON "public"."content_blocks";
DROP POLICY IF EXISTS "contents_select_active" ON "public"."contents";
DROP POLICY IF EXISTS "event_achievements_select_active_event" ON "public"."event_achievements";
DROP POLICY IF EXISTS "event_contents_select_published" ON "public"."event_contents";
DROP POLICY IF EXISTS "events_select_active" ON "public"."events";
DROP POLICY IF EXISTS "geo_region_prefectures_read_active" ON "public"."geo_region_prefectures";
DROP POLICY IF EXISTS "geo_regions_read_active" ON "public"."geo_regions";
DROP POLICY IF EXISTS "places_select_active" ON "public"."places";
DROP POLICY IF EXISTS "profiles_select_own" ON "public"."profiles";
DROP POLICY IF EXISTS "user_event_favorites_delete_own" ON "public"."user_event_favorites";
DROP POLICY IF EXISTS "user_event_favorites_insert_own" ON "public"."user_event_favorites";
DROP POLICY IF EXISTS "user_event_favorites_select_own" ON "public"."user_event_favorites";
DROP POLICY IF EXISTS "user_event_participations_select_own" ON "public"."user_event_participations";
DROP POLICY IF EXISTS "user_event_preferences_select_own" ON "public"."user_event_preferences";
DROP POLICY IF EXISTS "collection_series_read" ON "public"."collection_series";
DROP POLICY IF EXISTS "collection_series_places_read" ON "public"."collection_series_places";
DROP POLICY IF EXISTS "collection_series_regions_read" ON "public"."collection_series_regions";
DROP POLICY IF EXISTS "content_blocks_admin_delete" ON "public"."content_blocks";
DROP POLICY IF EXISTS "content_blocks_admin_insert" ON "public"."content_blocks";
DROP POLICY IF EXISTS "content_blocks_admin_update" ON "public"."content_blocks";
DROP POLICY IF EXISTS "event_achievements_select_authenticated" ON "public"."event_achievements";
DROP POLICY IF EXISTS "event_contents_select_active" ON "public"."event_contents";
DROP POLICY IF EXISTS "events_admin_update_theme" ON "public"."events";
DROP POLICY IF EXISTS "events_select_active_anon" ON "public"."events";
DROP POLICY IF EXISTS "geo_region_prefectures_read" ON "public"."geo_region_prefectures";
DROP POLICY IF EXISTS "geo_regions_read" ON "public"."geo_regions";
DROP POLICY IF EXISTS "place_visits_select_own" ON "public"."place_visits";
DROP POLICY IF EXISTS "places_admin_update" ON "public"."places";
DROP POLICY IF EXISTS "profiles_insert_own" ON "public"."profiles";
DROP POLICY IF EXISTS "profiles_update_own" ON "public"."profiles";
DROP POLICY IF EXISTS "user_event_participations_delete_own" ON "public"."user_event_participations";
DROP POLICY IF EXISTS "user_event_participations_insert_own" ON "public"."user_event_participations";
DROP POLICY IF EXISTS "user_event_participations_update_own" ON "public"."user_event_participations";
DROP POLICY IF EXISTS "user_event_preferences_delete_own" ON "public"."user_event_preferences";
DROP POLICY IF EXISTS "user_event_preferences_insert_own" ON "public"."user_event_preferences";
DROP POLICY IF EXISTS "user_event_preferences_update_own" ON "public"."user_event_preferences";
DROP POLICY IF EXISTS "content_media_admin_delete" ON "storage"."objects";
DROP POLICY IF EXISTS "content_media_admin_insert" ON "storage"."objects";
DROP POLICY IF EXISTS "content_media_admin_select" ON "storage"."objects";
DROP POLICY IF EXISTS "content_media_admin_update" ON "storage"."objects";
DROP POLICY IF EXISTS "event_card_images_public_read" ON "storage"."objects";

-- Public-schema application policies
CREATE POLICY "achievements_select_authenticated" ON "public"."achievements" AS PERMISSIVE FOR SELECT TO "authenticated"
USING (true);
CREATE POLICY "announcement_reads_insert_own" ON "public"."announcement_reads" AS PERMISSIVE FOR INSERT TO "authenticated"
WITH CHECK (((( SELECT auth.uid() AS uid) = user_id) AND (EXISTS ( SELECT 1
   FROM announcements a
  WHERE ((a.id = announcement_reads.announcement_id) AND a.is_active AND (a.publish_from <= now()) AND ((a.publish_until IS NULL) OR (now() < a.publish_until)))))));
CREATE POLICY "announcement_reads_select_own" ON "public"."announcement_reads" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "announcement_reads_update_own" ON "public"."announcement_reads" AS PERMISSIVE FOR UPDATE TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id))
WITH CHECK (((( SELECT auth.uid() AS uid) = user_id) AND (EXISTS ( SELECT 1
   FROM announcements a
  WHERE ((a.id = announcement_reads.announcement_id) AND a.is_active AND (a.publish_from <= now()) AND ((a.publish_until IS NULL) OR (now() < a.publish_until)))))));
CREATE POLICY "announcements_select_published" ON "public"."announcements" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((is_active AND (publish_from <= now()) AND ((publish_until IS NULL) OR (now() < publish_until))));
CREATE POLICY "app_release_policies_read_active" ON "public"."app_release_policies" AS PERMISSIVE FOR SELECT TO "anon", "authenticated"
USING (is_active);
CREATE POLICY "collection_history_select_own" ON "public"."collection_history" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "collection_series_read_active" ON "public"."collection_series" AS PERMISSIVE FOR SELECT TO "authenticated"
USING (is_active);
CREATE POLICY "collection_series_places_read_active" ON "public"."collection_series_places" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((EXISTS ( SELECT 1
   FROM collection_series s
  WHERE ((s.id = collection_series_places.series_id) AND s.is_active))));
CREATE POLICY "collection_series_regions_read_active" ON "public"."collection_series_regions" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((is_active AND (EXISTS ( SELECT 1
   FROM collection_series s
  WHERE ((s.id = collection_series_regions.series_id) AND s.is_active)))));
CREATE POLICY "content_blocks_select_active" ON "public"."content_blocks" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((is_active AND (EXISTS ( SELECT 1
   FROM contents c
  WHERE ((c.id = content_blocks.content_id) AND c.is_active)))));
CREATE POLICY "contents_select_active" ON "public"."contents" AS PERMISSIVE FOR SELECT TO "authenticated"
USING (is_active);
CREATE POLICY "event_achievements_select_active_event" ON "public"."event_achievements" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = event_achievements.event_id) AND e.is_active))));
CREATE POLICY "event_contents_select_published" ON "public"."event_contents" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((is_active AND (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = event_contents.event_id) AND e.is_active))) AND (EXISTS ( SELECT 1
   FROM contents c
  WHERE ((c.id = event_contents.content_id) AND c.is_active))) AND (EXISTS ( SELECT 1
   FROM places p
  WHERE ((p.id = event_contents.place_id) AND p.is_active)))));
CREATE POLICY "events_select_active" ON "public"."events" AS PERMISSIVE FOR SELECT TO "anon", "authenticated"
USING (is_active);
CREATE POLICY "geo_region_prefectures_read_active" ON "public"."geo_region_prefectures" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((EXISTS ( SELECT 1
   FROM geo_regions r
  WHERE ((r.id = geo_region_prefectures.region_id) AND r.is_active))));
CREATE POLICY "geo_regions_read_active" ON "public"."geo_regions" AS PERMISSIVE FOR SELECT TO "authenticated"
USING (is_active);
CREATE POLICY "places_select_active" ON "public"."places" AS PERMISSIVE FOR SELECT TO "authenticated"
USING (is_active);
CREATE POLICY "profiles_select_own" ON "public"."profiles" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "user_event_favorites_delete_own" ON "public"."user_event_favorites" AS PERMISSIVE FOR DELETE TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "user_event_favorites_insert_own" ON "public"."user_event_favorites" AS PERMISSIVE FOR INSERT TO "authenticated"
WITH CHECK (((( SELECT auth.uid() AS uid) = user_id) AND (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = user_event_favorites.event_id) AND e.is_active)))));
CREATE POLICY "user_event_favorites_select_own" ON "public"."user_event_favorites" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "user_event_participations_select_own" ON "public"."user_event_participations" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "user_event_preferences_select_own" ON "public"."user_event_preferences" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "content_blocks_admin_delete" ON "public"."content_blocks" AS PERMISSIVE FOR DELETE TO "authenticated"
USING (( SELECT private.is_admin() AS is_admin));
CREATE POLICY "content_blocks_admin_insert" ON "public"."content_blocks" AS PERMISSIVE FOR INSERT TO "authenticated"
WITH CHECK (( SELECT private.is_admin() AS is_admin));
CREATE POLICY "content_blocks_admin_update" ON "public"."content_blocks" AS PERMISSIVE FOR UPDATE TO "authenticated"
USING (( SELECT private.is_admin() AS is_admin))
WITH CHECK (( SELECT private.is_admin() AS is_admin));
CREATE POLICY "events_admin_update_theme" ON "public"."events" AS PERMISSIVE FOR UPDATE TO "authenticated"
USING (( SELECT private.is_admin() AS is_admin))
WITH CHECK (( SELECT private.is_admin() AS is_admin));
CREATE POLICY "place_visits_select_own" ON "public"."place_visits" AS PERMISSIVE FOR SELECT TO "authenticated"
USING ((( SELECT auth.uid() AS uid) = user_id));


-- Storage policies from source migrations
CREATE POLICY "event_card_images_public_read" ON storage.objects AS PERMISSIVE FOR SELECT TO PUBLIC USING (bucket_id = 'event-card-images');
CREATE POLICY "content_media_admin_insert" ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (bucket_id = 'content-media' AND (SELECT private.is_admin()));
CREATE POLICY "content_media_admin_update" ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated USING (bucket_id = 'content-media' AND (SELECT private.is_admin())) WITH CHECK (bucket_id = 'content-media' AND (SELECT private.is_admin()));
CREATE POLICY "content_media_admin_delete" ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated USING (bucket_id = 'content-media' AND (SELECT private.is_admin()));
CREATE POLICY "content_media_admin_select" ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated USING (bucket_id = 'content-media' AND (SELECT private.is_admin()));

DO $rls$
DECLARE r record;
BEGIN
 FOR r IN
   SELECT n.nspname, c.relname
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relkind IN ('r','p')
     AND NOT EXISTS (
       SELECT 1 FROM pg_depend d
       WHERE d.classid='pg_class'::regclass AND d.objid=c.oid AND d.deptype='e'
     )
 LOOP
   EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.nspname, r.relname);
 END LOOP;
END;
$rls$;

-- The PostGIS extension is installed in different schemas in these projects
-- (gis in production, public in test). Its extension-owned objects are not
-- relocated here; moving the extension safely requires a separate operation.
