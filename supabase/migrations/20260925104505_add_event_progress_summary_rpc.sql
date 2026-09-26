
create or replace function public.get_event_progress_summary(p_event_id uuid)
returns table(total_count bigint, collected_count bigint)
language sql
stable
set search_path = public
as $$
  select
    count(*)::bigint as total_count,
    count(*) filter (
      where exists (
        select 1
        from public.collection_history ch
        where ch.user_id = (select auth.uid())
          and ch.event_content_id = ec.id
      )
    )::bigint as collected_count
  from public.event_contents ec
  join public.contents c on c.id = ec.content_id and c.is_active
  join public.places p on p.id = ec.place_id and p.is_active
  where ec.event_id = p_event_id
    and ec.is_active;
$$;

revoke all on function public.get_event_progress_summary(uuid) from public;
grant execute on function public.get_event_progress_summary(uuid) to authenticated;
;
