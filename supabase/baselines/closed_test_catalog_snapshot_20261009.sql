-- Catalog-derived snapshot from the live closed-test Supabase database.
-- Captured: 2026-10-09. Source project: wxlvhpmolrtcwryaazfb.
-- NOT a drop-in executable migration: review dependencies, extension schema, ownership, role grants,
-- sequences, function grants, policies, and ordering before replaying into production.
-- This file excludes extension-owned public.spatial_ref_sys and all user data.
-- Never apply this snapshot to production without a reviewed deployment plan.

-- Extensions present in source:
-- http 1.6 (schema extensions)
-- pg_stat_statements 1.11 (schema extensions)
-- pgcrypto 1.3 (schema extensions)
-- plpgsql 1.0 (schema pg_catalog)
-- postgis 3.3.7 (schema public)
-- supabase_vault 0.3.1 (schema vault)
-- uuid-ossp 1.1 (schema extensions)

-- 1. Table columns
CREATE TABLE private.admin_users (
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.achievements (
  id text NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  icon text NOT NULL,
  required_count integer NOT NULL
);

CREATE TABLE public.announcement_reads (
  user_id uuid NOT NULL,
  announcement_id uuid NOT NULL,
  read_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.announcements (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  category text DEFAULT 'general'::text NOT NULL,
  priority integer DEFAULT 0 NOT NULL,
  event_id uuid,
  publish_from timestamp with time zone DEFAULT now() NOT NULL,
  publish_until timestamp with time zone,
  show_on_startup boolean DEFAULT false NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.app_release_policies (
  platform text NOT NULL,
  latest_build integer NOT NULL,
  minimum_build integer NOT NULL,
  latest_version text NOT NULL,
  store_url text NOT NULL,
  update_message text,
  is_active boolean DEFAULT true NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.collection_history (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  collected_at timestamp with time zone DEFAULT now() NOT NULL,
  synced_at timestamp with time zone,
  latitude double precision,
  longitude double precision,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  event_id uuid NOT NULL,
  content_id uuid,
  event_content_id uuid NOT NULL,
  place_id uuid,
  place_visit_id uuid
);

CREATE TABLE public.collection_series (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  category text NOT NULL,
  description text,
  is_active boolean DEFAULT true NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.collection_series_places (
  series_id uuid NOT NULL,
  place_id uuid NOT NULL,
  prefecture text
);

CREATE TABLE public.collection_series_regions (
  series_id uuid NOT NULL,
  region_id uuid NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  display_order integer DEFAULT 0 NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.content_blocks (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  content_id uuid NOT NULL,
  block_type text NOT NULL,
  title text,
  body text,
  media_path text,
  link_url text,
  display_order integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  role text DEFAULT 'default'::text NOT NULL,
  alt_text text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.contents (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  type text DEFAULT 'stamp'::text NOT NULL,
  content_key text NOT NULL,
  title text NOT NULL,
  description text,
  image_url text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.event_achievements (
  event_id uuid NOT NULL,
  achievement_id text NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.event_collection_resets (
  user_id uuid NOT NULL,
  event_id uuid NOT NULL,
  reset_at timestamp with time zone NOT NULL
);

CREATE TABLE public.event_contents (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_id uuid NOT NULL,
  content_id uuid NOT NULL,
  place_id uuid NOT NULL,
  display_order integer DEFAULT 0 NOT NULL,
  start_at timestamp with time zone,
  end_at timestamp with time zone,
  is_active boolean DEFAULT true NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  slug text NOT NULL,
  name text NOT NULL,
  description text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  icon_url text,
  cover_image_url text,
  start_at timestamp with time zone,
  end_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  prefecture text,
  item_label_singular text DEFAULT 'スポット'::text NOT NULL,
  item_label_plural text DEFAULT 'スポット'::text NOT NULL,
  theme_primary_hex text,
  theme_primary_deep_hex text,
  theme_accent_hex text
);

CREATE TABLE public.geo_region_prefectures (
  region_id uuid NOT NULL,
  prefecture text NOT NULL
);

CREATE TABLE public.geo_regions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  level text NOT NULL,
  display_order integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.location_security_events (
  id bigint GENERATED BY DEFAULT AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  event_type text NOT NULL,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL,
  details jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.location_security_states (
  user_id uuid NOT NULL,
  mock_violation_count integer DEFAULT 0 NOT NULL,
  last_mock_violation_at timestamp with time zone,
  cooldown_started_at timestamp with time zone,
  cooldown_until timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  movement_violation_count integer DEFAULT 0 NOT NULL,
  last_movement_violation_at timestamp with time zone
);

CREATE TABLE public.place_visits (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  place_id uuid NOT NULL,
  client_visit_id uuid NOT NULL,
  visited_at timestamp with time zone NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  accuracy_meters double precision,
  source text DEFAULT 'gps'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.places (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  radius_meters integer DEFAULT 200 NOT NULL,
  location geography(Point,4326),
  address text,
  prefecture text,
  city text,
  category text,
  description text,
  icon text,
  image_url text,
  official_url text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  external_ids jsonb DEFAULT '{}'::jsonb NOT NULL,
  location_source text,
  location_source_url text,
  location_verified_at timestamp with time zone,
  location_confidence text DEFAULT 'unverified'::text NOT NULL
);

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  display_name text,
  avatar_url text,
  age_group text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  avatar_key text,
  gender text
);

CREATE TABLE public.roadside_station_registry (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  official_name text NOT NULL,
  prefecture text NOT NULL,
  municipality text,
  registration_round integer,
  registration_date date,
  official_source_url text,
  source_checked_at timestamp with time zone,
  place_id uuid,
  status text DEFAULT 'registered'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  candidate_latitude double precision,
  candidate_longitude double precision,
  candidate_address text,
  candidate_source text,
  candidate_checked_at timestamp with time zone,
  candidate_confidence text DEFAULT 'unverified'::text NOT NULL
);

CREATE TABLE public.user_event_favorites (
  user_id uuid NOT NULL,
  event_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.user_event_participations (
  user_id uuid NOT NULL,
  event_id uuid NOT NULL,
  joined_at timestamp with time zone DEFAULT now() NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  left_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.user_event_preferences (
  user_id uuid NOT NULL,
  current_event_id uuid NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. Constraints
ALTER TABLE private.admin_users ADD CONSTRAINT admin_users_pkey PRIMARY KEY (user_id);
ALTER TABLE private.admin_users ADD CONSTRAINT admin_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.achievements ADD CONSTRAINT achievements_pkey PRIMARY KEY (id);
ALTER TABLE public.achievements ADD CONSTRAINT achievements_required_count_check CHECK (required_count >= 0);
ALTER TABLE public.announcement_reads ADD CONSTRAINT announcement_reads_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE;
ALTER TABLE public.announcement_reads ADD CONSTRAINT announcement_reads_pkey PRIMARY KEY (user_id, announcement_id);
ALTER TABLE public.announcement_reads ADD CONSTRAINT announcement_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.announcements ADD CONSTRAINT announcements_body_not_blank CHECK (char_length(btrim(body)) > 0);
ALTER TABLE public.announcements ADD CONSTRAINT announcements_category_check CHECK (category = ANY (ARRAY['event_start'::text, 'event_ending'::text, 'update'::text, 'maintenance'::text, 'campaign'::text, 'general'::text]));
ALTER TABLE public.announcements ADD CONSTRAINT announcements_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL;
ALTER TABLE public.announcements ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);
ALTER TABLE public.announcements ADD CONSTRAINT announcements_publish_window_check CHECK (publish_until IS NULL OR publish_until > publish_from);
ALTER TABLE public.announcements ADD CONSTRAINT announcements_title_not_blank CHECK (char_length(btrim(title)) > 0);
ALTER TABLE public.app_release_policies ADD CONSTRAINT app_release_policies_check CHECK (minimum_build > 0 AND minimum_build <= latest_build);
ALTER TABLE public.app_release_policies ADD CONSTRAINT app_release_policies_latest_build_check CHECK (latest_build > 0);
ALTER TABLE public.app_release_policies ADD CONSTRAINT app_release_policies_pkey PRIMARY KEY (platform);
ALTER TABLE public.app_release_policies ADD CONSTRAINT app_release_policies_platform_check CHECK (platform = ANY (ARRAY['android'::text, 'ios'::text]));
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_content_id_fkey FOREIGN KEY (content_id) REFERENCES contents(id) ON DELETE RESTRICT;
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_event_content_id_fkey FOREIGN KEY (event_content_id) REFERENCES event_contents(id) ON DELETE RESTRICT;
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE RESTRICT;
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_pkey PRIMARY KEY (id);
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_place_id_fkey FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE RESTRICT;
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_place_visit_id_fkey FOREIGN KEY (place_visit_id) REFERENCES place_visits(id) ON DELETE RESTRICT;
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_user_event_content_unique UNIQUE (user_id, event_content_id);
ALTER TABLE public.collection_history ADD CONSTRAINT collection_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.collection_series ADD CONSTRAINT collection_series_code_key UNIQUE (code);
ALTER TABLE public.collection_series ADD CONSTRAINT collection_series_pkey PRIMARY KEY (id);
ALTER TABLE public.collection_series_places ADD CONSTRAINT collection_series_places_pkey PRIMARY KEY (series_id, place_id);
ALTER TABLE public.collection_series_places ADD CONSTRAINT collection_series_places_place_id_fkey FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE;
ALTER TABLE public.collection_series_places ADD CONSTRAINT collection_series_places_series_id_fkey FOREIGN KEY (series_id) REFERENCES collection_series(id) ON DELETE CASCADE;
ALTER TABLE public.collection_series_regions ADD CONSTRAINT collection_series_regions_pkey PRIMARY KEY (series_id, region_id);
ALTER TABLE public.collection_series_regions ADD CONSTRAINT collection_series_regions_region_id_fkey FOREIGN KEY (region_id) REFERENCES geo_regions(id) ON DELETE CASCADE;
ALTER TABLE public.collection_series_regions ADD CONSTRAINT collection_series_regions_series_id_fkey FOREIGN KEY (series_id) REFERENCES collection_series(id) ON DELETE CASCADE;
ALTER TABLE public.content_blocks ADD CONSTRAINT content_blocks_content_id_fkey FOREIGN KEY (content_id) REFERENCES contents(id) ON DELETE CASCADE;
ALTER TABLE public.content_blocks ADD CONSTRAINT content_blocks_display_order_check CHECK (display_order >= 0);
ALTER TABLE public.content_blocks ADD CONSTRAINT content_blocks_payload_check CHECK (block_type = 'text'::text AND body IS NOT NULL AND btrim(body) <> ''::text OR block_type = 'image'::text AND media_path IS NOT NULL AND btrim(media_path) <> ''::text OR block_type = 'link'::text AND link_url IS NOT NULL AND btrim(link_url) <> ''::text);
ALTER TABLE public.content_blocks ADD CONSTRAINT content_blocks_pkey PRIMARY KEY (id);
ALTER TABLE public.content_blocks ADD CONSTRAINT content_blocks_role_format_check CHECK (role ~ '^[a-z][a-z0-9_]{0,63}$'::text);
ALTER TABLE public.content_blocks ADD CONSTRAINT content_blocks_type_check CHECK (block_type = ANY (ARRAY['text'::text, 'image'::text, 'link'::text]));
ALTER TABLE public.contents ADD CONSTRAINT contents_pkey PRIMARY KEY (id);
ALTER TABLE public.contents ADD CONSTRAINT contents_type_content_key_unique UNIQUE (type, content_key);
ALTER TABLE public.event_achievements ADD CONSTRAINT event_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES achievements(id) ON DELETE RESTRICT;
ALTER TABLE public.event_achievements ADD CONSTRAINT event_achievements_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE RESTRICT;
ALTER TABLE public.event_achievements ADD CONSTRAINT event_achievements_pkey PRIMARY KEY (event_id, achievement_id);
ALTER TABLE public.event_collection_resets ADD CONSTRAINT event_collection_resets_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
ALTER TABLE public.event_collection_resets ADD CONSTRAINT event_collection_resets_pkey PRIMARY KEY (user_id, event_id);
ALTER TABLE public.event_collection_resets ADD CONSTRAINT event_collection_resets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.event_contents ADD CONSTRAINT event_contents_content_id_fkey FOREIGN KEY (content_id) REFERENCES contents(id) ON DELETE RESTRICT;
ALTER TABLE public.event_contents ADD CONSTRAINT event_contents_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE RESTRICT;
ALTER TABLE public.event_contents ADD CONSTRAINT event_contents_period_check CHECK (end_at IS NULL OR start_at IS NULL OR start_at < end_at);
ALTER TABLE public.event_contents ADD CONSTRAINT event_contents_pkey PRIMARY KEY (id);
ALTER TABLE public.event_contents ADD CONSTRAINT event_contents_place_id_fkey FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE RESTRICT;
ALTER TABLE public.event_contents ADD CONSTRAINT event_contents_unique UNIQUE (event_id, content_id, place_id);
ALTER TABLE public.events ADD CONSTRAINT events_pkey PRIMARY KEY (id);
ALTER TABLE public.events ADD CONSTRAINT events_slug_key UNIQUE (slug);
ALTER TABLE public.geo_region_prefectures ADD CONSTRAINT geo_region_prefectures_pkey PRIMARY KEY (region_id, prefecture);
ALTER TABLE public.geo_region_prefectures ADD CONSTRAINT geo_region_prefectures_region_id_fkey FOREIGN KEY (region_id) REFERENCES geo_regions(id) ON DELETE CASCADE;
ALTER TABLE public.geo_regions ADD CONSTRAINT geo_regions_code_key UNIQUE (code);
ALTER TABLE public.geo_regions ADD CONSTRAINT geo_regions_level_check CHECK (level = ANY (ARRAY['prefecture'::text, 'regional'::text, 'national'::text]));
ALTER TABLE public.geo_regions ADD CONSTRAINT geo_regions_pkey PRIMARY KEY (id);
ALTER TABLE public.location_security_events ADD CONSTRAINT location_security_events_pkey PRIMARY KEY (id);
ALTER TABLE public.location_security_events ADD CONSTRAINT location_security_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.location_security_states ADD CONSTRAINT location_security_states_mock_violation_count_check CHECK (mock_violation_count >= 0);
ALTER TABLE public.location_security_states ADD CONSTRAINT location_security_states_movement_violation_count_check CHECK (movement_violation_count >= 0);
ALTER TABLE public.location_security_states ADD CONSTRAINT location_security_states_pkey PRIMARY KEY (user_id);
ALTER TABLE public.location_security_states ADD CONSTRAINT location_security_states_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.place_visits ADD CONSTRAINT place_visits_accuracy_check CHECK (accuracy_meters IS NULL OR accuracy_meters >= 0::double precision);
ALTER TABLE public.place_visits ADD CONSTRAINT place_visits_latitude_check CHECK (latitude >= '-90'::integer::double precision AND latitude <= 90::double precision);
ALTER TABLE public.place_visits ADD CONSTRAINT place_visits_longitude_check CHECK (longitude >= '-180'::integer::double precision AND longitude <= 180::double precision);
ALTER TABLE public.place_visits ADD CONSTRAINT place_visits_pkey PRIMARY KEY (id);
ALTER TABLE public.place_visits ADD CONSTRAINT place_visits_place_id_fkey FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE RESTRICT;
ALTER TABLE public.place_visits ADD CONSTRAINT place_visits_user_client_unique UNIQUE (user_id, client_visit_id);
ALTER TABLE public.place_visits ADD CONSTRAINT place_visits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.places ADD CONSTRAINT places_latitude_check CHECK (latitude >= '-90'::integer::double precision AND latitude <= 90::double precision);
ALTER TABLE public.places ADD CONSTRAINT places_location_confidence_check CHECK (location_confidence = ANY (ARRAY['unverified'::text, 'provisional'::text, 'verified'::text]));
ALTER TABLE public.places ADD CONSTRAINT places_longitude_check CHECK (longitude >= '-180'::integer::double precision AND longitude <= 180::double precision);
ALTER TABLE public.places ADD CONSTRAINT places_pkey PRIMARY KEY (id);
ALTER TABLE public.places ADD CONSTRAINT places_radius_check CHECK (radius_meters >= 50 AND radius_meters <= 1000);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_display_name_length_check CHECK (display_name IS NULL OR char_length(btrim(display_name)) >= 1 AND char_length(btrim(display_name)) <= 30 AND display_name = btrim(display_name));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_gender_check CHECK (gender IS NULL OR (gender = ANY (ARRAY['男性'::text, '女性'::text, 'その他'::text, '回答しない'::text])));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.roadside_station_registry ADD CONSTRAINT roadside_station_registry_candidate_confidence_check CHECK (candidate_confidence = ANY (ARRAY['unverified'::text, 'candidate'::text, 'verified'::text]));
ALTER TABLE public.roadside_station_registry ADD CONSTRAINT roadside_station_registry_pkey PRIMARY KEY (id);
ALTER TABLE public.roadside_station_registry ADD CONSTRAINT roadside_station_registry_place_id_fkey FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE SET NULL;
ALTER TABLE public.roadside_station_registry ADD CONSTRAINT roadside_station_registry_status_check CHECK (status = ANY (ARRAY['registered'::text, 'opening_pending'::text, 'open'::text, 'closed'::text, 'deregistered'::text]));
ALTER TABLE public.user_event_favorites ADD CONSTRAINT user_event_favorites_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
ALTER TABLE public.user_event_favorites ADD CONSTRAINT user_event_favorites_pkey PRIMARY KEY (user_id, event_id);
ALTER TABLE public.user_event_favorites ADD CONSTRAINT user_event_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.user_event_participations ADD CONSTRAINT user_event_participations_event_id_fkey FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
ALTER TABLE public.user_event_participations ADD CONSTRAINT user_event_participations_pkey PRIMARY KEY (user_id, event_id);
ALTER TABLE public.user_event_participations ADD CONSTRAINT user_event_participations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.user_event_preferences ADD CONSTRAINT user_event_preferences_current_event_id_fkey FOREIGN KEY (current_event_id) REFERENCES events(id) ON DELETE CASCADE;
ALTER TABLE public.user_event_preferences ADD CONSTRAINT user_event_preferences_pkey PRIMARY KEY (user_id);
ALTER TABLE public.user_event_preferences ADD CONSTRAINT user_event_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- 3. Explicit indexes not already created by PRIMARY KEY / UNIQUE constraints
CREATE INDEX announcement_reads_announcement_idx ON public.announcement_reads USING btree (announcement_id);
CREATE INDEX announcement_reads_user_read_at_idx ON public.announcement_reads USING btree (user_id, read_at DESC);
CREATE INDEX announcements_event_idx ON public.announcements USING btree (event_id) WHERE (event_id IS NOT NULL);
CREATE INDEX announcements_publication_idx ON public.announcements USING btree (is_active, show_on_startup, publish_from DESC, publish_until);
CREATE INDEX collection_history_collected_at_idx ON public.collection_history USING btree (collected_at DESC);
CREATE INDEX collection_history_content_idx ON public.collection_history USING btree (content_id);
CREATE INDEX collection_history_event_collected_at_idx ON public.collection_history USING btree (event_id, collected_at DESC);
CREATE INDEX collection_history_event_content_idx ON public.collection_history USING btree (event_content_id);
CREATE INDEX collection_history_place_idx ON public.collection_history USING btree (place_id);
CREATE INDEX collection_history_place_visit_idx ON public.collection_history USING btree (place_visit_id);
CREATE INDEX collection_history_user_collected_at_idx ON public.collection_history USING btree (user_id, collected_at DESC);
CREATE UNIQUE INDEX collection_history_user_event_content_unique ON public.collection_history USING btree (user_id, event_content_id);
CREATE INDEX collection_history_user_event_idx ON public.collection_history USING btree (user_id, event_id);
CREATE INDEX collection_history_user_id_idx ON public.collection_history USING btree (user_id);
CREATE INDEX collection_series_places_place_idx ON public.collection_series_places USING btree (place_id);
CREATE INDEX collection_series_places_series_pref_idx ON public.collection_series_places USING btree (series_id, prefecture);
CREATE INDEX collection_series_regions_region_idx ON public.collection_series_regions USING btree (region_id);
CREATE INDEX content_blocks_content_order_idx ON public.content_blocks USING btree (content_id, display_order, id) WHERE (is_active = true);
CREATE INDEX contents_is_active_idx ON public.contents USING btree (is_active);
CREATE UNIQUE INDEX contents_type_content_key_unique ON public.contents USING btree (type, content_key);
CREATE INDEX event_achievements_achievement_idx ON public.event_achievements USING btree (achievement_id);
CREATE INDEX event_achievements_event_sort_idx ON public.event_achievements USING btree (event_id, sort_order);
CREATE INDEX event_collection_resets_event_idx ON public.event_collection_resets USING btree (event_id);
CREATE INDEX event_contents_active_idx ON public.event_contents USING btree (is_active);
CREATE INDEX event_contents_content_idx ON public.event_contents USING btree (content_id);
CREATE INDEX event_contents_event_idx ON public.event_contents USING btree (event_id);
CREATE INDEX event_contents_place_idx ON public.event_contents USING btree (place_id);
CREATE UNIQUE INDEX event_contents_unique ON public.event_contents USING btree (event_id, content_id, place_id);
CREATE INDEX geo_region_prefectures_prefecture_idx ON public.geo_region_prefectures USING btree (prefecture);
CREATE INDEX location_security_events_user_occurred_idx ON public.location_security_events USING btree (user_id, occurred_at DESC);
CREATE INDEX place_visits_place_idx ON public.place_visits USING btree (place_id);
CREATE UNIQUE INDEX place_visits_user_client_unique ON public.place_visits USING btree (user_id, client_visit_id);
CREATE INDEX place_visits_user_idx ON public.place_visits USING btree (user_id);
CREATE INDEX place_visits_visited_at_idx ON public.place_visits USING btree (visited_at);
CREATE INDEX places_category_prefecture_idx ON public.places USING btree (category, prefecture);
CREATE INDEX places_is_active_idx ON public.places USING btree (is_active);
CREATE INDEX places_location_gix ON public.places USING gist (location);
CREATE INDEX idx_profiles_age_gender ON public.profiles USING btree (age_group, gender, id);
CREATE INDEX profiles_active_idx ON public.profiles USING btree (is_active);
CREATE UNIQUE INDEX profiles_display_name_unique_idx ON public.profiles USING btree (lower(display_name)) WHERE (display_name IS NOT NULL);
CREATE INDEX roadside_station_registry_candidate_confidence_idx ON public.roadside_station_registry USING btree (candidate_confidence);
CREATE UNIQUE INDEX roadside_station_registry_name_prefecture_uq ON public.roadside_station_registry USING btree (prefecture, official_name);
CREATE INDEX roadside_station_registry_place_idx ON public.roadside_station_registry USING btree (place_id);
CREATE INDEX user_event_favorites_event_idx ON public.user_event_favorites USING btree (event_id);
CREATE INDEX idx_user_event_participations_event_user ON public.user_event_participations USING btree (event_id, user_id);
CREATE INDEX user_event_participations_event_active_idx ON public.user_event_participations USING btree (event_id, is_active);
CREATE INDEX user_event_preferences_current_event_idx ON public.user_event_preferences USING btree (current_event_id) WHERE (current_event_id IS NOT NULL);

-- 4. RLS enablement
ALTER TABLE private.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_release_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_series ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_series_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_series_regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_collection_resets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_contents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geo_region_prefectures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geo_regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_security_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roadside_station_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_event_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_event_participations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_event_preferences ENABLE ROW LEVEL SECURITY;

-- 5. RLS policies
CREATE POLICY achievements_select_authenticated ON public.achievements AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY announcement_reads_insert_own ON public.announcement_reads AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY announcement_reads_select_own ON public.announcement_reads AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY announcement_reads_update_own ON public.announcement_reads AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY announcements_select_published ON public.announcements AS PERMISSIVE FOR SELECT TO authenticated USING ((is_active AND (publish_from <= now()) AND ((publish_until IS NULL) OR (now() < publish_until))));
CREATE POLICY app_release_policies_read_active ON public.app_release_policies AS PERMISSIVE FOR SELECT TO anon, authenticated USING ((is_active = true));
CREATE POLICY collection_history_select_own ON public.collection_history AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY collection_series_read ON public.collection_series AS PERMISSIVE FOR SELECT TO authenticated USING (is_active);
CREATE POLICY collection_series_places_read ON public.collection_series_places AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY collection_series_regions_read ON public.collection_series_regions AS PERMISSIVE FOR SELECT TO authenticated USING (is_active);
CREATE POLICY content_blocks_admin_delete ON public.content_blocks AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT private.is_admin() AS is_admin));
CREATE POLICY content_blocks_admin_insert ON public.content_blocks AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT private.is_admin() AS is_admin));
CREATE POLICY content_blocks_admin_update ON public.content_blocks AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT private.is_admin() AS is_admin)) WITH CHECK (( SELECT private.is_admin() AS is_admin));
CREATE POLICY content_blocks_select_active ON public.content_blocks AS PERMISSIVE FOR SELECT TO authenticated USING ((is_active = true));
CREATE POLICY contents_select_active ON public.contents AS PERMISSIVE FOR SELECT TO authenticated USING ((is_active = true));
CREATE POLICY event_achievements_select_authenticated ON public.event_achievements AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY event_contents_select_active ON public.event_contents AS PERMISSIVE FOR SELECT TO authenticated USING ((is_active = true));
CREATE POLICY events_admin_update_theme ON public.events AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT private.is_admin() AS is_admin)) WITH CHECK (( SELECT private.is_admin() AS is_admin));
CREATE POLICY events_select_active ON public.events AS PERMISSIVE FOR SELECT TO authenticated USING ((is_active = true));
CREATE POLICY events_select_active_anon ON public.events AS PERMISSIVE FOR SELECT TO anon USING ((is_active = true));
CREATE POLICY geo_region_prefectures_read ON public.geo_region_prefectures AS PERMISSIVE FOR SELECT TO authenticated USING (true);
CREATE POLICY geo_regions_read ON public.geo_regions AS PERMISSIVE FOR SELECT TO authenticated USING (is_active);
CREATE POLICY place_visits_select_own ON public.place_visits AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY places_admin_update ON public.places AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT private.is_admin() AS is_admin)) WITH CHECK (( SELECT private.is_admin() AS is_admin));
CREATE POLICY places_select_active ON public.places AS PERMISSIVE FOR SELECT TO authenticated USING ((is_active = true));
CREATE POLICY profiles_insert_own ON public.profiles AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY profiles_select_own ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY profiles_update_own ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY user_event_favorites_delete_own ON public.user_event_favorites AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_favorites_insert_own ON public.user_event_favorites AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_favorites_select_own ON public.user_event_favorites AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_participations_delete_own ON public.user_event_participations AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_participations_insert_own ON public.user_event_participations AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_participations_select_own ON public.user_event_participations AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_participations_update_own ON public.user_event_participations AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_preferences_delete_own ON public.user_event_preferences AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_preferences_insert_own ON public.user_event_preferences AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_preferences_select_own ON public.user_event_preferences AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY user_event_preferences_update_own ON public.user_event_preferences AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

-- 6. Triggers
CREATE TRIGGER enforce_location_collection_cooldown BEFORE INSERT ON collection_history FOR EACH ROW EXECUTE FUNCTION enforce_location_collection_cooldown();
CREATE TRIGGER events_set_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION set_events_updated_at();
CREATE TRIGGER places_set_updated_at BEFORE INSERT OR UPDATE OF latitude, longitude, name, radius_meters, address, prefecture, city, category, description, icon, image_url, official_url, is_active ON places FOR EACH ROW EXECUTE FUNCTION set_places_updated_at();
CREATE TRIGGER profiles_set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 7. Function definitions. Restore only after dependencies and extensions exist.
CREATE OR REPLACE FUNCTION private.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from private.admin_users au
      where au.user_id = (select auth.uid())
    );
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_location_collection_cooldown()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_state public.location_security_states%rowtype;
begin
  select *
    into v_state
  from public.location_security_states
  where user_id = new.user_id;

  if found
     and v_state.cooldown_until is not null
     and v_state.cooldown_until > now()
     and (
       v_state.cooldown_started_at is null
       or new.collected_at >= v_state.cooldown_started_at
     ) then
    raise exception '位置情報保護のためスタンプ獲得を一時停止しています.';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_collection_counts(p_event_id uuid)
 RETURNS TABLE(total_count bigint, collected_count bigint, uncollected_count bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with items as (
 select ec.id,
   exists(select 1 from public.collection_history ch
          where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id) as collected
 from public.event_contents ec
 join public.contents c on c.id=ec.content_id and c.is_active
 join public.places p on p.id=ec.place_id and p.is_active
 where ec.event_id=p_event_id and ec.is_active
)
select count(*)::bigint,
       count(*) filter(where collected)::bigint,
       count(*) filter(where not collected)::bigint
from items;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_contents_by_ids(p_event_id uuid, p_event_content_ids uuid[])
 RETURNS TABLE(event_content_id uuid, content_id uuid, place_id uuid, content_key text, title text, description text, icon text, image_url text, latitude double precision, longitude double precision, stamp_radius_meters integer, prefecture text, city text, display_order integer, is_collected boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
select ec.id,c.id,p.id,c.content_key,c.title,c.description,p.icon,
       coalesce(c.image_url,p.image_url),p.latitude,p.longitude,p.radius_meters,
       p.prefecture,p.city,ec.display_order,
       exists(select 1 from public.collection_history ch
              where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id)
from public.event_contents ec
join public.contents c on c.id=ec.content_id and c.is_active
join public.places p on p.id=ec.place_id and p.is_active
where ec.event_id=p_event_id and ec.is_active
  and ec.id=any(coalesce(p_event_content_ids,array[]::uuid[]))
order by ec.display_order,c.title,ec.id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_contents_by_region(p_event_id uuid, p_region_code text)
 RETURNS TABLE(event_content_id uuid, content_id uuid, place_id uuid, title text, description text, icon text, latitude double precision, longitude double precision, stamp_radius_meters integer, prefecture text, city text, display_order integer, is_collected boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
select ec.id,c.id,p.id,c.title,c.description,p.icon,p.latitude,p.longitude,p.radius_meters,p.prefecture,p.city,ec.display_order,
 exists(select 1 from public.collection_history ch where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id)
from public.geo_regions gr
join public.geo_region_prefectures grp on grp.region_id=gr.id
join public.places p on p.prefecture=grp.prefecture and p.is_active
join public.event_contents ec on ec.place_id=p.id and ec.event_id=p_event_id and ec.is_active
join public.contents c on c.id=ec.content_id and c.is_active
where gr.code=p_region_code and gr.is_active
order by ec.display_order,c.title
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_contents_in_bounds(p_event_id uuid, p_south double precision, p_west double precision, p_north double precision, p_east double precision, p_limit integer DEFAULT 400)
 RETURNS TABLE(event_content_id uuid, content_id uuid, place_id uuid, content_key text, title text, description text, icon text, image_url text, latitude double precision, longitude double precision, stamp_radius_meters integer, prefecture text, city text, display_order integer, is_collected boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
select ec.id,c.id,p.id,c.content_key,c.title,c.description,p.icon,
       coalesce(c.image_url,p.image_url),p.latitude,p.longitude,p.radius_meters,
       p.prefecture,p.city,ec.display_order,
       exists(select 1 from public.collection_history ch
              where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id)
from public.event_contents ec
join public.contents c on c.id=ec.content_id and c.is_active
join public.places p on p.id=ec.place_id and p.is_active
where ec.event_id=p_event_id and ec.is_active
  and p.latitude between least(p_south,p_north) and greatest(p_south,p_north)
  and (
    case when p_west <= p_east
      then p.longitude between p_west and p_east
      else p.longitude >= p_west or p.longitude <= p_east
    end
  )
order by ec.display_order,c.title
limit greatest(1,least(coalesce(p_limit,400),1000))
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_contents_nearby(p_event_id uuid, p_latitude double precision, p_longitude double precision, p_radius_meters double precision DEFAULT 50000, p_limit integer DEFAULT 250)
 RETURNS TABLE(event_content_id uuid, content_id uuid, place_id uuid, content_key text, title text, description text, icon text, image_url text, latitude double precision, longitude double precision, stamp_radius_meters integer, prefecture text, city text, display_order integer, distance_meters double precision, is_collected boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$
select ec.id,c.id,p.id,c.content_key,c.title,c.description,p.icon,coalesce(c.image_url,p.image_url),
p.latitude,p.longitude,p.radius_meters,p.prefecture,p.city,ec.display_order,
st_distance(st_setsrid(st_makepoint(p.longitude,p.latitude),4326)::geography,
            st_setsrid(st_makepoint(p_longitude,p_latitude),4326)::geography) as distance_meters,
exists(select 1 from public.collection_history ch where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id)
from public.event_contents ec
join public.contents c on c.id=ec.content_id and c.is_active
join public.places p on p.id=ec.place_id and p.is_active
where ec.event_id=p_event_id and ec.is_active
and st_dwithin(st_setsrid(st_makepoint(p.longitude,p.latitude),4326)::geography,
               st_setsrid(st_makepoint(p_longitude,p_latitude),4326)::geography,
               greatest(1000,least(coalesce(p_radius_meters,50000),200000)))
order by st_distance(st_setsrid(st_makepoint(p.longitude,p.latitude),4326)::geography,
            st_setsrid(st_makepoint(p_longitude,p_latitude),4326)::geography)
limit greatest(1,least(coalesce(p_limit,250),1000))
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_contents_page(p_event_id uuid, p_offset integer DEFAULT 0, p_limit integer DEFAULT 100, p_collection_state text DEFAULT 'all'::text)
 RETURNS TABLE(event_content_id uuid, content_id uuid, place_id uuid, content_key text, title text, description text, icon text, image_url text, latitude double precision, longitude double precision, stamp_radius_meters integer, prefecture text, city text, display_order integer, is_collected boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with items as (
select ec.id as event_content_id,c.id as content_id,p.id as place_id,c.content_key,c.title,
       c.description,p.icon,coalesce(c.image_url,p.image_url) as image_url,
       p.latitude,p.longitude,p.radius_meters as stamp_radius_meters,
       p.prefecture,p.city,ec.display_order,
       exists(select 1 from public.collection_history ch
              where ch.user_id=(select auth.uid()) and ch.event_content_id=ec.id) as is_collected
from public.event_contents ec
join public.contents c on c.id=ec.content_id and c.is_active
join public.places p on p.id=ec.place_id and p.is_active
where ec.event_id=p_event_id and ec.is_active
)
select * from items
where case lower(coalesce(p_collection_state,'all'))
  when 'collected' then is_collected
  when 'uncollected' then not is_collected
  else true end
order by display_order,title,event_content_id
offset greatest(0,coalesce(p_offset,0))
limit greatest(1,least(coalesce(p_limit,100),200));
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_progress_summary(p_event_id uuid)
 RETURNS TABLE(total_count bigint, collected_count bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select
    count(*)::bigint as total_count,
    count(*) filter (
      where exists (
        select 1
        from public.collection_history ch
        where ch.user_id = (select auth.uid())
          and ch.event_content_id = ec.id
      )
    )::bigint as collected_count
  from public.event_contents ec
  join public.contents c on c.id = ec.content_id and c.is_active
  join public.places p on p.id = ec.place_id and p.is_active
  where ec.event_id = p_event_id
    and ec.is_active;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_recommendations(p_limit integer DEFAULT 5)
 RETURNS TABLE(event_id uuid, participant_count bigint, demographic_population bigint, participation_rate numeric, recommendation_basis text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with viewer as (
  select
    p.age_group,
    p.gender
  from public.profiles p
  where p.id = (select auth.uid())
  limit 1
),
profile_mode as (
  select
    v.age_group,
    v.gender,
    (
      v.age_group is not null
      or v.gender in ('男性', '女性')
    ) as can_personalize
  from viewer v
),
demographic_population as (
  select count(*)::bigint as population
  from public.profiles p
  cross join profile_mode m
  where m.can_personalize
    and (
      m.age_group is null
      or p.age_group = m.age_group
    )
    and (
      m.gender not in ('男性', '女性')
      or p.gender = m.gender
    )
),
event_participants as (
  select
    p.event_id,
    count(*)::bigint as participant_count,
    count(*) filter (
      where m.can_personalize
        and (
          m.age_group is null
          or pr.age_group = m.age_group
        )
        and (
          m.gender not in ('男性', '女性')
          or pr.gender = m.gender
        )
    )::bigint as demographic_participant_count
  from public.user_event_participations p
  join public.events e on e.id = p.event_id
  left join public.profiles pr on pr.id = p.user_id
  cross join profile_mode m
  where e.is_active = true
    and (e.end_at is null or e.end_at >= now())
  group by p.event_id
),
personalized as (
  select
    ep.event_id,
    ep.demographic_participant_count as participant_count,
    dp.population as demographic_population,
    round(
      ep.demographic_participant_count::numeric
      / nullif(dp.population, 0) * 100,
      1
    ) as participation_rate,
    case
      when m.age_group is not null and m.gender in ('男性', '女性')
        then m.age_group || '・' || m.gender
      when m.age_group is not null
        then m.age_group
      else m.gender
    end as recommendation_basis
  from event_participants ep
  cross join demographic_population dp
  cross join profile_mode m
  where m.can_personalize
    and dp.population >= 5
    and ep.demographic_participant_count > 0
),
overall as (
  select
    ep.event_id,
    ep.participant_count,
    0::bigint as demographic_population,
    null::numeric as participation_rate,
    'みんなに人気'::text as recommendation_basis
  from event_participants ep
)
select
  r.event_id,
  r.participant_count,
  r.demographic_population,
  r.participation_rate,
  r.recommendation_basis
from (
  select * from personalized
  union all
  select *
  from overall
  where not exists (select 1 from personalized)
) r
where r.event_id not in (
  select p.event_id
  from public.user_event_participations p
  where p.user_id = (select auth.uid())
)
order by
  case when r.recommendation_basis = 'みんなに人気' then 1 else 0 end,
  r.participation_rate desc nulls last,
  r.participant_count desc,
  r.event_id
limit greatest(1, least(coalesce(p_limit, 5), 10));
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_regional_map_progress(p_event_id uuid)
 RETURNS TABLE(region_code text, region_name text, center_latitude double precision, center_longitude double precision, collected_count bigint, total_count bigint, completion_percent numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with regional as (
 select gr.id,gr.code,gr.name,gr.display_order
 from public.geo_regions gr where gr.level='regional' and gr.is_active
),
eligible as (
 select r.id region_id,ec.id event_content_id,p.latitude,p.longitude
 from regional r
 join public.geo_region_prefectures grp on grp.region_id=r.id
 join public.places p on p.prefecture=grp.prefecture and p.is_active
 join public.event_contents ec on ec.place_id=p.id and ec.event_id=p_event_id and ec.is_active
),
mine as (
 select distinct ch.event_content_id from public.collection_history ch
 where ch.user_id=(select auth.uid()) and ch.event_id=p_event_id
)
select r.code,r.name,avg(e.latitude),avg(e.longitude),
 count(distinct e.event_content_id) filter(where m.event_content_id is not null),
 count(distinct e.event_content_id),
 case when count(distinct e.event_content_id)=0 then 0::numeric else
 round(100.0*count(distinct e.event_content_id) filter(where m.event_content_id is not null)/count(distinct e.event_content_id),1) end
from regional r join eligible e on e.region_id=r.id
left join mine m on m.event_content_id=e.event_content_id
group by r.id,r.code,r.name,r.display_order
order by r.display_order
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_social_stats(p_event_id uuid)
 RETURNS TABLE(participant_count bigint, favorite_count bigint, is_favorited boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    (
      select count(*)
      from public.user_event_participations as participation
      where participation.event_id = p_event_id
        and participation.is_active = true
    ) as participant_count,

    (
      select count(*)
      from public.user_event_favorites as favorite
      where favorite.event_id = p_event_id
    ) as favorite_count,

    exists (
      select 1
      from public.user_event_favorites as favorite
      where favorite.event_id = p_event_id
        and favorite.user_id = auth.uid()
    ) as is_favorited;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_collection_history()
 RETURNS TABLE(event_id uuid, event_name text, content_id uuid, card text, event_content_id uuid, place_id uuid, content_key text, collected_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select ch.event_id,e.name,ch.content_id,c.content_key,
         ch.event_content_id,ch.place_id,c.content_key,ch.collected_at
  from public.collection_history ch
  join public.events e on e.id=ch.event_id
  join public.contents c on c.id=ch.content_id
  where ch.user_id=(select auth.uid())
  order by ch.collected_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_event_rank(p_event_id uuid)
 RETURNS TABLE(rank bigint, collected_count bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with ranked as (
    select
      p.id as user_id,
      row_number() over (
        order by
          count(ch.event_content_id) desc,
          min(ch.collected_at) asc,
          p.display_name asc
      ) as rank,
      count(ch.event_content_id) as collected_count
    from public.profiles as p
    join public.collection_history as ch
      on ch.user_id = p.id
     and ch.event_id = p_event_id
     and ch.event_content_id is not null
    where p.is_active = true
      and p.display_name is not null
      and btrim(p.display_name) <> ''
    group by
      p.id,
      p.display_name
  )
  select
    ranked.rank,
    ranked.collected_count
  from ranked
  where ranked.user_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_location_security_state()
 RETURNS TABLE(violation_count integer, cooldown_until timestamp with time zone, cooldown_seconds integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    s.mock_violation_count,
    s.cooldown_until,
    case
      when s.cooldown_until is null or s.cooldown_until <= now() then 0
      else ceil(extract(epoch from (s.cooldown_until - now())))::integer
    end
  from public.location_security_states s
  where s.user_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_public_ranking(p_event_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(rank bigint, display_name text, avatar_key text, collected_count bigint, participant_count bigint, is_me boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    row_number() over (
      order by
        count(ch.event_content_id) desc,
        min(ch.collected_at) asc,
        p.display_name asc
    ) as rank,
    p.display_name,
    p.avatar_key,
    count(ch.event_content_id) as collected_count,
    count(*) over () as participant_count,
    (auth.uid() = p.id) as is_me
  from public.profiles as p
  join public.collection_history as ch
    on ch.user_id = p.id
   and ch.event_id = p_event_id
   and ch.event_content_id is not null
  where p.is_active = true
    and p.display_name is not null
    and btrim(p.display_name) <> ''
  group by
    p.id,
    p.display_name,
    p.avatar_key
  order by
    collected_count desc,
    min(ch.collected_at) asc,
    p.display_name asc
  limit greatest(
    1,
    least(coalesce(p_limit, 50), 100)
  );
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
    insert into public.profiles (
        id,
        display_name,
        avatar_url
    )
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data ->> 'full_name',
            new.raw_user_meta_data ->> 'name'
        ),
        new.raw_user_meta_data ->> 'avatar_url'
    );

    return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_place_visit_and_collect(p_place_id uuid, p_client_visit_id uuid, p_visited_at timestamp with time zone, p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision, p_source text DEFAULT 'gps'::text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(collection_history_id uuid, event_id uuid, event_name text, content_id uuid, event_content_id uuid, place_id uuid, card text, content_title text, collected_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_place public.places%rowtype;
  v_existing_visit public.place_visits%rowtype;
  v_place_visit_id uuid;
  v_existing_place_id uuid;
  v_effective_visited_at timestamptz := now();
begin
  -- ----------------------------------------------------------
  -- 認証確認
  -- ----------------------------------------------------------
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception '認証が必要です.';
  end if;

  -- ----------------------------------------------------------
  -- 入力値確認
  -- ----------------------------------------------------------
  if p_place_id is null then
    raise exception 'place_idは必須です.';
  end if;

  if p_client_visit_id is null then
    raise exception 'client_visit_idは必須です.';
  end if;

  if p_visited_at is null then
    raise exception 'visited_atは必須です.';
  end if;

  if p_latitude is null
     or p_latitude < -90
     or p_latitude > 90 then
    raise exception 'latitudeが不正です.';
  end if;

  if p_longitude is null
     or p_longitude < -180
     or p_longitude > 180 then
    raise exception 'longitudeが不正です.';
  end if;

  if p_accuracy_meters is not null
     and (
       p_accuracy_meters < 0
       or p_accuracy_meters > 10000
     ) then
    raise exception 'accuracy_metersが不正です.';
  end if;

  if p_source is null or length(trim(p_source)) = 0 then
    raise exception 'sourceは必須です.';
  end if;

  -- ----------------------------------------------------------
  -- 対象place取得
  -- ----------------------------------------------------------
  select *
    into v_place
  from public.places
  where id = p_place_id
    and is_active = true;

  if not found then
    raise exception '有効な物理地点が見つかりません.';
  end if;

  -- ----------------------------------------------------------
  -- client_visit_id の冪等性確認
  -- ----------------------------------------------------------
  select *
    into v_existing_visit
  from public.place_visits
  where user_id = v_user_id
    and client_visit_id = p_client_visit_id
  for update;

  if found then
    -- --------------------------------------------------------
    -- 既存visit:
    -- 最初に保存した訪問事実を正とする。
    -- --------------------------------------------------------
    v_place_visit_id := v_existing_visit.id;
    v_effective_visited_at := v_existing_visit.created_at;

    if v_existing_visit.place_id <> p_place_id then
      raise exception
        '同じclient_visit_idが別の物理地点に使用されています.';
    end if;

  else
    -- --------------------------------------------------------
    -- 新規visit:
    -- この時点だけGPS距離判定を行う。
    -- --------------------------------------------------------
    if not public.st_dwithin(
      v_place.location,
      public.st_setsrid(
        public.st_makepoint(p_longitude, p_latitude),
        4326
      )::public.geography,
      v_place.radius_meters
    ) then
      raise exception
        '物理地点の獲得範囲外です.';
    end if;

    insert into public.place_visits (
      user_id,
      place_id,
      client_visit_id,
      visited_at,
      latitude,
      longitude,
      accuracy_meters,
      source,
      metadata
    )
    values (
      v_user_id,
      p_place_id,
      p_client_visit_id,
      v_effective_visited_at,
      p_latitude,
      p_longitude,
      p_accuracy_meters,
      p_source,
      coalesce(p_metadata, '{}'::jsonb)
    )
    on conflict (user_id, client_visit_id)
    do nothing
    returning id into v_place_visit_id;

    if v_place_visit_id is not null then
      -- ------------------------------------------------------
      -- 実際に保存されたvisitを取得する。
      -- collection_historyもこの保存値を使用する。
      -- ------------------------------------------------------
      select *
        into v_existing_visit
      from public.place_visits
      where id = v_place_visit_id
      for update;

      v_effective_visited_at := v_existing_visit.created_at;

    else
      -- ------------------------------------------------------
      -- 同時実行で別トランザクションが先に登録した場合。
      -- ------------------------------------------------------
      select *
        into v_existing_visit
      from public.place_visits
      where user_id = v_user_id
        and client_visit_id = p_client_visit_id
      for update;

      if not found then
        raise exception 'place_visitの保存に失敗しました.';
      end if;

      v_place_visit_id := v_existing_visit.id;
      v_effective_visited_at := v_existing_visit.created_at;

      if v_existing_visit.place_id <> p_place_id then
        raise exception
          '同じclient_visit_idが別の物理地点に使用されています.';
      end if;
    end if;
  end if;

  -- ----------------------------------------------------------
  -- イベント期間と獲得時刻は初回受付時のサーバー時刻で判定する。
  -- 再送時も最初の place_visits.created_at を使用する。
  -- p_visited_at は旧クライアントとの引数互換用で、判定には使わない。
  -- ----------------------------------------------------------
  return query
  with eligible as (
    select
      ec.event_id,
      ec.content_id,
      ec.id as event_content_id,
      ec.place_id
    from public.event_contents ec
    join public.events e
      on e.id = ec.event_id
    join public.contents c
      on c.id = ec.content_id
    where ec.place_id = p_place_id
      and ec.is_active = true
      and c.is_active = true
      and e.is_active = true

      -- 最後のイベントリセット以前の訪問は再獲得に使用しない
      and not exists (
        select 1
        from public.event_collection_resets r
        where r.user_id = v_user_id
          and r.event_id = ec.event_id
          and v_effective_visited_at <= r.reset_at
      )

      -- イベント期間
      and (
        e.start_at is null
        or v_effective_visited_at >= e.start_at
      )
      and (
        e.end_at is null
        or v_effective_visited_at < e.end_at
      )

      -- event_content期間
      and (
        ec.start_at is null
        or v_effective_visited_at >= ec.start_at
      )
      and (
        ec.end_at is null
        or v_effective_visited_at < ec.end_at
      )
  ),
  inserted as (
    insert into public.collection_history as ch (
      user_id,
      event_id,
      content_id,
      event_content_id,
      place_id,
      place_visit_id,
      collected_at,
      synced_at,
      latitude,
      longitude
    )
    select
      v_user_id,
      eligible.event_id,
      eligible.content_id,
      eligible.event_content_id,
      eligible.place_id,
      v_place_visit_id,
      v_effective_visited_at,
      now(),

      -- 重要:
      -- collection_historyのGPSも
      -- 最初に保存されたplace_visitsの事実を使用する。
      v_existing_visit.latitude,
      v_existing_visit.longitude

    from eligible
    on conflict do nothing
    returning
      ch.id,
      ch.event_id,
      ch.content_id,
      ch.event_content_id,
      ch.place_id,
      ch.collected_at
  )
  select
    i.id,
    i.event_id,
    e.name,
    i.content_id,
    i.event_content_id,
    i.place_id,
    c.content_key,
    c.title,
    i.collected_at
  from inserted i
  join public.events e
    on e.id = i.event_id
  join public.contents c
    on c.id = i.content_id
  order by e.name, c.content_key;

end;
$function$
;

CREATE OR REPLACE FUNCTION public.report_location_integrity_violation(p_violation_type text)
 RETURNS TABLE(violation_count integer, cooldown_until timestamp with time zone, cooldown_seconds integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_state public.location_security_states%rowtype;
  v_count integer;
  v_last_at timestamptz;
  v_cooldown interval;
  v_until timestamptz;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if p_violation_type not in ('mock_location','implausible_movement') then raise exception 'unsupported location violation'; end if;
  insert into public.location_security_states (user_id) values (v_user_id) on conflict (user_id) do nothing;
  select s.* into v_state from public.location_security_states s where s.user_id = v_user_id for update;
  if p_violation_type = 'mock_location' then
    v_last_at := v_state.last_mock_violation_at; v_count := v_state.mock_violation_count;
  else
    v_last_at := v_state.last_movement_violation_at; v_count := v_state.movement_violation_count;
  end if;
  if v_last_at is not null and v_now - v_last_at < interval '60 seconds' then
    return query select v_count, v_state.cooldown_until,
      case when v_state.cooldown_until is null or v_state.cooldown_until <= v_now then 0
      else ceil(extract(epoch from (v_state.cooldown_until-v_now)))::integer end;
    return;
  end if;
  if v_last_at is null or v_now-v_last_at >= interval '30 days' then v_count:=1; else v_count:=v_count+1; end if;
  v_cooldown := case when v_count<=1 then interval '0 seconds' when v_count=2 then interval '15 minutes' when v_count=3 then interval '1 hour' else interval '24 hours' end;
  v_until := case when v_cooldown > interval '0 seconds' then v_now+v_cooldown else null end;
  update public.location_security_states s
  set mock_violation_count=case when p_violation_type='mock_location' then v_count else s.mock_violation_count end,
      last_mock_violation_at=case when p_violation_type='mock_location' then v_now else s.last_mock_violation_at end,
      movement_violation_count=case when p_violation_type='implausible_movement' then v_count else s.movement_violation_count end,
      last_movement_violation_at=case when p_violation_type='implausible_movement' then v_now else s.last_movement_violation_at end,
      cooldown_started_at=case when v_until is not null then v_now else s.cooldown_started_at end,
      cooldown_until=case when v_until is not null then greatest(coalesce(s.cooldown_until,v_until),v_until)
                          when s.cooldown_until is not null and s.cooldown_until>v_now then s.cooldown_until else null end,
      updated_at=v_now
  where s.user_id=v_user_id returning s.cooldown_until into v_until;
  insert into public.location_security_events(user_id,event_type,occurred_at,details)
  values(v_user_id,p_violation_type,v_now,jsonb_build_object('violation_count',v_count,'cooldown_seconds',
    case when v_until is null or v_until<=v_now then 0 else ceil(extract(epoch from (v_until-v_now)))::integer end));
  return query select v_count,v_until,
    case when v_until is null or v_until<=v_now then 0 else ceil(extract(epoch from (v_until-v_now)))::integer end;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_event_collection_history(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception '認証されたユーザーが必要です。';
  end if;

  -- この時刻以前の訪問では再獲得できないよう境界を記録する。
  insert into public.event_collection_resets (
    user_id,
    event_id,
    reset_at
  )
  values (
    v_user_id,
    p_event_id,
    clock_timestamp()
  )
  on conflict (user_id, event_id)
  do update set
    reset_at = excluded.reset_at;

  -- 獲得履歴だけを削除する。
  -- place_visits は訪問事実なので削除しない。
  delete from public.collection_history
  where user_id = v_user_id
    and event_id = p_event_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_events_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_places_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  new.location =
    st_setsrid(
      st_makepoint(new.longitude, new.latitude),
      4326
    )::geography;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.st_estimatedextent(text, text)
 RETURNS box2d
 LANGUAGE c
 STABLE STRICT SECURITY DEFINER
AS '$libdir/postgis-3', $function$gserialized_estimated_extent$function$
;

CREATE OR REPLACE FUNCTION public.st_estimatedextent(text, text, text)
 RETURNS box2d
 LANGUAGE c
 STABLE STRICT SECURITY DEFINER
AS '$libdir/postgis-3', $function$gserialized_estimated_extent$function$
;

CREATE OR REPLACE FUNCTION public.st_estimatedextent(text, text, text, boolean)
 RETURNS box2d
 LANGUAGE c
 STABLE STRICT SECURITY DEFINER
AS '$libdir/postgis-3', $function$gserialized_estimated_extent$function$
;

-- 8. Table grants inventory (source state; review, then encode explicit grants separately)
-- postgres DELETE ON private.admin_users
-- postgres INSERT ON private.admin_users
-- postgres REFERENCES ON private.admin_users
-- postgres SELECT ON private.admin_users
-- postgres TRIGGER ON private.admin_users
-- postgres TRUNCATE ON private.admin_users
-- postgres UPDATE ON private.admin_users
-- authenticated SELECT ON public.achievements
-- postgres DELETE ON public.achievements
-- postgres INSERT ON public.achievements
-- postgres REFERENCES ON public.achievements
-- postgres SELECT ON public.achievements
-- postgres TRIGGER ON public.achievements
-- postgres TRUNCATE ON public.achievements
-- postgres UPDATE ON public.achievements
-- service_role REFERENCES ON public.achievements
-- service_role TRIGGER ON public.achievements
-- service_role TRUNCATE ON public.achievements
-- authenticated INSERT ON public.announcement_reads
-- authenticated SELECT ON public.announcement_reads
-- authenticated UPDATE ON public.announcement_reads
-- postgres DELETE ON public.announcement_reads
-- postgres INSERT ON public.announcement_reads
-- postgres REFERENCES ON public.announcement_reads
-- postgres SELECT ON public.announcement_reads
-- postgres TRIGGER ON public.announcement_reads
-- postgres TRUNCATE ON public.announcement_reads
-- postgres UPDATE ON public.announcement_reads
-- service_role REFERENCES ON public.announcement_reads
-- service_role TRIGGER ON public.announcement_reads
-- service_role TRUNCATE ON public.announcement_reads
-- authenticated SELECT ON public.announcements
-- postgres DELETE ON public.announcements
-- postgres INSERT ON public.announcements
-- postgres REFERENCES ON public.announcements
-- postgres SELECT ON public.announcements
-- postgres TRIGGER ON public.announcements
-- postgres TRUNCATE ON public.announcements
-- postgres UPDATE ON public.announcements
-- service_role REFERENCES ON public.announcements
-- service_role TRIGGER ON public.announcements
-- service_role TRUNCATE ON public.announcements
-- anon SELECT ON public.app_release_policies
-- authenticated SELECT ON public.app_release_policies
-- postgres DELETE ON public.app_release_policies
-- postgres INSERT ON public.app_release_policies
-- postgres REFERENCES ON public.app_release_policies
-- postgres SELECT ON public.app_release_policies
-- postgres TRIGGER ON public.app_release_policies
-- postgres TRUNCATE ON public.app_release_policies
-- postgres UPDATE ON public.app_release_policies
-- service_role REFERENCES ON public.app_release_policies
-- service_role TRIGGER ON public.app_release_policies
-- service_role TRUNCATE ON public.app_release_policies
-- authenticated SELECT ON public.collection_history
-- postgres DELETE ON public.collection_history
-- postgres INSERT ON public.collection_history
-- postgres REFERENCES ON public.collection_history
-- postgres SELECT ON public.collection_history
-- postgres TRIGGER ON public.collection_history
-- postgres TRUNCATE ON public.collection_history
-- postgres UPDATE ON public.collection_history
-- service_role REFERENCES ON public.collection_history
-- service_role TRIGGER ON public.collection_history
-- service_role TRUNCATE ON public.collection_history
-- authenticated SELECT ON public.collection_series
-- postgres DELETE ON public.collection_series
-- postgres INSERT ON public.collection_series
-- postgres REFERENCES ON public.collection_series
-- postgres SELECT ON public.collection_series
-- postgres TRIGGER ON public.collection_series
-- postgres TRUNCATE ON public.collection_series
-- postgres UPDATE ON public.collection_series
-- service_role REFERENCES ON public.collection_series
-- service_role TRIGGER ON public.collection_series
-- service_role TRUNCATE ON public.collection_series
-- authenticated SELECT ON public.collection_series_places
-- postgres DELETE ON public.collection_series_places
-- postgres INSERT ON public.collection_series_places
-- postgres REFERENCES ON public.collection_series_places
-- postgres SELECT ON public.collection_series_places
-- postgres TRIGGER ON public.collection_series_places
-- postgres TRUNCATE ON public.collection_series_places
-- postgres UPDATE ON public.collection_series_places
-- service_role REFERENCES ON public.collection_series_places
-- service_role TRIGGER ON public.collection_series_places
-- service_role TRUNCATE ON public.collection_series_places
-- authenticated SELECT ON public.collection_series_regions
-- postgres DELETE ON public.collection_series_regions
-- postgres INSERT ON public.collection_series_regions
-- postgres REFERENCES ON public.collection_series_regions
-- postgres SELECT ON public.collection_series_regions
-- postgres TRIGGER ON public.collection_series_regions
-- postgres TRUNCATE ON public.collection_series_regions
-- postgres UPDATE ON public.collection_series_regions
-- service_role REFERENCES ON public.collection_series_regions
-- service_role TRIGGER ON public.collection_series_regions
-- service_role TRUNCATE ON public.collection_series_regions
-- authenticated DELETE ON public.content_blocks
-- authenticated INSERT ON public.content_blocks
-- authenticated SELECT ON public.content_blocks
-- authenticated UPDATE ON public.content_blocks
-- postgres DELETE ON public.content_blocks
-- postgres INSERT ON public.content_blocks
-- postgres REFERENCES ON public.content_blocks
-- postgres SELECT ON public.content_blocks
-- postgres TRIGGER ON public.content_blocks
-- postgres TRUNCATE ON public.content_blocks
-- postgres UPDATE ON public.content_blocks
-- service_role REFERENCES ON public.content_blocks
-- service_role TRIGGER ON public.content_blocks
-- service_role TRUNCATE ON public.content_blocks
-- authenticated SELECT ON public.contents
-- postgres DELETE ON public.contents
-- postgres INSERT ON public.contents
-- postgres REFERENCES ON public.contents
-- postgres SELECT ON public.contents
-- postgres TRIGGER ON public.contents
-- postgres TRUNCATE ON public.contents
-- postgres UPDATE ON public.contents
-- service_role REFERENCES ON public.contents
-- service_role TRIGGER ON public.contents
-- service_role TRUNCATE ON public.contents
-- authenticated SELECT ON public.event_achievements
-- postgres DELETE ON public.event_achievements
-- postgres INSERT ON public.event_achievements
-- postgres REFERENCES ON public.event_achievements
-- postgres SELECT ON public.event_achievements
-- postgres TRIGGER ON public.event_achievements
-- postgres TRUNCATE ON public.event_achievements
-- postgres UPDATE ON public.event_achievements
-- service_role REFERENCES ON public.event_achievements
-- service_role TRIGGER ON public.event_achievements
-- service_role TRUNCATE ON public.event_achievements
-- postgres DELETE ON public.event_collection_resets
-- postgres INSERT ON public.event_collection_resets
-- postgres REFERENCES ON public.event_collection_resets
-- postgres SELECT ON public.event_collection_resets
-- postgres TRIGGER ON public.event_collection_resets
-- postgres TRUNCATE ON public.event_collection_resets
-- postgres UPDATE ON public.event_collection_resets
-- service_role REFERENCES ON public.event_collection_resets
-- service_role TRIGGER ON public.event_collection_resets
-- service_role TRUNCATE ON public.event_collection_resets
-- authenticated SELECT ON public.event_contents
-- postgres DELETE ON public.event_contents
-- postgres INSERT ON public.event_contents
-- postgres REFERENCES ON public.event_contents
-- postgres SELECT ON public.event_contents
-- postgres TRIGGER ON public.event_contents
-- postgres TRUNCATE ON public.event_contents
-- postgres UPDATE ON public.event_contents
-- service_role REFERENCES ON public.event_contents
-- service_role TRIGGER ON public.event_contents
-- service_role TRUNCATE ON public.event_contents
-- anon SELECT ON public.events
-- authenticated SELECT ON public.events
-- postgres DELETE ON public.events
-- postgres INSERT ON public.events
-- postgres REFERENCES ON public.events
-- postgres SELECT ON public.events
-- postgres TRIGGER ON public.events
-- postgres TRUNCATE ON public.events
-- postgres UPDATE ON public.events
-- service_role REFERENCES ON public.events
-- service_role TRIGGER ON public.events
-- service_role TRUNCATE ON public.events
-- authenticated SELECT ON public.geo_region_prefectures
-- postgres DELETE ON public.geo_region_prefectures
-- postgres INSERT ON public.geo_region_prefectures
-- postgres REFERENCES ON public.geo_region_prefectures
-- postgres SELECT ON public.geo_region_prefectures
-- postgres TRIGGER ON public.geo_region_prefectures
-- postgres TRUNCATE ON public.geo_region_prefectures
-- postgres UPDATE ON public.geo_region_prefectures
-- service_role REFERENCES ON public.geo_region_prefectures
-- service_role TRIGGER ON public.geo_region_prefectures
-- service_role TRUNCATE ON public.geo_region_prefectures
-- authenticated SELECT ON public.geo_regions
-- postgres DELETE ON public.geo_regions
-- postgres INSERT ON public.geo_regions
-- postgres REFERENCES ON public.geo_regions
-- postgres SELECT ON public.geo_regions
-- postgres TRIGGER ON public.geo_regions
-- postgres TRUNCATE ON public.geo_regions
-- postgres UPDATE ON public.geo_regions
-- service_role REFERENCES ON public.geo_regions
-- service_role TRIGGER ON public.geo_regions
-- service_role TRUNCATE ON public.geo_regions
-- anon DELETE ON public.geography_columns
-- anon INSERT ON public.geography_columns
-- anon REFERENCES ON public.geography_columns
-- anon SELECT ON public.geography_columns
-- anon TRIGGER ON public.geography_columns
-- anon TRUNCATE ON public.geography_columns
-- anon UPDATE ON public.geography_columns
-- authenticated DELETE ON public.geography_columns
-- authenticated INSERT ON public.geography_columns
-- authenticated REFERENCES ON public.geography_columns
-- authenticated SELECT ON public.geography_columns
-- authenticated TRIGGER ON public.geography_columns
-- authenticated TRUNCATE ON public.geography_columns
-- authenticated UPDATE ON public.geography_columns
-- postgres DELETE ON public.geography_columns
-- postgres INSERT ON public.geography_columns
-- postgres REFERENCES ON public.geography_columns
-- postgres SELECT ON public.geography_columns
-- postgres TRIGGER ON public.geography_columns
-- postgres TRUNCATE ON public.geography_columns
-- postgres UPDATE ON public.geography_columns
-- service_role DELETE ON public.geography_columns
-- service_role INSERT ON public.geography_columns
-- service_role REFERENCES ON public.geography_columns
-- service_role SELECT ON public.geography_columns
-- service_role TRIGGER ON public.geography_columns
-- service_role TRUNCATE ON public.geography_columns
-- service_role UPDATE ON public.geography_columns
-- anon DELETE ON public.geometry_columns
-- anon INSERT ON public.geometry_columns
-- anon REFERENCES ON public.geometry_columns
-- anon SELECT ON public.geometry_columns
-- anon TRIGGER ON public.geometry_columns
-- anon TRUNCATE ON public.geometry_columns
-- anon UPDATE ON public.geometry_columns
-- authenticated DELETE ON public.geometry_columns
-- authenticated INSERT ON public.geometry_columns
-- authenticated REFERENCES ON public.geometry_columns
-- authenticated SELECT ON public.geometry_columns
-- authenticated TRIGGER ON public.geometry_columns
-- authenticated TRUNCATE ON public.geometry_columns
-- authenticated UPDATE ON public.geometry_columns
-- postgres DELETE ON public.geometry_columns
-- postgres INSERT ON public.geometry_columns
-- postgres REFERENCES ON public.geometry_columns
-- postgres SELECT ON public.geometry_columns
-- postgres TRIGGER ON public.geometry_columns
-- postgres TRUNCATE ON public.geometry_columns
-- postgres UPDATE ON public.geometry_columns
-- service_role DELETE ON public.geometry_columns
-- service_role INSERT ON public.geometry_columns
-- service_role REFERENCES ON public.geometry_columns
-- service_role SELECT ON public.geometry_columns
-- service_role TRIGGER ON public.geometry_columns
-- service_role TRUNCATE ON public.geometry_columns
-- service_role UPDATE ON public.geometry_columns
-- postgres DELETE ON public.location_security_events
-- postgres INSERT ON public.location_security_events
-- postgres REFERENCES ON public.location_security_events
-- postgres SELECT ON public.location_security_events
-- postgres TRIGGER ON public.location_security_events
-- postgres TRUNCATE ON public.location_security_events
-- postgres UPDATE ON public.location_security_events
-- service_role REFERENCES ON public.location_security_events
-- service_role TRIGGER ON public.location_security_events
-- service_role TRUNCATE ON public.location_security_events
-- postgres DELETE ON public.location_security_states
-- postgres INSERT ON public.location_security_states
-- postgres REFERENCES ON public.location_security_states
-- postgres SELECT ON public.location_security_states
-- postgres TRIGGER ON public.location_security_states
-- postgres TRUNCATE ON public.location_security_states
-- postgres UPDATE ON public.location_security_states
-- service_role REFERENCES ON public.location_security_states
-- service_role TRIGGER ON public.location_security_states
-- service_role TRUNCATE ON public.location_security_states
-- authenticated SELECT ON public.place_visits
-- postgres DELETE ON public.place_visits
-- postgres INSERT ON public.place_visits
-- postgres REFERENCES ON public.place_visits
-- postgres SELECT ON public.place_visits
-- postgres TRIGGER ON public.place_visits
-- postgres TRUNCATE ON public.place_visits
-- postgres UPDATE ON public.place_visits
-- service_role REFERENCES ON public.place_visits
-- service_role TRIGGER ON public.place_visits
-- service_role TRUNCATE ON public.place_visits
-- authenticated SELECT ON public.places
-- postgres DELETE ON public.places
-- postgres INSERT ON public.places
-- postgres REFERENCES ON public.places
-- postgres SELECT ON public.places
-- postgres TRIGGER ON public.places
-- postgres TRUNCATE ON public.places
-- postgres UPDATE ON public.places
-- service_role REFERENCES ON public.places
-- service_role TRIGGER ON public.places
-- service_role TRUNCATE ON public.places
-- authenticated INSERT ON public.profiles
-- authenticated SELECT ON public.profiles
-- authenticated UPDATE ON public.profiles
-- postgres DELETE ON public.profiles
-- postgres INSERT ON public.profiles
-- postgres REFERENCES ON public.profiles
-- postgres SELECT ON public.profiles
-- postgres TRIGGER ON public.profiles
-- postgres TRUNCATE ON public.profiles
-- postgres UPDATE ON public.profiles
-- service_role REFERENCES ON public.profiles
-- service_role TRIGGER ON public.profiles
-- service_role TRUNCATE ON public.profiles
-- postgres DELETE ON public.roadside_station_registry
-- postgres INSERT ON public.roadside_station_registry
-- postgres REFERENCES ON public.roadside_station_registry
-- postgres SELECT ON public.roadside_station_registry
-- postgres TRIGGER ON public.roadside_station_registry
-- postgres TRUNCATE ON public.roadside_station_registry
-- postgres UPDATE ON public.roadside_station_registry
-- service_role DELETE ON public.roadside_station_registry
-- service_role INSERT ON public.roadside_station_registry
-- service_role REFERENCES ON public.roadside_station_registry
-- service_role SELECT ON public.roadside_station_registry
-- service_role TRIGGER ON public.roadside_station_registry
-- service_role TRUNCATE ON public.roadside_station_registry
-- service_role UPDATE ON public.roadside_station_registry
-- anon DELETE ON public.spatial_ref_sys
-- anon INSERT ON public.spatial_ref_sys
-- anon REFERENCES ON public.spatial_ref_sys
-- anon SELECT ON public.spatial_ref_sys
-- anon TRIGGER ON public.spatial_ref_sys
-- anon TRUNCATE ON public.spatial_ref_sys
-- anon UPDATE ON public.spatial_ref_sys
-- authenticated DELETE ON public.spatial_ref_sys
-- authenticated INSERT ON public.spatial_ref_sys
-- authenticated REFERENCES ON public.spatial_ref_sys
-- authenticated SELECT ON public.spatial_ref_sys
-- authenticated TRIGGER ON public.spatial_ref_sys
-- authenticated TRUNCATE ON public.spatial_ref_sys
-- authenticated UPDATE ON public.spatial_ref_sys
-- postgres DELETE ON public.spatial_ref_sys
-- postgres INSERT ON public.spatial_ref_sys
-- postgres REFERENCES ON public.spatial_ref_sys
-- postgres SELECT ON public.spatial_ref_sys
-- postgres TRIGGER ON public.spatial_ref_sys
-- postgres TRUNCATE ON public.spatial_ref_sys
-- postgres UPDATE ON public.spatial_ref_sys
-- service_role DELETE ON public.spatial_ref_sys
-- service_role INSERT ON public.spatial_ref_sys
-- service_role REFERENCES ON public.spatial_ref_sys
-- service_role SELECT ON public.spatial_ref_sys
-- service_role TRIGGER ON public.spatial_ref_sys
-- service_role TRUNCATE ON public.spatial_ref_sys
-- service_role UPDATE ON public.spatial_ref_sys
-- authenticated DELETE ON public.user_event_favorites
-- authenticated INSERT ON public.user_event_favorites
-- authenticated SELECT ON public.user_event_favorites
-- postgres DELETE ON public.user_event_favorites
-- postgres INSERT ON public.user_event_favorites
-- postgres REFERENCES ON public.user_event_favorites
-- postgres SELECT ON public.user_event_favorites
-- postgres TRIGGER ON public.user_event_favorites
-- postgres TRUNCATE ON public.user_event_favorites
-- postgres UPDATE ON public.user_event_favorites
-- service_role REFERENCES ON public.user_event_favorites
-- service_role TRIGGER ON public.user_event_favorites
-- service_role TRUNCATE ON public.user_event_favorites
-- authenticated DELETE ON public.user_event_participations
-- authenticated INSERT ON public.user_event_participations
-- authenticated SELECT ON public.user_event_participations
-- authenticated UPDATE ON public.user_event_participations
-- postgres DELETE ON public.user_event_participations
-- postgres INSERT ON public.user_event_participations
-- postgres REFERENCES ON public.user_event_participations
-- postgres SELECT ON public.user_event_participations
-- postgres TRIGGER ON public.user_event_participations
-- postgres TRUNCATE ON public.user_event_participations
-- postgres UPDATE ON public.user_event_participations
-- service_role REFERENCES ON public.user_event_participations
-- service_role TRIGGER ON public.user_event_participations
-- service_role TRUNCATE ON public.user_event_participations
-- authenticated DELETE ON public.user_event_preferences
-- authenticated INSERT ON public.user_event_preferences
-- authenticated SELECT ON public.user_event_preferences
-- authenticated UPDATE ON public.user_event_preferences
-- postgres DELETE ON public.user_event_preferences
-- postgres INSERT ON public.user_event_preferences
-- postgres REFERENCES ON public.user_event_preferences
-- postgres SELECT ON public.user_event_preferences
-- postgres TRIGGER ON public.user_event_preferences
-- postgres TRUNCATE ON public.user_event_preferences
-- postgres UPDATE ON public.user_event_preferences
-- service_role REFERENCES ON public.user_event_preferences
-- service_role TRIGGER ON public.user_event_preferences
-- service_role TRUNCATE ON public.user_event_preferences