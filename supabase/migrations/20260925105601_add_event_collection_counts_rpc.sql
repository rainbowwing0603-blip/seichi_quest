
create or replace function public.get_event_collection_counts(p_event_id uuid)
returns table(total_count bigint, collected_count bigint, uncollected_count bigint)
language sql stable set search_path=public as $$
with items as (
 select ec.id,
   exists(select 1 from public.collection_history ch
          where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id) as collected
 from public.event_contents ec
 join public.contents c on c.id=ec.content_id and c.is_active
 join public.places p on p.id=ec.place_id and p.is_active
 where ec.event_id=p_event_id and ec.is_active
)
select count(*)::bigint,
       count(*) filter(where collected)::bigint,
       count(*) filter(where not collected)::bigint
from items;
$$;
revoke all on function public.get_event_collection_counts(uuid) from public;
grant execute on function public.get_event_collection_counts(uuid) to authenticated;
;
