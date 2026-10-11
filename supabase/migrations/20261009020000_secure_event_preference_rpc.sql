-- Reconstructed from the deployed production database on 2026-10-10.
-- The selected event is changed through a serialized, validated RPC.

CREATE OR REPLACE FUNCTION public.set_current_event_preference(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '認証が必要です.' USING ERRCODE = '28000';
  END IF;

  -- Serialize this user's event-state mutations to avoid preference/leave races.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  IF p_event_id IS NULL THEN
    RAISE EXCEPTION 'event_idは必須です.' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.events e
    WHERE e.id = p_event_id
      AND e.is_active = true
  ) THEN
    RAISE EXCEPTION '有効なイベントが見つかりません.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.user_event_preferences (
    user_id,
    current_event_id,
    updated_at
  )
  VALUES (
    v_user_id,
    p_event_id,
    now()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    current_event_id = EXCLUDED.current_event_id,
    updated_at = now();
END;
$function$;
REVOKE ALL ON FUNCTION public.set_current_event_preference(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_current_event_preference(uuid) TO authenticated;

DROP POLICY IF EXISTS user_event_preferences_insert_own ON public.user_event_preferences;
DROP POLICY IF EXISTS user_event_preferences_update_own ON public.user_event_preferences;
DROP POLICY IF EXISTS user_event_preferences_delete_own ON public.user_event_preferences;
-- Remove direct client writes, including historical column-level grants.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_preferences FROM anon, authenticated;
REVOKE INSERT (user_id, current_event_id, updated_at) ON TABLE public.user_event_preferences FROM anon, authenticated;
REVOKE UPDATE (user_id, current_event_id, updated_at) ON TABLE public.user_event_preferences FROM anon, authenticated;
