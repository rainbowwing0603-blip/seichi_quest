-- 聖地クエスト オンライン機能用スキーマ
-- 既存の seichi テーブルは変更しません。

create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_stamps (
  user_id uuid not null references auth.users(id) on delete cascade,
  seichi_id uuid not null references public.seichi(id) on delete cascade,
  collected_at timestamptz not null default now(),
  primary key (user_id, seichi_id)
);

create table if not exists public.user_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  collected_count integer not null default 0,
  quest_count integer not null default 0,
  achievement_count integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.achievements (
  id text primary key,
  title text not null,
  description text not null default '',
  required_count integer not null default 0,
  icon text not null default '🏆',
  is_active boolean not null default true
);

create table if not exists public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null references public.achievements(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create table if not exists public.quests (
  id text primary key,
  title text not null,
  description text not null default '',
  target_count integer not null default 1,
  reward_points integer not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz
);

create table if not exists public.user_quests (
  user_id uuid not null references auth.users(id) on delete cascade,
  quest_id text not null references public.quests(id) on delete cascade,
  progress integer not null default 0,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, quest_id)
);

create table if not exists public.leaderboard_scores (
  user_id uuid primary key references auth.users(id) on delete cascade,
  score integer not null default 0,
  collected_count integer not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_stamps_seichi on public.user_stamps(seichi_id);
create index if not exists idx_user_stamps_collected_at on public.user_stamps(collected_at desc);
create index if not exists idx_user_quests_active on public.user_quests(quest_id, completed_at);
create index if not exists idx_leaderboard_score on public.leaderboard_scores(score desc);

alter table public.user_profiles enable row level security;
alter table public.user_stamps enable row level security;
alter table public.user_stats enable row level security;
alter table public.user_achievements enable row level security;
alter table public.user_quests enable row level security;
alter table public.leaderboard_scores enable row level security;

-- 自分のデータだけ読み書き可能
create policy "profiles own rows" on public.user_profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "stamps own rows" on public.user_stamps
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "stats own rows" on public.user_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "achievements own rows" on public.user_achievements
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "quests own rows" on public.user_quests
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ランキングは全ユーザーのスコアを閲覧可能。更新は本人のみ。
create policy "leaderboard public read" on public.leaderboard_scores
  for select using (true);

create policy "leaderboard own write" on public.leaderboard_scores
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 初期実績
insert into public.achievements (id, title, description, required_count, icon)
values
  ('first_stamp', 'はじめの一歩', '最初の聖地を獲得する', 1, '🌱'),
  ('ten_stamps', '聖地ハンター', '10個の聖地を獲得する', 10, '🗺️'),
  ('twenty_five_stamps', '群馬探訪者', '25個の聖地を獲得する', 25, '🚗'),
  ('all_stamps', '完全制覇', '44個すべての聖地を獲得する', 44, '🏆')
on conflict (id) do nothing;

insert into public.quests (id, title, description, target_count, reward_points)
values
  ('first_visit', '最初の聖地へ', '聖地を1か所訪れる', 1, 10),
  ('five_visits', '五か所巡り', '聖地を5か所訪れる', 5, 50),
  ('ten_visits', '十か所巡り', '聖地を10か所訪れる', 10, 100)
on conflict (id) do nothing;
