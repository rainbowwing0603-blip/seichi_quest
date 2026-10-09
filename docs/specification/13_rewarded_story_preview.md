# Rewarded story preview

## User experience

- Basic spot information remains available without an ad.
- A user who has not collected a spot may choose to watch a rewarded ad to unlock that spot's story for one hour.
- Access is granted only after the Google Mobile Ads SDK calls the earned-reward callback. Dismissing or failing to load the ad does not unlock content.
- Unlocks are scoped to the current authenticated user and content ID, and survive app restarts on the same installation. They are not synchronized across devices. A monotonic in-session timer hides preview-only content when the hour expires.
- Collecting the spot continues to provide permanent access according to the existing `after_collection` visibility mode.
- Blocks marked `hidden` remain hidden. Rewarded preview does not override the explicit hidden mode.

## Expiry and connectivity

- Expiry is stored locally, but validated against the Supabase `story_preview_server_time()` RPC rather than the device clock.
- The server-time RPC is used only when validating a previously stored expiry or granting a new unlock, not for every locked spot view.
- An unlock cannot be granted if the reward callback was not received, authentication is unavailable, the server-time call fails, or the expiry cannot be saved. The UI reports the failure instead of silently granting access.
- If the server cannot validate an existing expiry, the preview stays locked until validation can succeed.

## Ad unit configuration

- Debug/Profile use Google's official rewarded-ad test unit IDs.
- Android Release requires `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID` to be supplied as a Dart define.
- iOS Release requires `ADMOB_IOS_STORY_REWARDED_AD_UNIT_ID`; the iOS production build workflow must supply it before shipping this feature on iOS.
- Production CI must never fall back to Google's test unit IDs or a closed-test project key.

## Scope and limits

Content visibility is a client presentation rule, not a server-side entitlement boundary. The client downloads active content blocks and applies their `visibility` metadata. Do not store confidential or licensed-restricted material in public-readable blocks on the assumption that this rewarded-ad UI prevents direct API access.
