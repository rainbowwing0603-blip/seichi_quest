-- Keep current-event preference ownership and timestamps under database control.

CREATE OR REPLACE FUNCTION public.set_current_event_preference(p_event_id uuid)
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

REVOKE ALL ON FUNCTION public.set_current_event_preference(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_current_event_preference(uuid) TO authenticated;

-- Preference rows are read directly by Flutter; writes go through the validated RPC.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_preferences FROM anon, authenticated;
