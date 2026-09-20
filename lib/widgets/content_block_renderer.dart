import 'package:flutter/material.dart';

import '../models/content_block.dart';

class ContentBlockRenderer extends StatelessWidget {
  const ContentBlockRenderer({super.key, required this.blocks});

  final List<ContentBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final visibleBlocks = blocks
        .where((block) => block.type != ContentBlockType.unsupported)
        .toList(growable: false);

    if (visibleBlocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < visibleBlocks.length; index++) ...[
          if (index > 0) const SizedBox(height: 20),
          _buildBlock(context, visibleBlocks[index]),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.text:
        return _buildTextBlock(context, block);
      case ContentBlockType.image:
        return _buildImageBlock(context, block);
      case ContentBlockType.link:
        return _buildLinkBlock(context, block);
      case ContentBlockType.unsupported:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextBlock(BuildContext context, ContentBlock block) {
    final body = block.body;

    if (body == null || body.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      context,
      title: block.title,
      child: Text(
        body,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
      ),
    );
  }

  Widget _buildImageBlock(BuildContext context, ContentBlock block) {
    final mediaPath = block.mediaPath;

    if (mediaPath == null || mediaPath.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      context,
      title: block.title,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          mediaPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLinkBlock(BuildContext context, ContentBlock block) {
    final linkUrl = block.linkUrl;

    if (linkUrl == null || linkUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      context,
      title: block.title,
      child: SelectableText(
        linkUrl,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(decoration: TextDecoration.underline),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String? title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty) ...[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    );
  }
}
