-- ============================================================
-- イベント札画像用 Storage bucket
-- ============================================================

insert into storage.buckets (
  id,
  name,
  public
)
values (
  'event-card-images',
  'event-card-images',
  true
)
on conflict (id) do update set
  public = excluded.public;


-- ============================================================
-- 公開読み取り
-- ============================================================

drop policy if exists
  "event_card_images_public_read"
on storage.objects;

create policy
  "event_card_images_public_read"
on storage.objects
for select
to public
using (
  bucket_id = 'event-card-images'
);

-- ============================================================
-- クライアントからの書き込みは禁止
-- ============================================================
-- INSERT / UPDATE / DELETE policy は作成しない。
-- 画像アップロードは管理側からのみ行う。