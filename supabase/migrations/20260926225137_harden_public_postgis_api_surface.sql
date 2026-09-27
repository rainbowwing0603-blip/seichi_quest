-- Recovered from the production migration history on 2026-09-27.
-- Keep PostGIS metadata readable only where required by the extension itself.
-- The production migration already exists; this file restores Git migration parity.
revoke all on table public.spatial_ref_sys from anon, authenticated;
grant select on table public.spatial_ref_sys to anon, authenticated;
