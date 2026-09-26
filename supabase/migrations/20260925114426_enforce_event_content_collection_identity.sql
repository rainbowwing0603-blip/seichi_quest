alter table public.collection_history alter column event_content_id set not null;
drop index if exists public.collection_history_user_event_content_unique;
alter table public.collection_history add constraint collection_history_user_event_content_unique unique (user_id,event_content_id);;
