alter table public.events
  add column if not exists theme_primary_hex text,
  add column if not exists theme_primary_deep_hex text,
  add column if not exists theme_accent_hex text;

comment on column public.events.theme_primary_hex is
  'Optional event brand primary color as #RRGGBB or #AARRGGBB. Null uses app fallback.';

comment on column public.events.theme_primary_deep_hex is
  'Optional event brand deep primary color as #RRGGBB or #AARRGGBB. Null uses app fallback.';

comment on column public.events.theme_accent_hex is
  'Optional event brand accent color as #RRGGBB or #AARRGGBB. Null uses app fallback.';
