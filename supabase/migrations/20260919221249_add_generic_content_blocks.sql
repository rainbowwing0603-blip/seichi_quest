create table public.content_blocks (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.contents(id) on delete cascade,
  block_type text not null,
  title text,
  body text,
  media_path text,
  link_url text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint content_blocks_type_check
    check (block_type in ('text', 'image', 'link')),
  constraint content_blocks_display_order_check
    check (display_order >= 0),
  constraint content_blocks_payload_check
    check (
      (block_type = 'text' and body is not null and btrim(body) <> '')
      or
      (block_type = 'image' and media_path is not null and btrim(media_path) <> '')
      or
      (block_type = 'link' and link_url is not null and btrim(link_url) <> '')
    )
);

comment on table public.content_blocks is
  'コンテンツ詳細画面を構成する汎用表示ブロック。かるた・店舗・商品・コラボ等を共通構造で扱う。';

comment on column public.content_blocks.block_type is
  '表示種別。text / image / link。';

comment on column public.content_blocks.media_path is
  '画像等のStorage上の参照パス。現時点ではimageブロックで使用する。';

create index content_blocks_content_order_idx
  on public.content_blocks (content_id, display_order, id)
  where is_active = true;

alter table public.content_blocks enable row level security;

revoke all on table public.content_blocks from public, anon, authenticated;

grant select on table public.content_blocks to authenticated;
grant insert, update, delete on table public.content_blocks to authenticated;

create policy content_blocks_select_active
on public.content_blocks
for select
to authenticated
using (is_active = true);

create policy content_blocks_admin_insert
on public.content_blocks
for insert
to authenticated
with check ((select private.is_admin()));

create policy content_blocks_admin_update
on public.content_blocks
for update
to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy content_blocks_admin_delete
on public.content_blocks
for delete
to authenticated
using ((select private.is_admin()));
