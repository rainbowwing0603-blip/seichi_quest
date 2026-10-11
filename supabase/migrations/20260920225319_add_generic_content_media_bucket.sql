-- The admin helper must exist before the policies below are created.
-- Existing deployments also receive this idempotent definition from the
-- later database reconciliation migration.

create schema if not exists private;

create table if not exists private.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table private.admin_users enable row level security;
revoke all on table private.admin_users from public, anon, authenticated;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from private.admin_users au
      where au.user_id = (select auth.uid())
    );
$function$;

revoke all on function private.is_admin() from public, anon, authenticated;
grant execute on function private.is_admin() to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'content-media',
  'content-media',
  true,
  10485760,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "content_media_admin_insert" on storage.objects;
create policy "content_media_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'content-media'
  and (select private.is_admin())
);

drop policy if exists "content_media_admin_update" on storage.objects;
create policy "content_media_admin_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'content-media'
  and (select private.is_admin())
)
with check (
  bucket_id = 'content-media'
  and (select private.is_admin())
);

drop policy if exists "content_media_admin_delete" on storage.objects;
create policy "content_media_admin_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'content-media'
  and (select private.is_admin())
);

drop policy if exists "content_media_admin_select" on storage.objects;
create policy "content_media_admin_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'content-media'
  and (select private.is_admin())
);
