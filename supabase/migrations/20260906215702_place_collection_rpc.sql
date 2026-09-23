-- ============================================================
-- 聖地クエスト
-- 物理地点ベース・サーバー権威型スタンプ獲得RPC
--
-- 原則:
--   place_visits = 実際の訪問事実
--   events = 訪問時点で有効なイベント
--   event_contents = そのイベントでその場所から獲得可能なコンテンツ
--   collection_history = 実際に獲得した結果
--
-- Flutterから event_id / content_id / event_content_id は受け取らない。
-- 訪問時刻を基準にサーバー側で獲得対象を決定する。
-- ============================================================


-- ============================================================
-- 1. collection_history の新アーキテクチャ対応
-- ============================================================

-- 新しい獲得は content / event_content / place / place_visit を
-- 主軸とするため、旧 seichi_id は互換用としてNULLを許可する。
alter table public.collection_history
  alter column seichi_id drop not null;


-- 同じユーザーが同じ event_content を二重取得しないことを
-- DBレベルで保証する。
--
-- event_content_id は旧履歴ではNULLの場合があるため、
-- 旧履歴には影響しない。
create unique index if not exists
  collection_history_user_event_content_unique
on public.collection_history (user_id, event_content_id)
where event_content_id is not null;


-- ============================================================
-- 2. place_visits の追加整合性
-- ============================================================

-- 同じ client_visit_id を別の place_id として再送することを防ぐ。
-- 既存の user_id + client_visit_id UNIQUE と合わせて、
-- RPC内でも明示的に検証する。


-- ============================================================
-- 3. 物理地点訪問 + スタンプ獲得RPC
-- ============================================================

create or replace function public.record_place_visit_and_collect(
  p_place_id uuid,
  p_client_visit_id uuid,
  p_visited_at timestamptz,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision,
  p_source text default 'gps',
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  collection_history_id uuid,
  event_id uuid,
  event_name text,
  content_id uuid,
  event_content_id uuid,
  place_id uuid,
  card text,
  content_title text,
  collected_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid;
  v_place public.places%rowtype;
  v_existing_visit public.place_visits%rowtype;
  v_place_visit_id uuid;
  v_existing_place_id uuid;
  v_effective_visited_at timestamptz;
begin
  -- ----------------------------------------------------------
  -- 認証確認
  -- ----------------------------------------------------------
  v_user_id := auth.uid();


  if v_user_id is null then
    raise exception '認証されたユーザーが必要です.';
  end if;


  -- ----------------------------------------------------------
  -- 入力値検証
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
    raise exception 'sourceが不正です.';
  end if;


  -- ----------------------------------------------------------
  -- 物理地点取得
  -- ----------------------------------------------------------
  select *
    into v_place
  from public.places
  where id = p_place_id
    and is_active = true;

  if not found then
    raise exception '指定された物理地点は存在しないか無効です.';
  end if;



  -- ----------------------------------------------------------
  -- client_visit_id の冪等性確認
  --
  -- オフライン再送などで同じ訪問が送られてきても、
  -- place_visits を二重作成しない。
  -- ----------------------------------------------------------
  select *
    into v_existing_visit
  from public.place_visits
  where user_id = v_user_id
    and client_visit_id = p_client_visit_id
  for update;

  if found then
    if v_existing_visit.place_id <> p_place_id then
      raise exception
        '同じclient_visit_idが別の物理地点に使用されています.';
    end if;

    -- 同じ訪問の再送では、最初に保存した訪問事実を正とする。
    -- 特に visited_at は同期時刻などで上書きしない。
    v_place_visit_id := v_existing_visit.id;
    v_effective_visited_at := v_existing_visit.visited_at;
  else
    -- --------------------------------------------------------
    -- 新規訪問のみサーバー側GPS距離判定を行う。
    --
    -- 既存visitの再送では、保存済みplace_visitを訪問事実の正とし、
    -- 再送時のGPS値による再判定は行わない。
    -- --------------------------------------------------------
    if not extensions.st_dwithin(
      v_place.location,
      extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude),
        4326
      )::geography,
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
      p_visited_at,
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
      select *
        into v_existing_visit
      from public.place_visits
      where id = v_place_visit_id
      for update;

      v_effective_visited_at := v_existing_visit.visited_at;
    end if;

    -- 同時実行で別トランザクションが先に登録した場合。
    if v_place_visit_id is null then
      select id
        into v_place_visit_id
      from public.place_visits
      where user_id = v_user_id
        and client_visit_id = p_client_visit_id
      for update;

      if v_place_visit_id is null then
        raise exception 'place_visitの保存に失敗しました.';
      end if;

      select visited_at
        into v_effective_visited_at
      from public.place_visits
      where id = v_place_visit_id;

      select place_id
        into v_existing_place_id
      from public.place_visits
      where id = v_place_visit_id;

      if v_existing_place_id <> p_place_id then
        raise exception
          '同じclient_visit_idが別の物理地点に使用されています.';
      end if;
    end if;
  end if;


  -- ----------------------------------------------------------
  -- 訪問時点で有効な event_contents を判定して獲得
  --
  -- 重要:
  --   判定基準は now() ではなく v_effective_visited_at。
  --   新規訪問では p_visited_at、
  --   再送では最初に保存された place_visits.visited_at を使用する。
  --
  -- これにより:
  --   9/10訪問
  --   A = 9/1-9/30
  --   B = 9/5-9/20
  --   C = 10/1-
  --
  --   → A/Bのみ獲得
  -- ----------------------------------------------------------
  return query
  with eligible as (
    select
      e.id as event_id,
      e.name as event_name,
      ec.id as event_content_id,
      ec.content_id,
      ec.place_id,
      c.content_key,
      c.title,
      s.id as legacy_seichi_id
    from public.event_contents ec
    join public.events e
      on e.id = ec.event_id
    join public.contents c
      on c.id = ec.content_id
    left join public.seichi s
      on s.event_id = ec.event_id
     and s.card = c.content_key
     and s.latitude = v_place.latitude
     and s.longitude = v_place.longitude
    where ec.place_id = p_place_id
      and ec.is_active = true
      and c.is_active = true
      and e.is_active = true

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
    insert into public.collection_history (
      user_id,
      seichi_id,
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
      eligible.legacy_seichi_id,
      eligible.event_id,
      eligible.content_id,
      eligible.event_content_id,
      eligible.place_id,
      v_place_visit_id,
      v_effective_visited_at,
      now(),
       v_existing_visit.latitude,
       v_existing_visit.longitude
    from eligible
    on conflict do nothing
    returning
      id,
      event_id,
      content_id,
      event_content_id,
      place_id,
      collected_at
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
$function$;


-- ============================================================
-- 4. RPC権限
-- ============================================================

revoke all on function public.record_place_visit_and_collect(
  uuid,
  uuid,
  timestamptz,
  double precision,
  double precision,
  double precision,
  text,
  jsonb
)
from public, anon, authenticated;

grant execute on function public.record_place_visit_and_collect(
  uuid,
  uuid,
  timestamptz,
  double precision,
  double precision,
  double precision,
  text,
  jsonb
)
to authenticated;


-- ============================================================
-- 5. 直接INSERT/UPDATEはまだ残す
--
-- Flutterが新RPCへ完全移行するまでは、
-- collection_history の既存INSERT/UPDATE権限を削除しない。
--
-- Flutter移行完了後に別migrationで削除する。
-- ============================================================


-- ============================================================
-- 6. コメント
-- ============================================================

comment on function public.record_place_visit_and_collect(
  uuid,
  uuid,
  timestamptz,
  double precision,
  double precision,
  double precision,
  text,
  jsonb
) is
'聖地クエストの物理地点訪問・スタンプ獲得RPC。訪問時刻を基準に有効なイベントとevent_contentsをサーバー側で判定し、place_visitとcollection_historyを冪等に記録する。event_id/content_id/event_content_idはクライアントから受け取らない。';