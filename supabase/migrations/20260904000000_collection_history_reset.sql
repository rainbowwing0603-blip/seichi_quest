-- ============================================================
-- イベント単位の獲得履歴リセット
-- ============================================================

create or replace function public.reset_event_collection_history(
  p_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception '認証されたユーザーが必要です。';
  end if;

  delete from public.collection_history
  where user_id = auth.uid()
    and event_id = p_event_id;
end;
$$;

grant execute
on function public.reset_event_collection_history(uuid)
to authenticated;