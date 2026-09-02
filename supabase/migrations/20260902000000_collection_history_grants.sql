-- Grant required permissions on collection_history to authenticated users
grant select, insert, update
on table public.collection_history
to authenticated;
