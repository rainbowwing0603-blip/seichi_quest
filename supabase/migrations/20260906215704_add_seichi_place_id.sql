-- ============================================================
-- seichi に物理地点 place_id を正式に紐付ける
-- ============================================================

alter table public.seichi
  add column if not exists place_id uuid
    references public.places(id)
    on delete restrict;


-- ------------------------------------------------------------
-- 既存の seichi を、同一座標の places に紐付ける
-- ------------------------------------------------------------

update public.seichi s
set place_id = p.id
from public.places p
where p.latitude = s.latitude
  and p.longitude = s.longitude
  and s.place_id is null;


-- ------------------------------------------------------------
-- 全 seichi が物理地点に紐付いていることを検証
-- 1件でも未紐付けなら migration を失敗させる
-- ------------------------------------------------------------

do $$
declare
  v_unmapped_count integer;
begin
  select count(*)
    into v_unmapped_count
  from public.seichi
  where place_id is null;

  if v_unmapped_count > 0 then
    raise exception
      'seichi.place_id mapping failed: % seichi rows are unmapped',
      v_unmapped_count;
  end if;
end
$$;


-- ------------------------------------------------------------
-- 紐付け完了後に NOT NULL 化
-- ------------------------------------------------------------

alter table public.seichi
  alter column place_id set not null;


-- ------------------------------------------------------------
-- 物理地点から seichi を検索できるようにする
-- ------------------------------------------------------------

create index if not exists seichi_place_idx
  on public.seichi (place_id);