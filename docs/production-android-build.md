# Production Android artifact build

This workflow builds a signed production AAB for review only. It does **not** upload to Google Play, change a release track, or update `app_release_policies`.

Workflow: `.github/workflows/production-android-build.yml`

**Dispatch status:** The workflow is now present on the repository's default branch (PR #26). In GitHub Actions, select `Production Android Build (Artifact Only)` and choose `feature/android-next-release` as the run ref. The workflow rejects other refs and only builds a signed AAB artifact; it does not upload or publish to Google Play.

## Required GitHub Environment configuration

Create or verify the GitHub Environment named `production`. Store credentials there, never in repository files or workflow inputs.

- Variable `SUPABASE_URL`: exactly `https://npirfaoxcarfuqjlwgav.supabase.co`.
- Secret `SUPABASE_PUBLISHABLE_KEY`: the production project's publishable key. Do not use the closed-test project's key.
- Secret `ANDROID_KEYSTORE_BASE64`: base64 encoding of the existing Google Play upload keystore. It must be the same signing identity used for the app's existing Play listing.
- Secret `ANDROID_KEYSTORE_PASSWORD`.
- Secret `ANDROID_KEY_ALIAS`.
- Secret `ANDROID_KEY_PASSWORD`.
- Secret `GOOGLE_MAPS_API_KEY`: production Android Maps key, restricted to the production package and signing certificate where applicable.
- Variable `ADMOB_ANDROID_BANNER_AD_UNIT_ID`: production Android banner ad unit ID.
- Variable `ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID`: production Android interstitial ad unit ID.
- Variable `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID`: production Android rewarded-ad unit ID for the one-hour story preview.

All three Android ad unit variables are validated before the build and passed to Flutter through `--dart-define`. The workflow rejects malformed IDs and Google's official test unit IDs.

Do not add a service-account publishing credential to this workflow. It intentionally has no Play publishing step.

## Before running

1. Confirm the production Environment's required variables/secrets exist without displaying their values.
2. The closed-test release already used versionCode `20`, and the workflow rejects `build_number` values of `20` or lower. In Play Console, check the highest version code used by any uploaded bundle and enter a **higher, unused** positive integer. The workflow deliberately does not guess or reserve a Play version code.
3. Dispatch it from the reviewed `feature/android-next-release` branch. The workflow enforces this branch guard; the selected ref is the code that gets built.
4. Production already records the grant as migration version `20261010080644` and the authenticated RPC privilege has been verified. The follow-up migration `20261010100001_grant_story_preview_server_time_after_reconcile.sql` is intentionally ordered after security reconciliation and must be applied through the normal migration workflow before release.
5. Wait for analyze, tests, and the signed AAB build to finish.
6. Download the artifact and verify `app-release.aab.sha256` before transferring it.
7. Install/test the artifact in a controlled environment before any store upload.

## Important limitations

- A successful CI build proves the artifact can be produced; it does not prove production anonymous sign-in, GPS collection, ads, account deletion, or data isolation works on a device.
- The workflow guards against the known closed-test URL/key, but the publishable key must still be verified in the protected GitHub Environment.
- The one-hour rewarded story preview is included on the release branch. All three Android ad unit variables listed above must be configured with production ad units before the build can run successfully.
- The AAB artifact is retained for seven days. No store publication is performed.
- Do not populate `app_release_policies` until the actual release build number and public store URL are confirmed.
- Do not test account deletion with a real user's account. Use a disposable production test account only after confirming that its records can safely be deleted.
