-- 聖地クエスト: アプリ内お知らせ基盤
--
-- お知らせ本文は運用側で管理し、アプリ利用者は公開期間中のものだけ参照する。
-- 既読情報は Supabase Auth のユーザー単位で保持する。

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  category text not null default 'general',
  priority integer not null default 0,
  event_id uuid references public.events(id) on delete set null,
  publish_from timestamptz not null default now(),
  publish_until timestamptz,
  show_on_startup boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint announcements_title_not_blank
    check (char_length(btrim(title)) > 0),
  constraint announcements_body_not_blank
    check (char_length(btrim(body)) > 0),
  constraint announcements_category_check
    check (category in (
      'event_start',
      'event_ending',
      'update',
      'maintenance',
      'campaign',
      'general'
    )),
  constraint announcements_publish_window_check
    check (publish_until is null or publish_until > publish_from)
);

create index if not exists announcements_publication_idx
  on public.announcements (
    is_active,
    show_on_startup,
    publish_from desc,
    publish_until
  );

create index if not exists announcements_event_idx
  on public.announcements(event_id)
  where event_id is not null;

create table if not exists public.announcement_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, announcement_id)
);

create index if not exists announcement_reads_user_read_at_idx
  on public.announcement_reads(user_id, read_at desc);

alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;

create policy "announcements_select_published"
on public.announcements
for select
to authenticated
using (
  is_active
  and publish_from <= now()
  and (publish_until is null or now() < publish_until)
);

create policy "announcement_reads_select_own"
on public.announcement_reads
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "announcement_reads_insert_own"
on public.announcement_reads
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "announcement_reads_update_own"
on public.announcement_reads
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select on table public.announcements to authenticated;
grant select, insert, update on table public.announcement_reads to authenticated;

comment on table public.announcements is
  'アプリ内お知らせ。公開期間と起動表示対象を運用側で管理する。';

comment on table public.announcement_reads is
  'Supabase Authユーザー単位のお知らせ既読状態。';
