
create or replace function public.get_event_contents_page(
  p_event_id uuid,
  p_offset integer default 0,
  p_limit integer default 100
)
returns table(
  event_content_id uuid,
  content_id uuid,
  place_id uuid,
  content_key text,
  title text,
  description text,
  icon text,
  image_url text,
  latitude double precision,
  longitude double precision,
  stamp_radius_meters integer,
  prefecture text,
  city text,
  display_order integer,
  is_collected boolean
)
language sql
stable
set search_path = public
as $$
select ec.id,c.id,p.id,c.content_key,c.title,c.description,p.icon,
       coalesce(c.image_url,p.image_url),p.latitude,p.longitude,p.radius_meters,
       p.prefecture,p.city,ec.display_order,
       exists(select 1 from public.collection_history ch
              where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id)
from public.event_contents ec
join public.contents c on c.id=ec.content_id and c.is_active
join public.places p on p.id=ec.place_id and p.is_active
where ec.event_id=p_event_id and ec.is_active
order by ec.display_order,c.title,ec.id
offset greatest(0,coalesce(p_offset,0))
limit greatest(1,least(coalesce(p_limit,100),200));
$$;
revoke all on function public.get_event_contents_page(uuid,integer,integer) from public;
grant execute on function public.get_event_contents_page(uuid,integer,integer) to authenticated;
;
