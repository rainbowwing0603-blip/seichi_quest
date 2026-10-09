# Supabase Edge Function deployment notes

Production maintenance functions are intentionally not deployed until their secrets have been rotated/configured and the Deno checks pass.

| Function | Required secret | Request header | Gateway JWT |
|---|---|---|---|
| `import-roadside-station-registry` | `ROADSIDESTATION_IMPORT_KEY_V2` | `x-import-key` | Enable |
| `enrich-roadside-station-gps` | `ROADSIDESTATION_GPS_ENRICH_KEY_V2` | `x-import-key` | Enable |
| `reconcile-roadside-station-gps` | `ROADSIDESTATION_GPS_RECONCILE_KEY_V2` | `x-import-key` | Enable |

## Maintenance safeguards

- All maintenance endpoints reject methods other than POST and fail closed with HTTP 503 if their required secret is missing. The two GPS endpoints also support OPTIONS for CORS; the registry importer is intended for server-side maintenance calls.
- The closed-test maintenance functions have been redeployed with new V2 secret names and gateway JWT verification. Active versions are importer v12, GPS enrichment v16, and GPS reconciliation v2. The old hardcoded keys are considered compromised because they existed in deployed source and Git history. The new V2 secret names are not inferred from those old keys; configure independently generated values before using maintenance operations. Until the V2 secrets are present, each function fails closed with HTTP 503. These three maintenance functions are not deployed to production.
- GPS enrichment/reconciliation run in **dry-run mode by default**. The request body must explicitly include `{"apply":true}` to persist candidate-coordinate updates. Use a valid JWT plus the corresponding secret header when deploying with gateway JWT verification enabled.
- GPS candidates are range-checked, ambiguous station matches are skipped, and reconciliation merges its audit metadata rather than overwriting existing metadata.
- Registry replacement goes through the service-role-only `replace_roadside_station_registry(jsonb)` RPC. It validates the full 1,234-row payload and performs upsert/stale-row removal atomically.
- `verify-roadside-station-gsi` in the closed-test project is currently only a minimal health response, not a full validation workflow. Do not treat it as evidence that station coordinates have been verified.
- Production currently has only `delete-account` deployed (version 2, gateway JWT verification enabled). The three maintenance functions above are not deployed to production.

Before enabling or using maintenance operations:
1. Set independently generated V2 values for all three secrets in Supabase Dashboard → Edge Functions → Secrets. Deployment does not create or rotate secrets.
2. Keep the repository's Supabase Security Source Check and Deno type checks passing.
3. Exercise missing-secret, invalid-key, non-POST, dry-run, and explicit-apply behavior against a non-production project. The deployment connector cannot invoke endpoints or manage secrets, so this runtime check remains outstanding.
4. Confirm the live registry count and expected updated-row count before any apply run.
