insert into public.content_blocks
  (content_id, block_type, role, title, body, media_path, alt_text, display_order, metadata)
select
  c.id, 'text', 'reading', '読み札', s.reading, null, null, 10, '{}'::jsonb
from public.contents c
join public.event_contents ec on ec.content_id=c.id and ec.is_active=true
join public.seichi s on s.place_id=ec.place_id and s.card=c.content_key and s.is_active=true
where btrim(coalesce(s.reading,'')) <> ''
and not exists (
  select 1 from public.content_blocks cb
  where cb.content_id=c.id and cb.role='reading' and cb.is_active=true
);

insert into public.content_blocks
  (content_id, block_type, role, title, body, media_path, alt_text, display_order, metadata)
select
  c.id, 'text', 'description', '聖地について', s.description, null, null, 20, '{}'::jsonb
from public.contents c
join public.event_contents ec on ec.content_id=c.id and ec.is_active=true
join public.seichi s on s.place_id=ec.place_id and s.card=c.content_key and s.is_active=true
where btrim(coalesce(s.description,'')) <> ''
and not exists (
  select 1 from public.content_blocks cb
  where cb.content_id=c.id and cb.role='description' and cb.is_active=true
);

insert into public.content_blocks
  (content_id, block_type, role, title, body, media_path, alt_text, display_order, metadata)
select
  c.id, 'image', 'picture_card', '絵札', null, s.card_image_url,
  c.title || 'の絵札', 30, '{}'::jsonb
from public.contents c
join public.event_contents ec on ec.content_id=c.id and ec.is_active=true
join public.seichi s on s.place_id=ec.place_id and s.card=c.content_key and s.is_active=true
where btrim(coalesce(s.card_image_url,'')) <> ''
and not exists (
  select 1 from public.content_blocks cb
  where cb.content_id=c.id and cb.role='picture_card' and cb.is_active=true
);
