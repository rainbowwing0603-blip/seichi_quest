class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.publishFrom,
    required this.showOnStartup,
    required this.isRead,
    this.eventId,
    this.publishUntil,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final int priority;
  final String? eventId;
  final DateTime publishFrom;
  final DateTime? publishUntil;
  final bool showOnStartup;
  final bool isRead;

  factory Announcement.fromMap(
    Map<String, dynamic> map, {
    required bool isRead,
  }) {
    return Announcement(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      category: map['category'] as String? ?? 'general',
      priority: map['priority'] as int? ?? 0,
      eventId: map['event_id'] as String?,
      publishFrom: DateTime.parse(map['publish_from'] as String),
      publishUntil: map['publish_until'] == null
          ? null
          : DateTime.parse(map['publish_until'] as String),
      showOnStartup: map['show_on_startup'] as bool? ?? false,
      isRead: isRead,
    );
  }

  Announcement copyWith({bool? isRead}) {
    return Announcement(
      id: id,
      title: title,
      body: body,
      category: category,
      priority: priority,
      eventId: eventId,
      publishFrom: publishFrom,
      publishUntil: publishUntil,
      showOnStartup: showOnStartup,
      isRead: isRead ?? this.isRead,
    );
  }
}
