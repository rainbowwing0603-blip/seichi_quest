-- ============================================================
-- コレクション画面用の獲得履歴取得RPC
-- ============================================================

create or replace function public.get_my_collection_history()
returns table (
  event_id uuid,
  event_name text,
  content_id uuid,
  card text,
  seichi_id uuid,
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
    ch.collected_at
  from public.collection_history ch
  join public.events e
    on e.id = ch.event_id
  join public.contents c
    on c.id = ch.content_id
  where ch.user_id = auth.uid()
  order by ch.collected_at desc;
$function$;

revoke all
on function public.get_my_collection_history()
from public, anon;

grant execute
on function public.get_my_collection_history()
to authenticated;
