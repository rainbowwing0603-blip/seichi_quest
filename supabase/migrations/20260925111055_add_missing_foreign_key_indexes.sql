create index if not exists announcement_reads_announcement_idx on public.announcement_reads (announcement_id);
create index if not exists collection_history_seichi_idx on public.collection_history (seichi_id) where seichi_id is not null;
create index if not exists event_achievements_achievement_idx on public.event_achievements (achievement_id);
create index if not exists event_collection_resets_event_idx on public.event_collection_resets (event_id);
create index if not exists user_event_preferences_current_event_idx on public.user_event_preferences (current_event_id) where current_event_id is not null;;
