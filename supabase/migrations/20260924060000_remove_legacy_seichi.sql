-- ============================================================
-- QuestItem transition compatibility
--
-- Flutter now uses event_contents.id as the collection identity.
-- Keep legacy public.seichi / collection_history.seichi_id temporarily so
-- already-installed app builds continue to work during rollout.
-- A later migration may remove them after legacy clients are retired.
-- ============================================================

do $$
begin
  if exists (
    select 1
    from public.collection_history ch
    left join public.event_contents ec
      on ec.id = ch.event_content_id
    where ch.event_content_id is null
       or ch.content_id is null
       or ch.place_id is null
       or ec.id is null
       or ec.event_id is distinct from ch.event_id
       or ec.content_id is distinct from ch.content_id
       or ec.place_id is distinct from ch.place_id
  ) then
    raise exception
      'QuestItem transition aborted: collection_history is not fully consistent with event_contents';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from public.event_contents ec
    left join public.events e on e.id = ec.event_id
    left join public.contents c on c.id = ec.content_id
    left join public.places p on p.id = ec.place_id
    where e.id is null
       or c.id is null
       or p.id is null
  ) then
    raise exception
      'QuestItem transition aborted: event_contents contains broken generic references';
  end if;
end;
$$;

-- Keep the existing collection RPC compatible with older clients.
-- It already writes both legacy seichi_id and generic event/content/place IDs.
-- Only the history read RPC needs to expose the generic identity to the new app.
drop function if exists public.get_my_collection_history();

create function public.get_my_collection_history()
returns table (
  event_id uuid,
  event_name text,
  content_id uuid,
  card text,
  seichi_id uuid,
  event_content_id uuid,
  place_id uuid,
  content_key text,
  collected_at timestamptz
)
language sql
security definer
set search_path = ''
as $function$
  select
    ch.event_id,
    e.name as event_name,
    ch.content_id,
    c.content_key as card,
    ch.seichi_id,
    ch.event_content_id,
    ch.place_id,
    c.content_key,
    ch.collected_at
  from public.collection_history ch
  join public.events e
    on e.id = ch.event_id
  join public.contents c
    on c.id = ch.content_id
  where ch.user_id = auth.uid()
  order by ch.collected_at desc;
$function$;

revoke execute on function public.get_my_collection_history() from public, anon;
grant execute on function public.get_my_collection_history() to authenticated;

-- Deliberately NOT removed in this rollout:
--   public.seichi
--   collection_history.seichi_id
--   contents.metadata.legacy_seichi_id
--
-- They are compatibility data for already-installed builds. New Flutter code
-- does not use them and converges device caches to event_contents.id.
