import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_block.dart';
import '../services/content_media_resolver.dart';

class ContentBlockRenderer extends StatelessWidget {
  ContentBlockRenderer({
    super.key,
    required this.blocks,
    ContentMediaResolver? mediaResolver,
  }) : _mediaResolver = mediaResolver ?? ContentMediaResolver();

  final List<ContentBlock> blocks;
  final ContentMediaResolver _mediaResolver;

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
    final imageUrl = _mediaResolver.resolve(block.mediaPath);

    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final caption = block.body;

    return _buildSection(
      context,
      title: block.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              semanticLabel: block.altText,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkBlock(BuildContext context, ContentBlock block) {
    final linkUrl = block.linkUrl?.trim();

    if (linkUrl == null || linkUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final uri = Uri.tryParse(linkUrl);
    final canOpen =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (!canOpen) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      context,
      title: block.title,
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(block.body ?? linkUrl),
        ),
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
