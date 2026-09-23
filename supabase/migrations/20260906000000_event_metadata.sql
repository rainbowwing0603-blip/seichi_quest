-- 聖地クエスト
-- イベントの表示情報・開催期間を管理するための基盤。
--
-- 既存の event_system は変更せず、
-- イベントメタデータを後付けで拡張する。

alter table public.events
  add column if not exists icon_url text;

alter table public.events
  add column if not exists cover_image_url text;

alter table public.events
  add column if not exists start_at timestamptz;

alter table public.events
  add column if not exists end_at timestamptz;

alter table public.events
  add column if not exists updated_at timestamptz
  not null default now();

comment on column public.events.icon_url is
  'イベント一覧などで表示するアイコン画像URL。';

comment on column public.events.cover_image_url is
  'イベント詳細などで表示するカバー画像URL。';

comment on column public.events.start_at is
  'イベント開催開始日時。NULLの場合は期間指定なし。';

comment on column public.events.end_at is
  'イベント開催終了日時。NULLの場合は期間指定なし。';

comment on column public.events.updated_at is
  'イベント情報の最終更新日時。';

create or replace function public.set_events_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists events_set_updated_at
  on public.events;

create trigger events_set_updated_at
before update on public.events
for each row
execute function public.set_events_updated_at();