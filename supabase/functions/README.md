# Supabase Edge Function deployment notes

Production maintenance functions are intentionally not deployed until their secrets have been rotated/configured and the Deno checks pass.

| Function | Required secret | Request header | Gateway JWT |
|---|---|---|---|
| `import-roadside-station-registry` | `ROADSIDESTATION_IMPORT_KEY` | `x-import-key` | Enable |
| `enrich-roadside-station-gps` | `ROADSIDESTATION_GPS_ENRICH_KEY` | `x-import-key` | Enable |
| `reconcile-roadside-station-gps` | `ROADSIDESTATION_GPS_RECONCILE_KEY` | `x-import-key` | Enable |

## Maintenance safeguards

- All maintenance endpoints accept POST only (OPTIONS is supported for CORS) and fail closed with HTTP 503 if their required secret is missing.
- Rotate the old hardcoded keys used by deployed closed-test versions. Removing literals from the repository does not rotate the deployed key or remove it from Git history.
- GPS enrichment/reconciliation run in **dry-run mode by default**. The request body must explicitly include `{"apply":true}` to persist candidate-coordinate updates. Use a valid JWT plus the corresponding secret header when deploying with gateway JWT verification enabled.
- GPS candidates are range-checked, ambiguous station matches are skipped, and reconciliation merges its audit metadata rather than overwriting existing metadata.
- Registry replacement goes through the service-role-only `replace_roadside_station_registry(jsonb)` RPC. It validates the full 1,234-row payload and performs upsert/stale-row removal atomically.
- `verify-roadside-station-gsi` in the closed-test project is currently only a minimal health response, not a full validation workflow. Do not treat it as evidence that station coordinates have been verified.
- Production currently has only `delete-account` deployed (version 2, gateway JWT verification enabled). The three maintenance functions above are not deployed to production.

Before any maintenance deployment:
1. Set/rotate all three secrets in Supabase Dashboard → Edge Functions → Secrets.
2. Pass the repository's Supabase Security Source Check, including Deno type checks.
3. Test missing-secret, invalid-key, non-POST, dry-run, and explicit-apply behavior against a non-production project.
4. Confirm the live registry count and expected updated-row count before any apply run.
