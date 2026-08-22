class StampHistoryEntry {
  final String seichiId;
  final DateTime collectedAt;

  const StampHistoryEntry({
    required this.seichiId,
    required this.collectedAt,
  });
}

class StampHistoryPlace {
  final String card;
  final String name;
  final String icon;

  const StampHistoryPlace({
    required this.card,
    required this.name,
    required this.icon,
  });
}
