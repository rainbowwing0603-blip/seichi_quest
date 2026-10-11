-- Clock only: no collection, content, or reward records are modified.
create or replace function public.story_preview_server_time()
returns timestamptz
language sql volatile security invoker
set search_path = ''
as $$ select pg_catalog.clock_timestamp(); $$;
revoke all on function public.story_preview_server_time() from public, anon;
grant execute on function public.story_preview_server_time() to authenticated;
