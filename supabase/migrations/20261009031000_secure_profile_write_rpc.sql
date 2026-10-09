-- Keep profile ownership and server-managed columns out of direct client writes.

CREATE OR REPLACE FUNCTION public.save_my_profile(
  p_display_name text,
  p_age_group text,
  p_avatar_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_display_name text := nullif(btrim(p_display_name), '');
  v_age_group text := nullif(btrim(p_age_group), '');
  v_avatar_key text := nullif(btrim(p_avatar_key), '');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '認証が必要です.' USING ERRCODE = '28000';
  END IF;

  IF v_display_name IS NOT NULL AND char_length(v_display_name) > 30 THEN
    RAISE EXCEPTION '表示名が長すぎます.' USING ERRCODE = '22023';
  END IF;

  IF v_age_group IS NOT NULL AND char_length(v_age_group) > 32 THEN
    RAISE EXCEPTION '年齢区分が不正です.' USING ERRCODE = '22023';
  END IF;

  IF v_age_group IS NOT NULL AND v_age_group NOT IN (
    '10代以下', '20代', '30代', '40代', '50代', '60代', '70代以上', '回答しない'
  ) THEN
    RAISE EXCEPTION '年齢区分が不正です.' USING ERRCODE = '22023';
  END IF;

  IF v_avatar_key IS NOT NULL AND v_avatar_key NOT IN (
    'adventurer', 'mountain', 'shrine', 'camera', 'train', 'star'
  ) THEN
    RAISE EXCEPTION 'アバター設定が不正です.' USING ERRCODE = '22023';
  END IF;

  IF v_avatar_key IS NOT NULL AND char_length(v_avatar_key) > 64 THEN
    RAISE EXCEPTION 'アバター設定が不正です.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.profiles (id, display_name, age_group, avatar_key, updated_at)
  VALUES (v_user_id, v_display_name, v_age_group, v_avatar_key, now())
  ON CONFLICT (id)
  DO UPDATE SET
    display_name = EXCLUDED.display_name,
    age_group = EXCLUDED.age_group,
    avatar_key = EXCLUDED.avatar_key,
    updated_at = now();
END;
$function$;

REVOKE ALL ON FUNCTION public.save_my_profile(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_profile(text, text, text) TO authenticated;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.profiles FROM anon, authenticated;
