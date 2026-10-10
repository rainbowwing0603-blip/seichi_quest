-- Add optional gender editing without bypassing the profile RPC's validation.
-- Preserve the existing three-argument RPC for older app versions.

alter table public.profiles
  add column if not exists gender text;

update public.profiles
set age_group = '10代'
where age_group = '10代以下';

alter table public.profiles
  drop constraint if exists profiles_gender_check;

alter table public.profiles
  add constraint profiles_gender_check
  check (gender is null or gender in ('男性', '女性', 'その他', '回答しない'));

create index if not exists idx_profiles_age_gender
  on public.profiles (age_group, gender, id);

create or replace function public.save_my_profile(
  p_display_name text,
  p_age_group text,
  p_avatar_key text,
  p_gender text
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_display_name text := nullif(btrim(p_display_name), '');
  v_age_group text := nullif(btrim(p_age_group), '');
  v_avatar_key text := nullif(btrim(p_avatar_key), '');
  v_gender text := nullif(btrim(p_gender), '');
begin
  if v_user_id is null then
    raise exception '認証が必要です.' using errcode = '28000';
  end if;

  if v_age_group = '10代以下' then
    v_age_group := '10代';
  end if;

  if v_display_name is not null and char_length(v_display_name) > 30 then
    raise exception '表示名が長すぎます.' using errcode = '22023';
  end if;

  if v_age_group is not null and v_age_group not in (
    '10代', '20代', '30代', '40代', '50代', '60代', '70代以上', '回答しない'
  ) then
    raise exception '年齢区分が不正です.' using errcode = '22023';
  end if;

  if v_gender is not null and v_gender not in ('男性', '女性', 'その他', '回答しない') then
    raise exception '性別が不正です.' using errcode = '22023';
  end if;

  if v_avatar_key is not null and v_avatar_key not in (
    'adventurer', 'mountain', 'shrine', 'camera', 'train', 'star'
  ) then
    raise exception 'アバター設定が不正です.' using errcode = '22023';
  end if;

  if v_avatar_key is not null and char_length(v_avatar_key) > 64 then
    raise exception 'アバター設定が不正です.' using errcode = '22023';
  end if;

  insert into public.profiles (id, display_name, age_group, gender, avatar_key, updated_at)
  values (v_user_id, v_display_name, v_age_group, v_gender, v_avatar_key, now())
  on conflict (id)
  do update set
    display_name = excluded.display_name,
    age_group = excluded.age_group,
    gender = excluded.gender,
    avatar_key = excluded.avatar_key,
    updated_at = now();
end;
$function$;

-- Keep the legacy RPC callable by older installed app versions without erasing gender.
create or replace function public.save_my_profile(
  p_display_name text,
  p_age_group text,
  p_avatar_key text
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_gender text;
begin
  if v_user_id is null then
    raise exception '認証が必要です.' using errcode = '28000';
  end if;

  select p.gender
  into v_gender
  from public.profiles p
  where p.id = v_user_id;

  perform public.save_my_profile(
    p_display_name,
    p_age_group,
    p_avatar_key,
    v_gender
  );
end;
$function$;

revoke all on function public.save_my_profile(text, text, text) from public, anon;
grant execute on function public.save_my_profile(text, text, text) to authenticated;

revoke all on function public.save_my_profile(text, text, text, text) from public, anon;
grant execute on function public.save_my_profile(text, text, text, text) to authenticated;

-- Reconstructed from the deployed closed-test database on 2026-10-09.
-- Keep EXECUTE limited to authenticated users, matching the live function ACL.

create or replace function public.get_event_recommendations(p_limit integer default 5)
returns table(
  event_id uuid,
  participant_count bigint,
  demographic_population bigint,
  participation_rate numeric,
  recommendation_basis text
)
language sql
stable
security definer
set search_path = ''
as $function$
with viewer as (
  select p.age_group, p.gender
  from public.profiles p
  where p.id = (select auth.uid())
  limit 1
),
profile_mode as (
  select
    v.age_group,
    v.gender,
    (
      (v.age_group is not null and v.age_group <> '回答しない')
      or v.gender in ('男性', '女性')
    ) as can_personalize
  from viewer v
),
demographic_population as (
  select count(*)::bigint as population
  from public.profiles p
  cross join profile_mode m
  where m.can_personalize
    and (m.age_group is null or m.age_group = '回答しない' or p.age_group = m.age_group)
    and (m.gender is null or m.gender not in ('男性', '女性') or p.gender = m.gender)
),
event_participants as (
  select
    p.event_id,
    count(*)::bigint as participant_count,
    count(*) filter (
      where m.can_personalize
        and (m.age_group is null or m.age_group = '回答しない' or pr.age_group = m.age_group)
        and (m.gender is null or m.gender not in ('男性', '女性') or pr.gender = m.gender)
    )::bigint as demographic_participant_count
  from public.user_event_participations p
  join public.events e on e.id = p.event_id
  left join public.profiles pr on pr.id = p.user_id
  cross join profile_mode m
  where e.is_active = true
    and (e.end_at is null or e.end_at >= now())
  group by p.event_id
),
personalized as (
  select
    ep.event_id,
    ep.demographic_participant_count as participant_count,
    dp.population as demographic_population,
    round(
      ep.demographic_participant_count::numeric
      / nullif(dp.population, 0) * 100,
      1
    ) as participation_rate,
    case
      when m.age_group is not null and m.age_group <> '回答しない' and m.gender in ('男性', '女性')
        then m.age_group || '・' || m.gender
      when m.age_group is not null and m.age_group <> '回答しない' then m.age_group
      else m.gender
    end as recommendation_basis
  from event_participants ep
  cross join demographic_population dp
  cross join profile_mode m
  where m.can_personalize
    and dp.population >= 5
    and ep.demographic_participant_count > 0
),
overall as (
  select
    ep.event_id,
    ep.participant_count,
    0::bigint as demographic_population,
    null::numeric as participation_rate,
    'みんなに人気'::text as recommendation_basis
  from event_participants ep
)
select
  r.event_id,
  r.participant_count,
  r.demographic_population,
  r.participation_rate,
  r.recommendation_basis
from (
  select * from personalized
  union all
  select *
  from overall
  where not exists (select 1 from personalized)
) r
where r.event_id not in (
  select p.event_id
  from public.user_event_participations p
  where p.user_id = (select auth.uid())
)
order by
  case when r.recommendation_basis = 'みんなに人気' then 1 else 0 end,
  r.participation_rate desc nulls last,
  r.participant_count desc,
  r.event_id
limit greatest(1, least(coalesce(p_limit, 5), 10));
$function$;

revoke all on function public.get_event_recommendations(integer) from public, anon, authenticated;
grant execute on function public.get_event_recommendations(integer) to authenticated;
