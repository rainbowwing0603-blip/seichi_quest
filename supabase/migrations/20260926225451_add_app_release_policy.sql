-- Recovered from the production schema/migration history on 2026-09-27.
-- The production migration already exists. Keep this file aligned with the
-- deployed table shape so fresh environments can reproduce it.

create table if not exists public.app_release_policies (
  platform text primary key check (platform = any (array['android'::text, 'ios'::text])),
  latest_build integer not null check (latest_build > 0),
  minimum_build integer not null,
  latest_version text not null,
  store_url text not null,
  update_message text,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.app_release_policies enable row level security;

revoke all on table public.app_release_policies from anon, authenticated;
grant select on table public.app_release_policies to anon, authenticated;

drop policy if exists app_release_policies_public_read
  on public.app_release_policies;

create policy app_release_policies_public_read
on public.app_release_policies
for select
to anon, authenticated
using (is_active = true);
