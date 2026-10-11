-- Admin-only mutations require a permanent (non-anonymous) Supabase Auth user.
DROP POLICY IF EXISTS content_blocks_admin_delete ON public.content_blocks;
CREATE POLICY content_blocks_admin_delete ON public.content_blocks FOR DELETE TO authenticated USING ((SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
DROP POLICY IF EXISTS content_blocks_admin_insert ON public.content_blocks;
CREATE POLICY content_blocks_admin_insert ON public.content_blocks FOR INSERT TO authenticated WITH CHECK ((SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
DROP POLICY IF EXISTS content_blocks_admin_update ON public.content_blocks;
CREATE POLICY content_blocks_admin_update ON public.content_blocks FOR UPDATE TO authenticated USING ((SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin())) WITH CHECK ((SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
DROP POLICY IF EXISTS events_admin_update_theme ON public.events;
CREATE POLICY events_admin_update_theme ON public.events FOR UPDATE TO authenticated USING ((SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin())) WITH CHECK ((SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
DROP POLICY IF EXISTS content_media_admin_delete ON storage.objects;
CREATE POLICY content_media_admin_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id='content-media' AND (SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
DROP POLICY IF EXISTS content_media_admin_insert ON storage.objects;
CREATE POLICY content_media_admin_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='content-media' AND (SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
DROP POLICY IF EXISTS content_media_admin_select ON storage.objects;
CREATE POLICY content_media_admin_select ON storage.objects FOR SELECT TO authenticated USING (bucket_id='content-media' AND (SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
DROP POLICY IF EXISTS content_media_admin_update ON storage.objects;
CREATE POLICY content_media_admin_update ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='content-media' AND (SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin())) WITH CHECK (bucket_id='content-media' AND (SELECT (auth.jwt()->>'is_anonymous')::boolean) IS FALSE AND (SELECT private.is_admin()));
