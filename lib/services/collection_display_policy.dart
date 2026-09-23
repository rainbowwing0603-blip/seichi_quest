class CollectionDisplayPolicy {
  const CollectionDisplayPolicy();

  Map<String, Set<String>> eventNamesByCard(
    List<Map<String, dynamic>> history,
  ) {
    final result = <String, Set<String>>{};

    for (final item in history) {
      final card = item['card']?.toString();
      final eventName = item['event_name']?.toString();

      if (card == null ||
          card.isEmpty ||
          eventName == null ||
          eventName.isEmpty) {
        continue;
      }

      result.putIfAbsent(card, () => <String>{}).add(eventName);
    }

    return result;
  }
}
