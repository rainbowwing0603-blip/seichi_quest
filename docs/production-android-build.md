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

Do not add a service-account publishing credential to this workflow. It intentionally has no Play publishing step.

## Before running

1. Confirm the production Environment's required variables/secrets exist without displaying their values.
2. In Play Console, check the highest version code already used by any uploaded bundle. Enter a **higher, unused** positive integer as `build_number`. The workflow deliberately does not guess or reserve a Play version code.
3. Dispatch this workflow only from the reviewed `feature/android-next-release` branch. The workflow enforces this branch guard; the workflow ref is the code that gets built.
4. Wait for analyze, tests, and the signed AAB build to finish.
5. Download the artifact and verify `app-release.aab.sha256` before transferring it.
6. Install/test the artifact in a controlled environment before any store upload.

## Important limitations

- A successful CI build proves the artifact can be produced; it does not prove production anonymous sign-in, GPS collection, ads, account deletion, or data isolation works on a device.
- The workflow guards against the known closed-test URL/key, but the publishable key must still be verified in the protected GitHub Environment.
- The AAB artifact is retained for seven days. No store publication is performed.
- Do not populate `app_release_policies` until the actual release build number and public store URL are confirmed.
- Do not test account deletion with a real user's account. Use a disposable production test account only after confirming that its records can safely be deleted.
