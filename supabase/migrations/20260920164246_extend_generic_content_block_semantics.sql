alter table public.content_blocks
  add column if not exists role text not null default 'default',
  add column if not exists alt_text text,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table public.content_blocks
  drop constraint if exists content_blocks_role_format_check;

alter table public.content_blocks
  add constraint content_blocks_role_format_check
  check (role ~ '^[a-z][a-z0-9_]{0,63}$');

comment on column public.content_blocks.role is
  '汎用表示ブロックの意味上の役割。例: default, hero, picture_card, reading_card, reading, description, product, store, official。UI分岐ではなく意味付けに使用する。';

comment on column public.content_blocks.alt_text is
  '画像などの代替テキスト。アクセシビリティ用途。';

comment on column public.content_blocks.metadata is
  'ブロック固有の将来拡張情報。共通カラム化するほど安定していない属性のみ格納する。';
