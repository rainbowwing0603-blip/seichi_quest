# Production Android artifact build

This workflow builds a signed production AAB for review only. It does **not** upload to Google Play, change a release track, or update `app_release_policies`.

Workflow: `.github/workflows/production-android-build.yml`

**Dispatch prerequisite:** GitHub only accepts `workflow_dispatch` for workflows present on the repository's default branch. This PR currently targets `feature/android-next-release`, so the workflow will not be manually runnable until the same reviewed workflow file is also present on the default branch. Once that prerequisite is met, select `feature/android-next-release` as the run ref; the workflow rejects other refs. Do not merge to the default branch or publish a release without the normal review/approval.

## Required GitHub Environment configuration

Create or verify the GitHub Environment named `production`. Store credentials there, never in repository files or workflow inputs.

- Variable `SUPABASE_URL`: exactly `https://npirfaoxcarfuqjlwgav.supabase.co`.
- Secret `SUPABASE_PUBLISHABLE_KEY`: the production project's publishable key. Do not use the closed-test project's key.
- Secret `ANDROID_KEYSTORE_BASE64`: base64 encoding of the existing Google Play upload keystore. It must be the same signing identity used for the app's existing Play listing.
- Secret `ANDROID_KEYSTORE_PASSWORD`.
- Secret `ANDROID_KEY_ALIAS`.
- Secret `ANDROID_KEY_PASSWORD`.
- Secret `GOOGLE_MAPS_API_KEY`: production Android Maps key, restricted to the production package and signing certificate where applicable.
- Secret `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID`: the production Android rewarded-ad unit ID for the one-hour story preview. Do not use a test ad unit in release builds.

Do not add a service-account publishing credential to this workflow. It intentionally has no Play publishing step.

## Before running

1. Confirm the production Environment's required variables/secrets exist without displaying their values.
2. In Play Console, check the highest version code already used by any uploaded bundle. Enter a **higher, unused** positive integer as `build_number`. The workflow deliberately does not guess or reserve a Play version code.
3. First confirm the workflow file exists on the repository's default branch (see dispatch prerequisite above). Then dispatch it from the reviewed `feature/android-next-release` branch. The workflow enforces this branch guard; the selected ref is the code that gets built.
4. Confirm reviewed migration `20261009164000_grant_story_preview_server_time.sql` has been applied to production and its authenticated RPC access has been verified.
5. Wait for analyze, tests, and the signed AAB build to finish.
6. Download the artifact and verify `app-release.aab.sha256` before transferring it.
7. Install/test the artifact in a controlled environment before any store upload.

## Important limitations

- A successful CI build proves the artifact can be produced; it does not prove production anonymous sign-in, GPS collection, ads, account deletion, or data isolation works on a device.
- The workflow guards against the known closed-test URL/key, but the publishable key must still be verified in the protected GitHub Environment.
- The rewarded-ad story preview feature is being developed separately. This workflow now passes its Android production ad-unit ID when building the release AAB; the GitHub Environment secret must be configured before the build can run successfully.
- The AAB artifact is retained for seven days. No store publication is performed.
- Do not populate `app_release_policies` until the actual release build number and public store URL are confirmed.
- Do not test account deletion with a real user's account. Use a disposable production test account only after confirming that its records can safely be deleted.
