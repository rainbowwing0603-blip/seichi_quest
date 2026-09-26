import '../models/quest_item.dart';

/// Decides how generic quest content should be presented without teaching the
/// UI about a specific event genre such as karuta, stores, castles, or anime.
class QuestItemPresentation {
  const QuestItemPresentation({
    required this.hasPrimaryImage,
    required this.revealPrimaryImage,
    required this.showLockedPlaceholder,
  });

  final bool hasPrimaryImage;
  final bool revealPrimaryImage;
  final bool showLockedPlaceholder;
}

class QuestPresentationPolicy {
  const QuestPresentationPolicy();

  QuestItemPresentation forItem(
    QuestItem item, {
    required bool collected,
  }) {
    final imageUrl = item.primaryImageUrl?.trim();
    final hasPrimaryImage = imageUrl != null && imageUrl.isNotEmpty;

    return QuestItemPresentation(
      hasPrimaryImage: hasPrimaryImage,
      revealPrimaryImage: collected && hasPrimaryImage,
      showLockedPlaceholder: !collected,
    );
  }
}
