-- ============================================================
-- seichi に札画像URLを追加
-- ============================================================

alter table public.seichi
  add column if not exists card_image_url text;

comment on column public.seichi.card_image_url is
  '札画像のURL。未設定時は既存のアイコン表示へフォールバックする。';