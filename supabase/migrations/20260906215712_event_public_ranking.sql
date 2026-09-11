-- ============================================================
-- イベント別 公開ランキング
-- ============================================================
-- 現在選択中のイベントだけを対象に、
-- event_content_id 単位で獲得数を集計する。
-- user_id は公開しない。

create or replace function public.get_public_ranking(
  p_event_id uuid,
  p_limit integer default 50
)
returns table (
  rank bigint,
  display_name text,
  collected_count bigint,
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
    count(ch.event_content_id) as collected_count,
    (auth.uid() = p.id) as is_me
  from public.profiles as p
  left join public.collection_history as ch
    on ch.user_id = p.id
   and ch.event_id = p_event_id
   and ch.event_content_id is not null
  where p.is_active = true
    and p.display_name is not null
    and btrim(p.display_name) <> ''
  group by
    p.id,
    p.display_name
  order by
    collected_count desc,
    min(ch.collected_at) asc,
    p.display_name asc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

revoke all
  on function public.get_public_ranking(uuid, integer)
  from public;

grant execute
  on function public.get_public_ranking(uuid, integer)
  to anon, authenticated;

comment on function public.get_public_ranking(uuid, integer) is
  '指定イベントについて、表示名を設定したアクティブユーザーのコンテンツ獲得数ランキングを取得する。user_idは公開せず、本人判定のみis_meで返す。';
