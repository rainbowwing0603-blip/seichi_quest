# Production app release policy

The production database currently has **no active Android or iOS release-policy rows**. This is intentional until the matching production build is signed, uploaded, and has a real store listing.

The Flutter client reads `app_release_policies` by platform. A missing row is fail-open: it does not force an update. Add a row only when the production release is ready.

## Values to confirm per platform

- `platform`: exactly `android` or `ios`.
- `latest_build`: numeric build number embedded in the production binary actually published to that store. Do not copy the closed-test build/version settings.
- `minimum_build`: lowest build that the backend will allow to continue. Must be greater than zero and no greater than `latest_build`. For the first release, use the same value as `latest_build` unless a deliberate compatibility policy says otherwise.
- `latest_version`: user-visible version of that exact binary, e.g. `1.0.0` only if that is what was shipped.
- `store_url`: the real public listing URL for that platform, not a placeholder or a closed-test invite URL.
- `update_message`: optional localized message shown by the app.
- `is_active`: set true only when the row should govern clients.

Do not confuse a Google Play testing-track release number with Android's `versionCode`. Use the value embedded in the actual production AAB/APK.

## Safe write procedure

1. Confirm the production build command uses `APP_ENV=production`, the production Supabase URL, and the production publishable key supplied through the local environment. Never put keys in Git or chat.
2. Confirm the published Android/iOS build number and version from the store's release details.
3. Confirm the public store listing URL works for a user who is not in the testing track.
4. Review the intended row values with the release owner.
5. Use a privileged database session and one transaction. Upsert one platform at a time, validate the resulting row, and commit only after all values match the shipped binary.

Example shape only; replace every uppercase placeholder after verification. Do not execute this example as written:

```sql
BEGIN;
INSERT INTO public.app_release_policies
  (platform, latest_build, minimum_build, latest_version, store_url, update_message, is_active, updated_at)
VALUES
  ('android', ANDROID_BUILD_NUMBER, MINIMUM_SUPPORTED_BUILD,
   'SHIPPED_VERSION', 'PUBLIC_PLAY_STORE_LISTING_URL',
   'OPTIONAL_UPDATE_MESSAGE', true, now())
ON CONFLICT (platform) DO UPDATE SET
  latest_build = EXCLUDED.latest_build,
  minimum_build = EXCLUDED.minimum_build,
  latest_version = EXCLUDED.latest_version,
  store_url = EXCLUDED.store_url,
  update_message = EXCLUDED.update_message,
  is_active = EXCLUDED.is_active,
  updated_at = now();
SELECT * FROM public.app_release_policies WHERE platform = 'android';
-- COMMIT only after reviewing the selected row; otherwise ROLLBACK.
```

Repeat with `ios` only after an iOS production build and public App Store listing exist. Keep the policy inactive or absent until then. The current database state (0 rows) is correct for the pre-release stage.
