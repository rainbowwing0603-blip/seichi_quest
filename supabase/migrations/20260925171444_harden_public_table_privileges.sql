-- Remove privileges that the mobile client does not require.
-- Row access continues to be controlled by the existing RLS policies.
-- SELECT / INSERT / UPDATE / DELETE privileges are intentionally unchanged.

revoke truncate, references, trigger on table
  public.achievements,
  public.announcement_reads,
  public.announcements,
  public.collection_history,
  public.event_achievements,
  public.events,
  public.profiles,
  public.user_event_favorites,
  public.user_event_participations,
  public.user_event_preferences
from anon, authenticated;
