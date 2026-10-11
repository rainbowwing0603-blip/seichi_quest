-- Reconstructed from the deployed closed-test database on 2026-10-09.
-- This helper returns server time only and is executable by authenticated users.

create or replace function public.story_preview_server_time()
returns timestamp with time zone
language sql
set search_path = ''
as $function$
  select pg_catalog.clock_timestamp();
$function$;

revoke all on function public.story_preview_server_time() from public, anon, authenticated;
grant execute on function public.story_preview_server_time() to authenticated;
