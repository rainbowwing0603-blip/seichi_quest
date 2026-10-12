-- Export the active content rows that still need original stamp art.
-- Run in Supabase SQL Editor and export the result as CSV.
-- Existing image_url rows are intentionally excluded; event-content rows sharing
-- one content_id produce one asset because the filename is content_id-based.
select distinct
  e.slug as event_slug,
  c.id as content_id,
  c.title,
  c.content_key,
  c.type
from public.events e
join public.event_contents ec on ec.event_id = e.id
join public.contents c on c.id = ec.content_id
where e.is_active = true
  and ec.is_active = true
  and c.is_active = true
  and c.image_url is null
  and e.slug <> 'テストクエスト'
order by e.slug, c.content_key nulls last, c.title;
