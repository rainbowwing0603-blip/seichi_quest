grant update (
  theme_primary_hex,
  theme_primary_deep_hex,
  theme_accent_hex
)
on table public.events
to authenticated;

drop policy if exists events_admin_update_theme
on public.events;

create policy events_admin_update_theme
on public.events
for update
to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));
