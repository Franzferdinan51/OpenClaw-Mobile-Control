import 'package:flutter/material.dart';
import 'info_card.dart';

/// Image card for displaying images and galleries
/// 
/// Features:
/// - Single image display
/// - Image galleries with swipe
/// - Zoom support
/// - Image metadata
/// - Download/share actions
class ImageCard extends InfoCard {
  final List<ImageData> images;
  final int initialIndex;
  final bool showGallery;
  final bool showIndicators;
  final bool showCounter;
  final bool enableZoom;
  final ImageCardLayout layout;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final Function(int index)? onImageTap;

  const ImageCard({
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
    required this.images,
    this.initialIndex = 0,
    this.showGallery = true,
    this.showIndicators = true,
    this.showCounter = true,
    this.enableZoom = true,
    this.layout = ImageCardLayout.single,
    this.onDownload,
    this.onShare,
    this.onImageTap,
  });

  @override
  Widget buildContent(BuildContext context) {
    return _ImageCardContent(
      images: images,
      initialIndex: initialIndex,
      showGallery: showGallery,
      showIndicators: showIndicators,
      showCounter: showCounter,
      enableZoom: enableZoom,
      layout: layout,
      onImageTap: onImageTap,
    );
  }
}

class _ImageCardContent extends StatefulWidget {
  final List<ImageData> images;
  final int initialIndex;
  final bool showGallery;
  final bool showIndicators;
  final bool showCounter;
  final bool enableZoom;
  final ImageCardLayout layout;
  final Function(int index)? onImageTap;

  const _ImageCardContent({
    required this.images,
    required this.initialIndex,
    required this.showGallery,
    required this.showIndicators,
    required this.showCounter,
    required this.enableZoom,
    required this.layout,
    this.onImageTap,
  });

  @override
  State<_ImageCardContent> createState() => _ImageCardContentState();
}

class _ImageCardContentState extends State<_ImageCardContent> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return _buildEmptyState();
    }

    switch (widget.layout) {
      case ImageCardLayout.single:
        return _buildSingleImage();
      case ImageCardLayout.gallery:
        return _buildGallery();
      case ImageCardLayout.grid:
        return _buildGrid();
      case ImageCardLayout.carousel:
        return _buildCarousel();
    }
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text('No images', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleImage() {
    final image = widget.images.first;
    return _ImageDisplay(
      image: image,
      enableZoom: widget.enableZoom,
      onTap: widget.onImageTap != null ? () => widget.onImageTap!(0) : null,
    );
  }

  Widget _buildGallery() {
    return Column(
      children: [
        // Main image
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return _ImageDisplay(
                image: widget.images[index],
                enableZoom: widget.enableZoom,
                onTap: widget.onImageTap != null 
                    ? () => widget.onImageTap!(index) 
                    : null,
              );
            },
          ),
        ),
        
        // Indicators
        if (widget.showIndicators && widget.images.length > 1) ...[
          const SizedBox(height: 12),
          _buildIndicators(),
        ],
        
        // Counter
        if (widget.showCounter && widget.images.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            '${_currentIndex + 1} / ${widget.images.length}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid() {
    final gridImages = widget.images.take(4).toList();
    final hasMore = widget.images.length > 4;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1,
      children: List.generate(gridImages.length, (index) {
        final image = gridImages[index];
        final isLast = index == 3 && hasMore;

        return GestureDetector(
          onTap: widget.onImageTap != null 
              ? () => widget.onImageTap!(index) 
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Placeholder
              Container(
                color: Colors.grey[850],
                child: Icon(
                  Icons.image,
                  size: 32,
                  color: Colors.grey[600],
                ),
              ),
              // Overlay for more images
              if (isLast)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Text(
                      '+${widget.images.length - 4}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.images.length - 1 ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: widget.onImageTap != null 
                  ? () => widget.onImageTap!(index) 
                  : null,
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image placeholder
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.image, size: 32, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    // Caption
                    if (image.caption != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          image.caption!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.images.length, (index) {
        final isActive = index == _currentIndex;
        return GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isActive 
                  ? const Color(0xFF00D4AA) 
                  : Colors.grey[700],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

/// Image display widget with zoom support
class _ImageDisplay extends StatefulWidget {
  final ImageData image;
  final bool enableZoom;
  final VoidCallback? onTap;

  const _ImageDisplay({
    required this.image,
    required this.enableZoom,
    this.onTap,
  });

  @override
  State<_ImageDisplay> createState() => _ImageDisplayState();
}

class _ImageDisplayState extends State<_ImageDisplay> {
  final TransformationController _transformController = TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image placeholder
            InteractiveViewer(
              transformationController: _transformController,
              onInteractionEnd: (details) {
                final scale = _transformController.value.getMaxScaleOnAxis();
                setState(() => _isZoomed = scale > 1.0);
              },
              minScale: 1.0,
              maxScale: 4.0,
              child: Container(
                color: Colors.grey[800],
                child: Center(
                  child: Icon(Icons.image, size: 48, color: Colors.grey[600]),
                ),
              ),
            ),
            
            // Caption overlay
            if (widget.image.caption != null && !_isZoomed)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.image.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            
            // Zoom indicator
            if (_isZoomed)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      _transformController.value = Matrix4.identity();
                      setState(() => _isZoomed = false);
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_out, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Reset',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Image card layout types
enum ImageCardLayout {
  single,
  gallery,
  grid,
  carousel,
}

/// Image data class
class ImageData {
  final String url;
  final String? thumbnailUrl;
  final String? caption;
  final String? altText;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? mimeType;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  const ImageData({
    required this.url,
    this.thumbnailUrl,
    this.caption,
    this.altText,
    this.width,
    this.height,
    this.sizeBytes,
    this.mimeType,
    this.createdAt,
    this.metadata,
  });

  String get sizeFormatted {
    if (sizeBytes == null) return '';
    if (sizeBytes! >= 1024 * 1024) {
      return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (sizeBytes! >= 1024) {
      return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '$sizeBytes B';
  }

  String get dimensionsFormatted {
    if (width == null || height == null) return '';
    return '${width}x$height';
  }
}

/// Avatar card - specialized for profile images
class AvatarCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? subtitle;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double size;

  const AvatarCard({
    super.key,
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.backgroundColor,
    this.onTap,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final color = backgroundColor ?? _getColorForName(name);
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size / 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Color _getColorForName(String name) {
    const colors = [
      Color(0xFF00D4AA),
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.red,
    ];
    
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    return colors[hash.abs() % colors.length];
  }
}

/// Screenshot card - specialized for captured screens
class ScreenshotCard extends StatelessWidget {
  final ImageData screenshot;
  final String? deviceName;
  final DateTime? capturedAt;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  const ScreenshotCard({
    super.key,
    required this.screenshot,
    this.deviceName,
    this.capturedAt,
    this.onTap,
    this.onDownload,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ImageCard(
      images: [screenshot],
      title: deviceName != null ? 'Screenshot - $deviceName' : 'Screenshot',
      subtitle: capturedAt != null ? _formatTime(capturedAt!) : null,
      layout: ImageCardLayout.single,
      onTap: onTap,
      actions: [
        if (onDownload != null)
          InfoCardAction(
            icon: Icons.download,
            label: 'Download',
            color: Colors.blue,
            onAction: onDownload!,
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

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Photo gallery card - specialized for photo collections
class PhotoGalleryCard extends StatelessWidget {
  final String title;
  final List<ImageData> photos;
  final DateTime? createdAt;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const PhotoGalleryCard({
    super.key,
    required this.title,
    required this.photos,
    this.createdAt,
    this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ImageCard(
      images: photos,
      title: title,
      subtitle: '${photos.length} photos',
      layout: ImageCardLayout.grid,
      onTap: onTap,
      actions: [
        if (onAdd != null)
          InfoCardAction(
            icon: Icons.add_photo_alternate,
            label: 'Add Photos',
            color: const Color(0xFF00D4AA),
            onAction: onAdd!,
          ),
      ],
    );
  }
}