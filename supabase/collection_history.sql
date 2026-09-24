-- 聖地クエスト: 獲得履歴（QuestItem移行期間の参照スキーマ）
--
-- 実DBの変更は supabase/migrations を正とする。
-- 新アプリの正規IDは event_contents.id。
-- seichi_id は旧アプリ互換のため一時的に残しており、新コードからは参照しない。

create table if not exists public.collection_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  -- 旧アプリ互換。新規コードの識別子として使用しない。
  seichi_id uuid references public.seichi(id) on delete restrict,

  event_id uuid not null references public.events(id) on delete restrict,
  content_id uuid references public.contents(id) on delete restrict,
  event_content_id uuid references public.event_contents(id) on delete restrict,
  place_id uuid references public.places(id) on delete restrict,
  place_visit_id uuid references public.place_visits(id) on delete restrict,
  collected_at timestamptz not null default now(),
  synced_at timestamptz,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

alter table public.collection_history enable row level security;

create index if not exists collection_history_user_id_idx
  on public.collection_history(user_id);

create index if not exists collection_history_event_content_idx
  on public.collection_history(event_content_id);

create unique index if not exists collection_history_user_event_content_unique
  on public.collection_history(user_id, event_content_id);

create index if not exists collection_history_collected_at_idx
  on public.collection_history(collected_at desc);
