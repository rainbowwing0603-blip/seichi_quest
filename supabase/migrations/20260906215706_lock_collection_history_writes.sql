-- ============================================================
-- collection_history: クライアントからの直接書き込みを禁止
-- ============================================================

-- 読み取りは自分の履歴に限って引き続き許可する。
-- 新規獲得は SECURITY DEFINER の
-- public.record_place_visit_and_collect() 経由に一本化する。

drop policy if exists "collection_history_insert_own"
  on public.collection_history;

drop policy if exists "collection_history_update_own"
  on public.collection_history;

revoke insert, update
on table public.collection_history
from authenticated;

grant select
on table public.collection_history
to authenticated;
