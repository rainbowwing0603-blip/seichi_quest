-- ============================================================
-- 公開ランキング v2
-- ・プロフィールアバターを返す
-- ・イベント参加者総数を返す
-- ============================================================

drop function if exists public.get_public_ranking(uuid, integer);

create function public.get_public_ranking(
  p_event_id uuid,
  p_limit integer default 50
)
returns table (
  rank bigint,
  display_name text,
  avatar_key text,
  collected_count bigint,
  participant_count bigint,
  is_me boolean
)
language sql
security definer
set search_path = ''
as $$
  select
    row_number() over (
      order by
        count(ch.event_content_id) desc,
        min(ch.collected_at) asc,
        p.display_name asc
    ) as rank,
    p.display_name,
    p.avatar_key,
    count(ch.event_content_id) as collected_count,
    count(*) over () as participant_count,
    (auth.uid() = p.id) as is_me
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
    p.display_name,
    p.avatar_key
  order by
    collected_count desc,
    min(ch.collected_at) asc,
    p.display_name asc
  limit greatest(
    1,
    least(coalesce(p_limit, 50), 100)
  );
$$;

revoke all
  on function public.get_public_ranking(uuid, integer)
  from public;

grant execute
  on function public.get_public_ranking(uuid, integer)
  to anon, authenticated;

comment on function public.get_public_ranking(uuid, integer) is
  '指定イベントで1件以上獲得し、表示名を設定したアクティブユーザーのランキングを、アバター・参加者総数・本人判定付きで取得する。user_idは公開しない。';