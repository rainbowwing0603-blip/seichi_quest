-- collection series master data; curated master data only.
INSERT INTO public.collection_series
SELECT * FROM jsonb_populate_recordset(NULL::public.collection_series, '[{"id":"9299c098-8829-409b-b695-a8a778eab466","code":"roadside-stations-japan","name":"全国 道の駅","category":"roadside_station","metadata":{"progress_scope":"geo_regions","visit_identity":"place"},"is_active":true,"created_at":"2026-09-25T03:55:00.87284+00:00","updated_at":"2026-09-25T03:55:00.87284+00:00","description":"全国の道の駅を一つの訪問実績として集計し、都道府県・地方・全国の進捗へ共通反映するシリーズ"}]'::jsonb)
ON CONFLICT DO NOTHING;
