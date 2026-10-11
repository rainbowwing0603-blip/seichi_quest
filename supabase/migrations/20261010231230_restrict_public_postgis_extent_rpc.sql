-- Restrict direct PostgREST execution of PostGIS extent helpers where supported.
-- These extension-owned functions may reject ACL changes on managed Supabase; verify
-- the effective grants with has_function_privilege after deployment.
do $migration$
begin
  if to_regprocedure('public.st_estimatedextent(text,text)') is not null then
    begin
      execute 'revoke execute on function public.st_estimatedextent(text,text) from public, anon, authenticated';
    exception when insufficient_privilege then
      raise notice 'Managed extension owner prevents changing st_estimatedextent(text,text) ACL';
    end;
  end if;
  if to_regprocedure('public.st_estimatedextent(text,text,text)') is not null then
    begin
      execute 'revoke execute on function public.st_estimatedextent(text,text,text) from public, anon, authenticated';
    exception when insufficient_privilege then
      raise notice 'Managed extension owner prevents changing st_estimatedextent(text,text,text) ACL';
    end;
  end if;
  if to_regprocedure('public.st_estimatedextent(text,text,text,boolean)') is not null then
    begin
      execute 'revoke execute on function public.st_estimatedextent(text,text,text,boolean) from public, anon, authenticated';
    exception when insufficient_privilege then
      raise notice 'Managed extension owner prevents changing st_estimatedextent(text,text,text,boolean) ACL';
    end;
  end if;
end
$migration$;
