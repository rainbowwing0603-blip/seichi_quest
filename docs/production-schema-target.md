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


## Additional live-catalog findings to address before the baseline is approved

- `public.handle_new_user()` is SECURITY DEFINER and currently has `search_path = public`, unlike most app-owned SECURITY DEFINER functions whose path is pinned to an empty value and whose relations are schema-qualified. Its body schema-qualifies `public.profiles`, so the target should set its search path to empty as well and verify the auth trigger still works.
- Several app-owned SECURITY DEFINER functions are intentionally executable by `authenticated`, and `get_public_ranking` is executable by `anon`. Keep only after reviewing each body and confirming the intended public fields/aggregate exposure. The target baseline must explicitly set EXECUTE grants after function creation because PostgreSQL defaults can otherwise expose new functions to PUBLIC.
- Extension-owned PostGIS overloads also appear as SECURITY DEFINER and publicly executable. Do not blanket-revoke extension grants without testing PostGIS operations; distinguish extension-owned functions from app-owned functions in the privilege audit.
- The prior registry import key has been removed from the current source, but the old value may remain in Git history and in the deployed closed-test function. Rotate/revoke it in the deployed environment before reuse. Tool access available for this task does not expose Edge Function secret management, so that rotation is a deployment gate rather than a completed action.


## Flutter call-site reconciliation (reviewed from current `feature/android-next-release`)

The initial policy matrix must accommodate these live client access patterns; do not issue broad table-level CRUD grants to make them work:

| Table / function | Observed app access | Target access |
|---|---|---|
| `events` | SELECT active events | SELECT only; active predicate; anon access only if pre-session startup truly requires it |
| `user_event_preferences` | SELECT own current event; UPSERT current event | SELECT/INSERT/UPDATE own row; owner immutable; client cannot set admin/system columns |
| `user_event_participations` | SELECT, INSERT and UPDATE active participation | Own row only; move timestamps to DB defaults/trigger or RPC; never permit ownership reassignment |
| `profiles` | SELECT own display name/avatar key | SELECT own only; client does not need direct INSERT based on current inspected service |
| `announcements` | SELECT published announcements | SELECT only; server-controlled publication window |
| `announcement_reads` | SELECT own reads; UPSERT read timestamps | SELECT/INSERT/UPDATE own; constrain read timestamp server-side where practical |
| `app_release_policies` | SELECT release policy | Minimal read-only fields for anon/authenticated; server-only writes |
| `content_blocks` | SELECT active blocks | SELECT active only; no client mutation grant |
| `collection_history` | SELECT own event history; also calls RPCs | SELECT own only; no direct writes |
| `get_my_collection_history()` | RPC for display history | Authenticated EXECUTE; function must derive user from `auth.uid()` |
| `reset_event_collection_history(p_event_id)` | RPC to reset own event history | Authenticated EXECUTE only; verify caller owns the target operation inside function |
| `record_place_visit_and_collect(...)` | RPC for visit and stamp acquisition | Authenticated EXECUTE only; derive user from `auth.uid()`; no direct INSERT/UPDATE/DELETE on visit/history tables |
| `event_contents` and five event-content RPCs | SELECT active mappings and call paged/region/bounds/nearby/by-ID RPCs | SELECT only for public active content; explicit EXECUTE grants per RPC after body review |

This call-site pass is partial, not a claim that every Dart file and Edge Function has been reconciled. Before finalizing grants, inspect remaining map/progress/ranking/series/achievement services and all server-function call sites, then verify the exact select column lists and RPC signatures. Current client code supplies timestamps to some preference/participation/read operations; the target should prefer database-generated timestamps and narrowly grant only columns the app genuinely needs.


### Additional RPCs found in current Flutter services

- `get_event_contents_by_region`
- `get_event_contents_by_ids`
- `get_event_contents_page`
- `get_event_contents_in_bounds`
- `get_event_contents_nearby`
- `get_event_progress_summary`
- `get_my_event_rank`
- `get_event_regional_map_progress`
- `get_my_location_security_state`
- `report_location_integrity_violation`
- Direct SELECT from `event_achievements`

These are part of the client contract and must be included in the function/grant review. The per-user functions must derive the user from `auth.uid()`; public map/content functions should return only published content and bounded results. Do not blanket grant EXECUTE on all functions in `public`.


## Live Supabase advisor baseline (closed-test project, 2026-10-09)

Read-only Supabase security advisor run returned these notable findings. They are recorded as design inputs, not a mandate to copy the old setup:

- **ERROR: RLS disabled in exposed schema** on extension-owned `public.spatial_ref_sys`. Treat this separately from app tables and PostGIS's supported schema layout; do not blindly alter extension internals.
- **5 INFO findings: RLS enabled with no policies** on `private.admin_users`, `public.event_collection_resets`, `public.location_security_events`, `public.location_security_states`, and `public.roadside_station_registry`. The target should retain default-deny/no client grants for these tables; the advisor notice is not a reason to add permissive policies.
- **PostGIS in public schema** is flagged. The production baseline should test whether PostGIS can be installed into a non-exposed schema with the required geography types/operators and all app SQL references adjusted. Do not relocate it without a clean-room extension test.
- **4 anon-executable SECURITY DEFINER warnings** include the app's public-ranking function and three extension-owned PostGIS `st_estimatedextent` overloads. Review public-ranking's returned fields and keep extension-owned grants distinct from app-owned function grants.
- **12 authenticated-executable SECURITY DEFINER warnings** include several app RPCs expected to be callable by the app. Review each body and explicitly grant only the needed signatures.
- **Anonymous sign-in warnings** are expected to need a product-aware decision because the Flutter app currently uses Supabase anonymous sign-in. Do not disable anonymous sign-in without replacing that session flow.
- **Leaked-password protection** was flagged in the advisor output; assess it for any password-based sign-in flow. The current inspected client flow is anonymous sign-in.

Performance advisor also marked 20 indexes as unused in the observed workload. Since this test database has modest usage and several indexes support foreign keys or future queries, do not delete them solely from this signal. Re-evaluate indexes after the new schema and representative workload tests.


## Event participation write path hardening

The Flutter client now calls `ensure_event_participation(p_event_id)` instead of directly inserting/updating `user_event_participations` with client-provided timestamps. The matching migration:

- derives the user ID from `auth.uid()`;
- rejects missing identity, missing event ID, and inactive/nonexistent events;
- writes `joined_at` and `updated_at` from database time;
- reactivates an existing row without resetting the original `joined_at`;
- revokes direct client INSERT/UPDATE/DELETE and grants only the authenticated RPC execution.

The function pins an empty `search_path` and schema-qualifies its relations. This migration is staged in GitHub and has not yet been applied to the closed-test or production database, so the matching app source must not be released until the migration is applied and verified in the target environment.


### Participation RPC validation result

The migration was executed inside an explicit transaction against the closed-test schema with a temporary authenticated-role context, then rolled back. The RPC returned successfully and the role could read its own participation row; a follow-up catalog check confirmed the function was absent after rollback. This validates SQL syntax and the happy path without persisting schema/data changes. Negative tests (unauthenticated, inactive/missing event, cross-user access, direct writes after migration) remain required before applying the migration.

A second rollback-only privilege check also passed: `authenticated` can execute the RPC, `anon` cannot, and `authenticated` has no direct INSERT/UPDATE/DELETE privileges on `user_event_participations`. No schema or row changes were persisted.
