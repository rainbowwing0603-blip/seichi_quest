# Production Android artifact build

This workflow builds a signed production AAB for review only. It does **not** upload to Google Play, change a release track, or update `app_release_policies`.

Workflow: `.github/workflows/production-android-build.yml`

## Required GitHub Environment configuration

Create or verify the GitHub Environment named `production`. Store credentials there, never in repository files or workflow inputs.

- Variable `SUPABASE_URL`: exactly `https://npirfaoxcarfuqjlwgav.supabase.co`.
- Secret `SUPABASE_PUBLISHABLE_KEY`: the production project's publishable key. Do not use the closed-test project's key.
- Secret `ANDROID_KEYSTORE_BASE64`: base64 encoding of the existing Google Play upload keystore. It must be the same signing identity used for the app's existing Play listing.
- Secret `ANDROID_KEYSTORE_PASSWORD`.
- Secret `ANDROID_KEY_ALIAS`.
- Secret `ANDROID_KEY_PASSWORD`.
- Secret `GOOGLE_MAPS_API_KEY`: production Android Maps key, restricted to the production package and signing certificate where applicable.
- Variable `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID`: the production AdMob rewarded-ad unit used to unlock a spot's story for one hour. Do not use Google's test ad unit.

Do not add a service-account publishing credential to this workflow. It intentionally has no Play publishing step.

## Before running

1. Confirm the production Environment's required variables/secrets exist without displaying their values.
2. The closed-test release has already used versionCode `20`. The workflow rejects `build_number` values of `20` or lower. Still check Play Console for the highest version code used by any uploaded bundle and enter a **higher, unused** positive integer. The workflow does not guess or reserve a Play version code.
3. Dispatch this workflow only from the reviewed `feature/android-next-release` branch. The workflow enforces this branch guard; the workflow ref is the code that gets built.
4. Production migration history already records `20261010080644_grant_story_preview_server_time` and `20261010100000_reconcile_production_security`. The follow-up `20261010100001_grant_story_preview_server_time_after_reconcile.sql` is still pending in migration history. A read-only production privilege check currently confirms that `authenticated` can execute `public.story_preview_server_time()` and `anon` cannot. Before shipping, apply the pending migration through the repository's normal Supabase CLI migration workflow so production migration history stays aligned, then repeat the privilege check.
5. Wait for analyze, tests, and the signed AAB build to finish.
6. Download the artifact and verify `app-release.aab.sha256` before transferring it.
7. Install/test the artifact in a controlled environment before any store upload.

## Important limitations

- A successful CI build proves the artifact can be produced; it does not prove production anonymous sign-in, GPS collection, ads, account deletion, or data isolation works on a device.
- The workflow guards against the known closed-test URL/key, but the publishable key must still be verified in the protected GitHub Environment.
- The AAB artifact is retained for seven days. No store publication is performed.
- Do not populate `app_release_policies` until the actual release build number and public store URL are confirmed.
- Do not test account deletion with a real user's account. Use a disposable production test account only after confirming that its records can safely be deleted.
