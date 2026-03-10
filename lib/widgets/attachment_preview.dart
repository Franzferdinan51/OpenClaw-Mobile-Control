import 'dart:io';
import 'package:flutter/material.dart';

/// Attachment preview widget for displaying attached files
class AttachmentPreview extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showActions;
  final double maxHeight;

  const AttachmentPreview({
    super.key,
    required this.attachment,
    this.onTap,
    this.onRemove,
    this.showActions = true,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          if (showActions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(_getFileIcon(), size: 16, color: _getFileColor()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getFileInfo(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Remove',
                    ),
                ],
              ),
            ),
          
          // Preview content
          Flexible(
            child: InkWell(
              onTap: onTap,
              child: _buildPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    switch (attachment.type) {
      case AttachmentType.image:
        return _buildImagePreview();
      case AttachmentType.code:
        return _buildCodePreview();
      case AttachmentType.document:
        return _buildDocumentPreview();
      case AttachmentType.audio:
        return _buildAudioPreview();
      case AttachmentType.video:
        return _buildVideoPreview();
      case AttachmentType.other:
        return _buildGenericPreview();
    }
  }

  Widget _buildImagePreview() {
    if (attachment.path != null && File(attachment.path!).existsSync()) {
      return ClipRRect(
        borderRadius: showActions
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.circular(12),
        child: Image.file(
          File(attachment.path!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGenericPreview(),
        ),
      );
    } else if (attachment.url != null) {
      return ClipRRect(
        borderRadius: showActions
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.circular(12),
        child: Image.network(
          attachment.url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGenericPreview(),
        ),
      );
    }
    return _buildGenericPreview();
  }

  Widget _buildCodePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Icon(Icons.code, size: 40, color: Color(0xFF00D4AA)),
          const SizedBox(height: 8),
          Text(
            attachment.name,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (attachment.size != null)
            Text(
              _formatSize(attachment.size!),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview() {
    final ext = attachment.name.split('.').last.toLowerCase();
    IconData icon;
    
    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        break;
      default:
        icon = Icons.insert_drive_file;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            attachment.name,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.audiotrack,
              size: 30,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            attachment.name,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (attachment.duration != null)
            Text(
              _formatDuration(attachment.duration!),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.video_file, color: Colors.grey),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.black,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericPreview() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getFileIcon(), size: 48, color: _getFileColor()),
          const SizedBox(height: 8),
          Text(
            attachment.name,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    switch (attachment.type) {
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.code:
        return Icons.code;
      case AttachmentType.document:
        return Icons.insert_drive_file;
      case AttachmentType.audio:
        return Icons.audiotrack;
      case AttachmentType.video:
        return Icons.video_file;
      case AttachmentType.other:
        return Icons.attach_file;
    }
  }

  Color _getFileColor() {
    switch (attachment.type) {
      case AttachmentType.image:
        return Colors.green;
      case AttachmentType.code:
        return const Color(0xFF00D4AA);
      case AttachmentType.document:
        return Colors.blue;
      case AttachmentType.audio:
        return Colors.purple;
      case AttachmentType.video:
        return Colors.red;
      case AttachmentType.other:
        return Colors.grey;
    }
  }

  String _getFileInfo() {
    final parts = <String>[];
    
    if (attachment.size != null) {
      parts.add(_formatSize(attachment.size!));
    }
    
    if (attachment.mimeType != null) {
      parts.add(attachment.mimeType!);
    }
    
    return parts.isEmpty ? 'Attachment' : parts.join(' • ');
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Attachment type enumeration
enum AttachmentType {
  image,
  code,
  document,
  audio,
  video,
  other,
}

/// Attachment model
class Attachment {
  final String id;
  final String name;
  final AttachmentType type;
  final String? path;
  final String? url;
  final int? size;
  final String? mimeType;
  final Duration? duration;
  final Map<String, dynamic>? metadata;

  const Attachment({
    required this.id,
    required this.name,
    required this.type,
    this.path,
    this.url,
    this.size,
    this.mimeType,
    this.duration,
    this.metadata,
  });

  factory Attachment.fromFile(String path, {String? name}) {
    final file = File(path);
    final fileName = name ?? path.split('/').last;
    final type = _getTypeFromExtension(fileName);
    
    return Attachment(
      id: path.hashCode.toString(),
      name: fileName,
      type: type,
      path: path,
      size: file.existsSync() ? file.lengthSync() : null,
      mimeType: _getMimeType(fileName),
    );
  }

  static AttachmentType _getTypeFromExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    const codeExts = ['dart', 'js', 'ts', 'py', 'java', 'cpp', 'c', 'h', 'json', 'yaml', 'xml'];
    const audioExts = ['mp3', 'wav', 'ogg', 'm4a', 'flac'];
    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    const docExts = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md'];
    
    if (imageExts.contains(ext)) return AttachmentType.image;
    if (codeExts.contains(ext)) return AttachmentType.code;
    if (audioExts.contains(ext)) return AttachmentType.audio;
    if (videoExts.contains(ext)) return AttachmentType.video;
    if (docExts.contains(ext)) return AttachmentType.document;
    return AttachmentType.other;
  }

  static String? _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'mp4': 'video/mp4',
      'json': 'application/json',
      'txt': 'text/plain',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
    };
    
    return mimeTypes[ext];
  }
}

/// Attachment list widget for displaying multiple attachments
class AttachmentList extends StatelessWidget {
  final List<Attachment> attachments;
  final Function(Attachment)? onTap;
  final Function(Attachment)? onRemove;
  final bool horizontal;
  final double maxHeight;

  const AttachmentList({
    super.key,
    required this.attachments,
    this.onTap,
    this.onRemove,
    this.horizontal = true,
    this.maxHeight = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    if (horizontal) {
      return SizedBox(
        height: maxHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: attachments.length,
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            return Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 8,
                right: index == attachments.length - 1 ? 0 : 0,
              ),
              child: SizedBox(
                width: 150,
                child: AttachmentPreview(
                  attachment: attachment,
                  onTap: onTap != null ? () => onTap!(attachment) : null,
                  onRemove: onRemove != null ? () => onRemove!(attachment) : null,
                  maxHeight: maxHeight,
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: attachments.map((attachment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AttachmentPreview(
            attachment: attachment,
            onTap: onTap != null ? () => onTap!(attachment) : null,
            onRemove: onRemove != null ? () => onRemove!(attachment) : null,
            maxHeight: maxHeight,
          ),
        );
      }).toList(),
    );
  }
}