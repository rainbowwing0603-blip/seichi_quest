alter table public.collection_history drop constraint if exists collection_history_seichi_id_fkey;
comment on column public.collection_history.seichi_id is 'Legacy compatibility only. New collection identity is event_content_id; generic events may leave this NULL.';;
