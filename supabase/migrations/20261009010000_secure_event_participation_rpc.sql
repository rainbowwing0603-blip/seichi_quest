-- Reconstructed from the deployed production database on 2026-10-10.
-- Event membership writes go through validated SECURITY DEFINER RPCs.

CREATE OR REPLACE FUNCTION public.ensure_event_participation(p_event_id uuid)
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

  INSERT INTO public.user_event_participations AS participation (
    user_id,
    event_id,
    joined_at,
    is_active,
    left_at,
    updated_at
  )
  VALUES (
    v_user_id,
    p_event_id,
    now(),
    true,
    NULL,
    now()
  )
  ON CONFLICT (user_id, event_id)
  DO UPDATE SET
    is_active = true,
    left_at = NULL,
    updated_at = now()
  WHERE participation.is_active IS DISTINCT FROM true;
END;
$function$;
CREATE OR REPLACE FUNCTION public.leave_event_participation(p_event_id uuid)
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

  IF EXISTS (
    SELECT 1
    FROM public.user_event_preferences pref
    WHERE pref.user_id = v_user_id
      AND pref.current_event_id = p_event_id
  ) THEN
    RAISE EXCEPTION '現在選択中のイベントは参加解除できません.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.user_event_participations p
  SET is_active = false,
      left_at = now(),
      updated_at = now()
  WHERE p.user_id = v_user_id
    AND p.event_id = p_event_id
    AND p.is_active = true;
END;
$function$;
REVOKE ALL ON FUNCTION public.ensure_event_participation(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_event_participation(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.leave_event_participation(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.leave_event_participation(uuid) TO authenticated;

DROP POLICY IF EXISTS user_event_participations_insert_own ON public.user_event_participations;
DROP POLICY IF EXISTS user_event_participations_update_own ON public.user_event_participations;
DROP POLICY IF EXISTS user_event_participations_delete_own ON public.user_event_participations;
-- Remove direct client writes, including historical column-level grants.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_participations FROM anon, authenticated;
REVOKE INSERT (user_id, event_id, joined_at, is_active, left_at, updated_at) ON TABLE public.user_event_participations FROM anon, authenticated;
REVOKE UPDATE (user_id, event_id, joined_at, is_active, left_at, updated_at) ON TABLE public.user_event_participations FROM anon, authenticated;
