-- 聖地クエスト
-- 公開ランキング取得用RPC
--
-- collection_history は RLS により本人の履歴しか直接SELECTできない。
-- そのため SECURITY DEFINER 関数を介してランキングに必要な
-- 最小限の情報だけを公開する。
--
-- 公開する情報:
-- ・順位
-- ・表示名
-- ・獲得聖地数
--
-- user_id は公開しない。

create or replace function public.get_public_ranking(
  p_limit integer default 50
)
returns table (
  rank bigint,
  display_name text,
  collected_count bigint
)
language sql
security definer
set search_path = public
as $$
  select
    row_number() over (
      order by
        count(ch.seichi_id) desc,
        min(ch.collected_at) asc,
        p.display_name asc
    ) as rank,
    p.display_name,
    count(ch.seichi_id) as collected_count
  from public.profiles p
  left join public.collection_history ch
    on ch.user_id = p.id
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
  on function public.get_public_ranking(integer)
  from public;

grant execute
  on function public.get_public_ranking(integer)
  to anon, authenticated;

comment on function public.get_public_ranking(integer) is
  '表示名を設定したアクティブユーザーの聖地獲得数ランキングを取得する。user_idは公開しない。';