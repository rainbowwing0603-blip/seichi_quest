-- ============================================================
-- profiles の authenticated 権限を補完
-- ============================================================

grant select, insert, update
on table public.profiles
to authenticated;
