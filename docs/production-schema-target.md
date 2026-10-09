# Production Supabase schema target

Status: design and source-hardening work in progress. This is not an authorization to deploy to production.

## Design objective

Build the production schema from the current product contract, not by replaying the entire closed-test database history. The live closed-test catalog snapshot is evidence for current column names, constraints and relationships. It is not a production migration.

## Canonical domain model

- `events`: independently published quest/event container, with slug, active window, labels and theme.
- `places`: normalized physical place records and geospatial point.
- `contents`: reusable narrative, quiz, stamp and other app content.
- `event_contents`: the event-to-content-to-place relationship, display ordering and publication window.
- `content_blocks`: ordered story/media blocks attached to content.
- `achievements` + `event_achievements`: achievement definitions and event associations.
- `collection_series`, `collection_series_places`, `collection_series_regions`: only where active product flows use curated collections.
- `geo_regions`, `geo_region_prefectures`: normalized region/reference metadata.
- `roadside_station_registry`: source registry for official roadside-station identity and reconciliation with app places. Import through a staged, validated, atomic server-side process.
- `profiles`: minimal user-owned profile attributes; never expose email/auth internals.
- `collection_history`, `place_visits`: user-owned outcomes and visit evidence, written only through trusted RPC operations.
- `user_event_preferences`, `user_event_favorites`, `user_event_participations`: user-owned event settings/relationships.
- `announcement_reads`: per-user read state.
- `announcements`: editorial content with publication windows; direct writes are server/admin only.
- `app_release_policies`: minimal client-readable release constraints; only server/admin may write.
- `location_security_states`, `location_security_events`: internal anti-abuse data; no direct client table access.
- `event_collection_resets`: internal reset bookkeeping only if the shipped reset feature still needs it.
- `private.admin_users`: keep only if there is a reviewed need for DB-side admin membership. Prefer managed server-side authorization; never trust user-editable metadata.

## Explicitly excluded from the new app schema

- Retired `public.seichi` and all old table-specific coupling.
- Temporary CodeMagic bridge objects that are no longer present in the live catalog.
- Test-only rows, user histories, user profiles, Auth users, location-security history and reset records.
- Historical Storage URLs that point at the closed-test project.
- Extension-owned PostGIS catalog objects such as `spatial_ref_sys`; install/manage the extension through the supported extension mechanism instead of copying its internal catalog.

A table above is not automatically required just because it exists. Before finalizing the baseline, verify each table against current Flutter queries/RPCs and either include it with an owner or explicitly omit it.

## Authorization model

1. Exposed-schema tables use RLS. A table that the client does not need is not granted to `anon` or `authenticated` at all.
2. Keep grants and RLS separate and explicit. No implicit auto-exposure of future tables in local configuration.
3. App sessions include Supabase anonymous-auth users. Therefore, the Postgres role `authenticated` alone does not mean a human-verified account.
4. Published reference content is read-only to clients and filtered by active/publication predicates.
5. Profile and preference rows are limited to `auth.uid()`. Owner columns are immutable to the client.
6. Collection and place-visit writes go through narrow RPCs that derive user identity from `auth.uid()`, validate event/content/place relationships, validate location/cooldown rules, and set server timestamps. Clients do not receive direct INSERT/UPDATE/DELETE grants on outcome tables.
7. Internal registry, anti-abuse, reset and admin data is not directly accessible through the Data API.
8. Admin operations use trusted server-managed credentials/claims. Never authorize from user-editable `user_metadata`.
9. SECURITY DEFINER functions are exceptions, not a default. Each requires a fixed safe `search_path`, a minimal body, explicit EXECUTE grants, and anonymous/cross-user negative tests.
10. Any exposed view uses `security_invoker = true` on supported PostgreSQL versions, unless a documented security review approves an alternative.

## Required RPC contracts

- `collect_stamp` (or the app's final equivalent): derives user ID from `auth.uid()`; validates active event/content/place relationship, proximity evidence and server-side cooldown; performs outcome writes atomically; is idempotent under retry; returns a stable result code without exposing internal security details.
- `record_place_visit` only if a separate visit lifecycle is still needed: same identity/relationship validation and replay protection.
- Admin content/registry functions: no caller-controlled user ID or shared fixed key; service-only or narrowly authorized.
- Account deletion remains an authenticated Edge Function and must delete only the caller's Auth identity plus explicitly owned rows according to a documented retention policy.

Do not finalize RPC names or signatures until the current Flutter repository call sites have been exhaustively matched.

## Deployment stages

1. Inventory every Flutter table/RPC/storage call and every Edge Function.
2. Produce an ordered, repeatable schema baseline (extensions/types, tables, constraints, indexes, functions, grants/RLS, triggers).
3. Generate curated master-data export separately from user data. Verify foreign keys and counts before import.
4. Move only approved Storage assets after rights, hashes, MIME types and bucket visibility are confirmed.
5. Run the schema on an isolated disposable database; rerun from empty to prove repeatability.
6. Run `supabase/security/production_rls_audit.sql`, Supabase security advisors, and role-based positive/negative tests.
7. Deploy production schema and master data; verify counts, geospatial queries, anonymous sign-in, RPCs and release policy.
8. Only after gates pass, switch a production build to the production URL/key. Keep the closed-test project unchanged.

## Source hardening already staged on this branch

- Registry import no longer contains a fixed shared secret in the current source. It reads `ROADSIDESTATION_IMPORT_KEY` from function secrets, rejects non-POST methods, and returns generic client errors. Because the previous literal may exist in Git history and in the already-deployed closed-test function, rotate/revoke the old value in the deployed environment before any further use; deleting it from the latest source does not revoke it.
- Account deletion accepts only POST (besides CORS preflight) and no longer returns underlying Auth/delete error details to clients.
- `supabase/config.toml` disables automatic exposure of new tables and disables the currently broken seed configuration that pointed to a missing `supabase/seed.sql`.

Important: registry import is still not production-ready. Its current delete-and-reinsert sequence is not atomic, and it still needs staging/transactional replacement, secret provisioning, request-rate controls, idempotency and an authorization test before deployment. Do not deploy this function as-is.
