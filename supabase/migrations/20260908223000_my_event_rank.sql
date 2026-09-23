-- ============================================================
-- 現在ユーザーのイベント別ランキング順位
-- ============================================================

create or replace function public.get_my_event_rank(
  p_event_id uuid
)
returns table (
  rank bigint,
  collected_count bigint
)
language sql
security definer
set search_path = ''
as $$
  with ranked as (
    select
      p.id as user_id,
      row_number() over (
        order by
          count(ch.event_content_id) desc,
          min(ch.collected_at) asc,
          p.display_name asc
      ) as rank,
      count(ch.event_content_id) as collected_count
    from public.profiles as p
    join public.collection_history as ch
      on ch.user_id = p.id
     and ch.event_id = p_event_id
     and ch.event_content_id is not null
    where p.is_active = true
      and p.display_name is not null
      and btrim(p.display_name) <> ''
    group by
      p.id,
      p.display_name
  )
  select
    ranked.rank,
    ranked.collected_count
  from ranked
  where ranked.user_id = auth.uid();
$$;

comment on function public.get_my_event_rank(uuid) is
  '指定イベントにおける現在ユーザーの順位と獲得数を返す。表示名未設定または獲得0件の場合は0行を返す。';

revoke all
on function public.get_my_event_rank(uuid)
from public;

grant execute
on function public.get_my_event_rank(uuid)
to authenticated;