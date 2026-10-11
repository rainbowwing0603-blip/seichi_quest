# Master-data export manifest

Source: closed-test Supabase project `wxlvhpmolrtcwryaazfb`, read-only export on 2026-10-09.
Destination schema: candidate production bootstrap in `supabase/baselines/production_schema_candidate_20261009.sql`.
Total exported rows: **10,320** across 13 master/reference tables.

| Apply order | Table | Source rows | Files |
|---:|---|---:|---|
| 1 | `events` | 51 | `001_events.sql` |
| 2 | `places` | 1,713 | `002_places_01.sql` through `002_places_07.sql` |
| 3 | `contents` | 2,742 | `003_contents_01.sql` through `003_contents_11.sql` |
| 4 | `achievements` | 18 | `004_achievements.sql` |
| 5 | `geo_regions` | 57 | `005_geo_regions.sql` |
| 6 | `collection_series` | 1 | `006_collection_series.sql` |
| 7 | `event_contents` | 2,721 | `007_event_contents_01.sql` through `007_event_contents_11.sql` |
| 8 | `content_blocks` | 336 | `008_content_blocks.sql` |
| 9 | `event_achievements` | 18 | `009_event_achievements.sql` |
| 10 | `geo_region_prefectures` | 141 | `010_geo_region_prefectures.sql` |
| 11 | `collection_series_places` | 1,231 | `011_collection_series_places_01.sql` through `011_collection_series_places_05.sql` |
| 12 | `collection_series_regions` | 57 | `012_collection_series_regions.sql` |
| 13 | `roadside_station_registry` | 1,234 | `013_roadside_station_registry_01.sql` through `013_roadside_station_registry_05.sql` |
| | **Total** | **10,320** | **47 SQL files** |

All data files use `jsonb_populate_recordset` and `ON CONFLICT DO NOTHING`. Place geography is serialized as EWKT and was successfully parsed into `geography` in a rollback-only production bootstrap rehearsal. The single event cover URL pointing to the closed-test Supabase project was nulled; local `assets/...` references are retained.

Not included: `announcements`, `app_release_policies`, Storage objects, Auth/users, profiles, visits, collection history, preferences, favorites, participation, announcement reads, location-security data, reset ledgers, or admin membership. These omissions are intentional.


## Validation status

All 47 SQL files were individually executed against the closed-test schema inside explicit transactions and rolled back before production import. This validated SQL syntax and row-to-column type conversion for every exported row. The PostGIS EWKT conversion for place rows was additionally tested against the production schema. The production import has since completed; live validation confirms all 13 expected row counts, zero orphan mappings, zero duplicate roadside registry keys, all geography SRID 4326, and no user-specific rows copied. The closed-test project remains unchanged.
