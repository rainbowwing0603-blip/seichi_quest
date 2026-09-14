-- ============================================================
-- イベント公開集計
--
-- user_event_participations / user_event_favorites は
-- 本人の行だけ参照可能なRLSになっているため、
-- 公開してよい「件数」だけをこのRPC経由で返す。
-- ============================================================

create or replace function public.get_event_social_stats(
  p_event_id uuid
)
returns table (
  participant_count bigint,
  favorite_count bigint,
  is_favorited boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (
      select count(*)
      from public.user_event_participations as participation
      where participation.event_id = p_event_id
        and participation.is_active = true
    ) as participant_count,

    (
      select count(*)
      from public.user_event_favorites as favorite
      where favorite.event_id = p_event_id
    ) as favorite_count,

    exists (
      select 1
      from public.user_event_favorites as favorite
      where favorite.event_id = p_event_id
        and favorite.user_id = auth.uid()
    ) as is_favorited;
$$;

revoke all
on function public.get_event_social_stats(uuid)
from public;

grant execute
on function public.get_event_social_stats(uuid)
to authenticated;

comment on function public.get_event_social_stats(uuid) is
  'イベントの現在参加人数、お気に入り数、自分のお気に入り状態を返す。';