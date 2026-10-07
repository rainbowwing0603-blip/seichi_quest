# Story preview rewarded ads

Users explicitly opt in and earn a one-hour preview of eligible current content after the SDK reward callback. Only after_collection description/history/field_guide/story blocks are eligible. Stamps, achievements, cards and hidden blocks are unaffected.

Expiry is checked against the authenticated Supabase server clock on reopen/resume and every minute. Communication failure closes the preview. The entitlement is stored per account/content on this device and is not synchronized to other devices.

## Ad IDs and build configuration

Debug/Profile builds use Google test rewarded IDs.

Release Android builds use `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID` passed through `--dart-define`. The current Android production rewarded unit is configured for the build workflow. The application does not display the preview button when a Release build has no Rewarded ID.

Create and use a separate Rewarded unit in AdMob. Do not reuse banner or interstitial IDs.

## Release incident and prevention

Version 16 was released to the Alpha test track, but its GitHub Actions build log showed an empty `STORY_REWARDED_AD_UNIT_ID`. Consequently the Release AAB did not have the Android Rewarded unit ID and the UI correctly hid the preview button.

Version 17 changes the Google Play Test Release workflow so that the Android Rewarded unit ID is resolved from GitHub variable/secret configuration, falls back to the configured production unit when the repository configuration is absent, and fails the build if the final value is empty.

The intended verification for Version 17 is:
1. Build succeeds and logs `Rewarded story ad unit configured.`
2. AAB versionCode is 17.
3. On an uncollected spot with eligible story content, `広告を見て物語を1時間読む` is visible.
4. Tapping it displays the Rewarded Ad.
5. Completing the ad grants one hour only.
6. The preview expires after one hour and does not grant a stamp.

## Security / product boundary

The reward uses the SDK client callback, not AdMob server-side verification. Local entitlement storage is not tamper-proof. This is an optional content preview, not a secure paywall or financial entitlement.

Rewarded ads share the full-screen lock and postpone automatic interstitials for the normal interval after display.
