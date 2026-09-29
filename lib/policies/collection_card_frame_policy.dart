import '../models/event.dart';

/// Event art is selected outside the shared card renderer. New event frames
/// can be added here without branching the export or collection flow.
class CollectionCardFramePolicy {
  const CollectionCardFramePolicy();

  static const String defaultAsset = 'assets/collection_cards/travel_frame.png';

  static const Map<String, String> _assetsByEventSlug = {
    'jomo-karuta-gunma': 'assets/collection_cards/jomo_karuta_gunma_frame.png',
  };

  String assetFor(Event event) =>
      _assetsByEventSlug[event.slug] ?? defaultAsset;
}
