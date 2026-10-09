-- Keep event participation timestamps and ownership under database control.
-- The client may ensure that its own participation is active, but cannot write
-- joined_at, user_id, or other participation state directly.

CREATE OR REPLACE FUNCTION public.ensure_event_participation(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '認証が必要です.' USING ERRCODE = '28000';
  END IF;

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

  INSERT INTO public.user_event_participations (
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
  WHERE public.user_event_participations.is_active IS DISTINCT FROM true;
END;
$function$;

REVOKE ALL ON FUNCTION public.ensure_event_participation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_event_participation(uuid) TO authenticated;

-- The app now uses the validated RPC rather than client-supplied timestamps.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_participations FROM anon, authenticated;
