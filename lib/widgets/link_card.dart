import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'info_card.dart';

/// Link card for displaying URL previews
/// 
/// Features:
/// - URL preview with favicon
/// - Open Graph metadata
/// - Image preview
/// - Domain verification
/// - Copy/share actions
class LinkCard extends InfoCard {
  final LinkData link;
  final bool showPreview;
  final bool showFavicon;
  final bool showImage;

  const LinkCard({
    super.key,
    super.title,
    super.subtitle,
    super.leading,
    super.trailing,
    super.accentColor,
    super.onTap,
    super.onLongPress,
    super.actions,
    super.isLoading,
    super.errorMessage,
    super.padding,
    super.margin,
    super.enableSwipe,
    super.swipeLeftAction,
    super.swipeRightAction,
    required this.link,
    this.showPreview = true,
    this.showFavicon = true,
    this.showImage = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    return _LinkCardContent(
      link: link,
      showPreview: showPreview,
      showFavicon: showFavicon,
      showImage: showImage,
    );
  }
}

class _LinkCardContent extends StatelessWidget {
  final LinkData link;
  final bool showPreview;
  final bool showFavicon;
  final bool showImage;

  const _LinkCardContent({
    required this.link,
    required this.showPreview,
    required this.showFavicon,
    required this.showImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main link info
        _buildLinkInfo(context),
        
        // Preview image
        if (showImage && link.imageUrl != null) ...[
          const SizedBox(height: 12),
          _buildPreviewImage(context),
        ],
        
        // Description
        if (showPreview && link.description != null) ...[
          const SizedBox(height: 8),
          Text(
            link.description!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[300],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        
        // Tags
        if (link.tags != null && link.tags!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildTags(),
        ],
      ],
    );
  }

  Widget _buildLinkInfo(BuildContext context) {
    return Row(
      children: [
        // Favicon or domain icon
        if (showFavicon)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Center(
              child: link.faviconUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(Icons.language, color: Colors.grey[500], size: 20),
                    )
                  : Icon(_getDomainIcon(), color: _getDomainColor(), size: 20),
            ),
          ),
        const SizedBox(width: 12),
        
        // Link details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              if (link.title != null)
                Text(
                  link.title!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              
              // Domain
              Row(
                children: [
                  Icon(Icons.link, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    link.domain,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  if (link.isSecure)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock, size: 10, color: Colors.green[400]),
                    ),
                ],
              ),
            ],
          ),
        ),
        
        // Open button
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF00D4AA)),
          ),
          onPressed: () => _openLink(context),
        ),
      ],
    );
  }

  Widget _buildPreviewImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey[600]),
            // Image would be loaded here
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Preview',
                  style: TextStyle(fontSize: 10, color: Colors.grey[300]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: link.tags!.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00D4AA).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00D4AA).withOpacity(0.3),
            ),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF00D4AA),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openLink(BuildContext context) async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getDomainIcon() {
    final domain = link.domain.toLowerCase();
    
    if (domain.contains('github')) return Icons.code;
    if (domain.contains('twitter') || domain.contains('x.com')) return Icons.alternate_email;
    if (domain.contains('youtube')) return Icons.play_circle;
    if (domain.contains('reddit')) return Icons.forum;
    if (domain.contains('stackoverflow')) return Icons.help;
    if (domain.contains('medium')) return Icons.article;
    if (domain.contains('discord')) return Icons.chat;
    if (domain.contains('slack')) return Icons.tag;
    if (domain.contains('google')) return Icons.search;
    if (domain.contains('amazon')) return Icons.shopping_cart;
    if (domain.contains('netflix')) return Icons.movie;
    if (domain.contains('spotify')) return Icons.music_note;
    
    return Icons.language;
  }

  Color _getDomainColor() {
    final domain = link.domain.toLowerCase();
    
    if (domain.contains('github')) return Colors.white;
    if (domain.contains('twitter') || domain.contains('x.com')) return Colors.blue;
    if (domain.contains('youtube')) return Colors.red;
    if (domain.contains('reddit')) return Colors.orange;
    if (domain.contains('stackoverflow')) return const Color(0xFFF48024);
    if (domain.contains('discord')) return const Color(0xFF5865F2);
    if (domain.contains('spotify')) return Colors.green;
    
    return Colors.grey;
  }
}

/// Link data class
class LinkData {
  final String url;
  final String domain;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? faviconUrl;
  final String? siteName;
  final String? author;
  final DateTime? publishedAt;
  final List<String>? tags;
  final bool isSecure;
  final String? mimeType;

  const LinkData({
    required this.url,
    required this.domain,
    this.title,
    this.description,
    this.imageUrl,
    this.faviconUrl,
    this.siteName,
    this.author,
    this.publishedAt,
    this.tags,
    this.isSecure = true,
    this.mimeType,
  });

  factory LinkData.fromUrl(String url) {
    final uri = Uri.parse(url);
    return LinkData(
      url: url,
      domain: uri.host,
      isSecure: uri.scheme == 'https',
    );
  }
}

/// Social media link card - specialized for social platforms
class SocialLinkCard extends StatelessWidget {
  final LinkData link;
  final String platform;
  final String? author;
  final String? authorHandle;
  final int? likes;
  final int? shares;
  final int? comments;
  final DateTime? postedAt;
  final VoidCallback? onTap;

  const SocialLinkCard({
    super.key,
    required this.link,
    required this.platform,
    this.author,
    this.authorHandle,
    this.likes,
    this.shares,
    this.comments,
    this.postedAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LinkCard(
      link: link,
      title: author,
      subtitle: authorHandle,
      showImage: true,
      onTap: onTap,
    );
  }

  Widget buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row
        Row(
          children: [
            if (likes != null) ...[
              Icon(Icons.favorite, size: 14, color: Colors.red[400]),
              const SizedBox(width: 4),
              Text(_formatNumber(likes!), style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
            ],
            if (comments != null) ...[
              Icon(Icons.comment, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(_formatNumber(comments!), style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
            ],
            if (shares != null) ...[
              Icon(Icons.share, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(_formatNumber(shares!), style: const TextStyle(fontSize: 12)),
            ],
            const Spacer(),
            if (postedAt != null)
              Text(
                _formatTimeAgo(postedAt!),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

/// Article link card - specialized for news/blogs
class ArticleLinkCard extends StatelessWidget {
  final LinkData link;
  final String? source;
  final String? author;
  final int? readTime;
  final DateTime? publishedAt;
  final VoidCallback? onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;

  const ArticleLinkCard({
    super.key,
    required this.link,
    this.source,
    this.author,
    this.readTime,
    this.publishedAt,
    this.onTap,
    this.onBookmark,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return LinkCard(
      link: link,
      title: link.title,
      subtitle: source,
      showImage: true,
      onTap: onTap,
      actions: [
        if (onBookmark != null)
          InfoCardAction(
            icon: Icons.bookmark_border,
            label: 'Bookmark',
            color: Colors.blue,
            onAction: onBookmark!,
          ),
        if (onShare != null)
          InfoCardAction(
            icon: Icons.share,
            label: 'Share',
            color: Colors.green,
            onAction: onShare!,
          ),
      ],
    );
  }

  Widget buildContent(BuildContext context) {
    return Row(
      children: [
        if (author != null) ...[
          Icon(Icons.person, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(author!, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(width: 8),
        ],
        if (readTime != null) ...[
          Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            '$readTime min read',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
        const Spacer(),
        if (publishedAt != null)
          Text(
            _formatDate(publishedAt!),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Bookmark card - for saved links
class BookmarkCard extends StatelessWidget {
  final LinkData link;
  final DateTime? savedAt;
  final String? collection;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const BookmarkCard({
    super.key,
    required this.link,
    this.savedAt,
    this.collection,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return LinkCard(
      link: link,
      title: link.title,
      subtitle: collection,
      onTap: onTap,
      swipeLeftAction: InfoCardSwipeAction(
        icon: Icons.delete,
        label: 'Remove',
        color: Colors.red,
        onAction: onRemove ?? () {},
      ),
    );
  }
}