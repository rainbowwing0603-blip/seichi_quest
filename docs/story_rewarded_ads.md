# Story preview rewarded ads

Users explicitly opt in and earn a one-hour preview of the current content after the SDK reward callback. Only after_collection description/history/field_guide/story blocks are eligible. Stamps, achievements, cards and hidden blocks are unaffected. Expiry is checked against the authenticated server clock on reopen/resume and every minute; communication failure closes the preview. The entitlement is stored per account/content on this device, not synchronized to other devices.

Debug builds use Google test rewarded IDs. Release builds require ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID or ADMOB_IOS_STORY_REWARDED_AD_UNIT_ID via --dart-define. Without the platform ID the button is hidden. Create a separate rewarded unit in AdMob; do not reuse banner/interstitial IDs. Set the stated reward to one story preview for one hour. No real rewarded ID has been configured yet.

The reward uses the SDK client callback, not AdMob server-side verification. Local entitlement storage is not tamper-proof; this is an optional content preview, not a secure paywall or financial entitlement. Rewarded ads share the full-screen lock and postpone automatic interstitials for the normal interval after display.
