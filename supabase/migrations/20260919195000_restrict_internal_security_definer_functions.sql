-- Internal trigger functions must not be callable directly
-- by application client roles.

revoke execute
on function public.handle_new_user()
from public, anon, authenticated;

revoke execute
on function public.rls_auto_enable()
from public, anon, authenticated;