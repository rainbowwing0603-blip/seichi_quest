-- 聖地クエスト
-- collection_history を現在のFlutter実装と整合させる
--
-- 方針:
-- ・既存の履歴データを保持する
-- ・seichi_id を public.seichi.id と同じ UUID に統一
-- ・Flutter が送信する latitude / longitude を保存可能にする
-- ・upsert に必要な UPDATE RLS を追加
-- ・既存のオフライン同期仕様は変更しない

-- ------------------------------------------------------------
-- seichi_id を UUID に統一
-- ------------------------------------------------------------

alter table public.collection_history
  alter column seichi_id type uuid
  using seichi_id::uuid;

-- ------------------------------------------------------------
-- Flutter が送信する位置情報を保存
-- ------------------------------------------------------------

alter table public.collection_history
  add column if not exists latitude double precision;

alter table public.collection_history
  add column if not exists longitude double precision;

-- ------------------------------------------------------------
-- 作成日時
-- ------------------------------------------------------------

alter table public.collection_history
  add column if not exists created_at timestamptz not null default now();

-- ------------------------------------------------------------
-- seichi との参照整合性
-- ------------------------------------------------------------

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'collection_history_seichi_id_fkey'
      and conrelid = 'public.collection_history'::regclass
  ) then
    alter table public.collection_history
      add constraint collection_history_seichi_id_fkey
      foreign key (seichi_id)
      references public.seichi(id)
      on delete restrict;
  end if;
end
$$;

-- ------------------------------------------------------------
-- インデックス
-- ------------------------------------------------------------

create index if not exists collection_history_user_id_idx
  on public.collection_history(user_id);

create index if not exists collection_history_collected_at_idx
  on public.collection_history(collected_at desc);

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.collection_history enable row level security;

-- 自分の履歴だけ参照可能
drop policy if exists "collection_history_select_own"
  on public.collection_history;

create policy "collection_history_select_own"
on public.collection_history
for select
to authenticated
using ((select auth.uid()) = user_id);

-- 自分の履歴だけ追加可能
drop policy if exists "collection_history_insert_own"
  on public.collection_history;

create policy "collection_history_insert_own"
on public.collection_history
for insert
to authenticated
with check ((select auth.uid()) = user_id);

-- upsert の UPDATE 側
drop policy if exists "collection_history_update_own"
  on public.collection_history;

create policy "collection_history_update_own"
on public.collection_history
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
