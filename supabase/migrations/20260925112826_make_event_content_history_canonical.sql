alter table public.collection_history drop constraint if exists collection_history_user_event_seichi_unique;
drop index if exists public.collection_history_seichi_idx;

create or replace function public.get_my_collection_history()
returns table(event_id uuid,event_name text,content_id uuid,card text,seichi_id uuid,event_content_id uuid,place_id uuid,content_key text,collected_at timestamptz)
language sql security definer set search_path=''
as $$
  select ch.event_id,e.name,ch.content_id,c.content_key,ch.seichi_id,
         ch.event_content_id,ch.place_id,c.content_key,ch.collected_at
  from public.collection_history ch
  join public.events e on e.id=ch.event_id
  join public.contents c on c.id=ch.content_id
  where ch.user_id=(select auth.uid())
  order by ch.collected_at desc;
$$;
revoke all on function public.get_my_collection_history() from public,anon;
grant execute on function public.get_my_collection_history() to authenticated;;
