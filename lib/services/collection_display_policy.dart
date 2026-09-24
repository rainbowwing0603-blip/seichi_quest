class CollectionDisplayPolicy {
  const CollectionDisplayPolicy();

  Map<String, Set<String>> eventNamesByContentKey(
    List<Map<String, dynamic>> history,
  ) {
    final result = <String, Set<String>>{};

    for (final item in history) {
      final contentKey = item['content_key']?.toString();
      final eventName = item['event_name']?.toString();

      if (contentKey == null ||
          contentKey.isEmpty ||
          eventName == null ||
          eventName.isEmpty) {
        continue;
      }

      result.putIfAbsent(contentKey, () => <String>{}).add(eventName);
    }

    return result;
  }
}
