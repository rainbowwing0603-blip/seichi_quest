# Production app-release policy setup

`app_release_policies` is intentionally not copied from the closed-test database. The closed-test release number/build configuration must not silently become the production rollout policy.

Before publishing the first production build:

1. Confirm the actual Android `versionCode` and `versionName` from the release AAB that will be uploaded.
2. Choose `minimum_build` based on the oldest production build that is still supported. Do not infer this from the closed-test release number.
3. Set `store_url` to the real Google Play listing URL.
4. Insert/update the `platform = 'android'` row in `public.app_release_policies` using a privileged deployment session.
5. Verify the row through the app's release-policy query and confirm clients cannot update it.

Example template, **not executable until every placeholder is replaced and reviewed**:

```sql
INSERT INTO public.app_release_policies
  (platform, latest_build, minimum_build, latest_version, store_url, update_message, is_active, updated_at)
VALUES
  ('android', <ACTUAL_PRODUCTION_VERSION_CODE>, <MINIMUM_SUPPORTED_VERSION_CODE>,
   '<ACTUAL_VERSION_NAME>', '<ACTUAL_PLAY_STORE_URL>', '最新版をご利用ください。', true, now())
ON CONFLICT (platform) DO UPDATE SET
  latest_build = EXCLUDED.latest_build,
  minimum_build = EXCLUDED.minimum_build,
  latest_version = EXCLUDED.latest_version,
  store_url = EXCLUDED.store_url,
  update_message = EXCLUDED.update_message,
  is_active = EXCLUDED.is_active,
  updated_at = now();
```

The table is readable to anon/authenticated only while `is_active = true`; all writes remain server/admin-only.
