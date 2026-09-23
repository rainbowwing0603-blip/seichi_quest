enum ContentBlockType { text, image, link, unsupported }

class ContentBlock {
  final String id;
  final String contentId;
  final ContentBlockType type;
  final String role;
  final String? title;
  final String? body;
  final String? mediaPath;
  final String? altText;
  final String? linkUrl;
  final int displayOrder;
  final Map<String, dynamic> metadata;

  const ContentBlock({
    required this.id,
    required this.contentId,
    required this.type,
    required this.role,
    required this.title,
    required this.body,
    required this.mediaPath,
    required this.altText,
    required this.linkUrl,
    required this.displayOrder,
    required this.metadata,
  });

  factory ContentBlock.fromMap(Map<String, dynamic> map) {
    return ContentBlock(
      id: map['id']?.toString() ?? '',
      contentId: map['content_id']?.toString() ?? '',
      type: _parseType(map['block_type']),
      role: _normalizedRole(map['role']),
      title: _nullableText(map['title']),
      body: _nullableText(map['body']),
      mediaPath: _nullableText(map['media_path']),
      altText: _nullableText(map['alt_text']),
      linkUrl: _nullableText(map['link_url']),
      displayOrder: _toInt(map['display_order']),
      metadata: _toMetadata(map['metadata']),
    );
  }

  static ContentBlockType _parseType(dynamic value) {
    switch (value?.toString()) {
      case 'text':
        return ContentBlockType.text;
      case 'image':
        return ContentBlockType.image;
      case 'link':
        return ContentBlockType.link;
      default:
        return ContentBlockType.unsupported;
    }
  }

  static String _normalizedRole(dynamic value) {
    final role = value?.toString().trim();
    return role == null || role.isEmpty ? 'default' : role;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _toMetadata(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }
}
