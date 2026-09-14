-- ============================================================
-- events に都道府県情報を追加
-- ============================================================

alter table public.events
  add column if not exists prefecture text;

comment on column public.events.prefecture is
  'クエストの主な開催都道府県。';

-- 既存の上毛かるたクエストを群馬県として登録
update public.events
set prefecture = '群馬県'
where slug = 'jomo-karuta-gunma'
  and (
    prefecture is null
    or btrim(prefecture) = ''
  );