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
        .where(_isRenderable)
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

  bool _isRenderable(ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.text:
        return block.body?.isNotEmpty ?? false;
      case ContentBlockType.image:
        return _mediaResolver.resolve(block.mediaPath)?.isNotEmpty ?? false;
      case ContentBlockType.link:
        return _validLinkUri(block.linkUrl) != null;
      case ContentBlockType.unsupported:
        return false;
    }
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

    final presentation = _textPresentationFor(block.role);

    return _buildSection(
      context,
      title: block.title,
      leadingIcon: presentation.icon,
      accentColor: presentation.accentColor,
      emphasized: presentation.emphasized,
      child: Text(
        body,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: block.role == 'reading' ? 1.8 : 1.7,
          fontWeight: block.role == 'reading' ? FontWeight.w700 : null,
        ),
      ),
    );
  }

  _ContentTextPresentation _textPresentationFor(String role) {
    switch (role) {
      case 'reading':
        return const _ContentTextPresentation(
          icon: Icons.format_quote_rounded,
          accentColor: Color(0xFF5968E8),
          emphasized: true,
        );
      case 'field_guide':
        return const _ContentTextPresentation(
          icon: Icons.explore_rounded,
          accentColor: Color(0xFF167B9B),
          emphasized: true,
        );
      case 'history':
        return const _ContentTextPresentation(
          icon: Icons.account_balance_rounded,
          accentColor: Color(0xFF8A5A2B),
        );
      case 'description':
      case 'about':
        return const _ContentTextPresentation(
          icon: Icons.menu_book_rounded,
          accentColor: Color(0xFF5968E8),
        );
      default:
        return const _ContentTextPresentation();
    }
  }

  Widget _buildImageBlock(BuildContext context, ContentBlock block) {
    final imageUrl = _mediaResolver.resolve(block.mediaPath);

    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final caption = block.body;
    final isHero = block.role == 'hero';

    return _buildSection(
      context,
      title: block.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(isHero ? 20 : 16),
            child: AspectRatio(
              aspectRatio: _aspectRatioFor(block),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: _imageFitFor(block),
                semanticLabel: block.altText,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
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

  BoxFit _imageFitFor(ContentBlock block) {
    switch (block.role) {
      case 'picture_card':
      case 'reading_card':
      case 'product':
        return BoxFit.contain;
      default:
        return BoxFit.cover;
    }
  }

  double _aspectRatioFor(ContentBlock block) {
    final configured = block.metadata['aspect_ratio'];

    if (configured is num && configured > 0) {
      return configured.toDouble();
    }

    switch (block.role) {
      case 'hero':
        return 16 / 9;
      case 'picture_card':
      case 'reading_card':
        return 4 / 3;
      case 'product':
        return 1;
      default:
        return 4 / 3;
    }
  }

  Widget _buildLinkBlock(BuildContext context, ContentBlock block) {
    final uri = _validLinkUri(block.linkUrl);

    if (uri == null) {
      return const SizedBox.shrink();
    }

    final linkUrl = block.linkUrl!.trim();

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

  Uri? _validLinkUri(String? value) {
    final linkUrl = value?.trim();

    if (linkUrl == null || linkUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(linkUrl);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }

    return uri;
  }

  Widget _buildSection(
    BuildContext context, {
    required String? title,
    required Widget child,
    IconData? leadingIcon,
    Color? accentColor,
    bool emphasized = false,
  }) {
    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty) ...[
          Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  size: 19,
                  color: accentColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    );

    if (!emphasized) {
      return section;
    }

    final color = accentColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: section,
    );
  }
}

class _ContentTextPresentation {
  const _ContentTextPresentation({
    this.icon,
    this.accentColor,
    this.emphasized = false,
  });

  final IconData? icon;
  final Color? accentColor;
  final bool emphasized;
}
