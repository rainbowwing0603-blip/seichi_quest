-- 既存の位置情報対策と新しい collection_history スキーマを維持し、
-- スタンプ獲得の時刻のみサーバーの初回受付時刻に切り替える。
CREATE OR REPLACE FUNCTION public.record_place_visit_and_collect(p_place_id uuid, p_client_visit_id uuid, p_visited_at timestamp with time zone, p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision, p_source text DEFAULT 'gps'::text, p_metadata jsonb DEFAULT '{}'::jsonb)
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
$function$
;
