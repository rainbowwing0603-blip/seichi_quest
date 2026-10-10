/// Pure time policy for temporary story previews granted by rewarded ads.
abstract final class StoryPreviewAccessPolicy {
  static const Duration accessDuration = Duration(hours: 1);

  static DateTime expiresAt(DateTime serverNow) =>
      serverNow.toUtc().add(accessDuration);

  static bool isActive({
    required DateTime? expiresAt,
    required DateTime serverNow,
  }) {
    final expiry = expiresAt?.toUtc();
    return expiry != null && expiry.isAfter(serverNow.toUtc());
  }
}
