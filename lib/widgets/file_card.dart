import 'package:flutter/material.dart';
import 'info_card.dart';

/// File card for displaying file information and previews
/// 
/// Features:
/// - File type detection
/// - Preview for images/text
/// - File metadata
/// - Download/share actions
class FileCard extends InfoCard {
  final FileData file;
  final bool showPreview;
  final int? previewLines;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const FileCard({
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
    required this.file,
    this.showPreview = true,
    this.previewLines,
    this.onDownload,
    this.onShare,
    this.onOpen,
    this.onDelete,
  });

  @override
  Widget buildContent(BuildContext context) {
    return _FileCardContent(
      file: file,
      showPreview: showPreview,
      previewLines: previewLines,
    );
  }
}

class _FileCardContent extends StatelessWidget {
  final FileData file;
  final bool showPreview;
  final int? previewLines;

  const _FileCardContent({
    required this.file,
    required this.showPreview,
    this.previewLines,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File info row
        _buildFileInfo(context),
        
        // Preview
        if (showPreview && file.preview != null) ...[
          const SizedBox(height: 12),
          _buildPreview(context),
        ],
        
        // Metadata chips
        if (file.metadata != null && file.metadata!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildMetadata(context),
        ],
      ],
    );
  }

  Widget _buildFileInfo(BuildContext context) {
    final fileType = _getFileType(file.name);
    
    return Row(
      children: [
        // File icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: fileType.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fileType.color.withOpacity(0.3)),
          ),
          child: Icon(fileType.icon, color: fileType.color, size: 24),
        ),
        const SizedBox(width: 12),
        
        // File details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (file.extension ?? 'FILE').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: fileType.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    file.sizeFormatted,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (file.modifiedAt != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(file.modifiedAt!),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final fileType = _getFileType(file.name);
    
    if (fileType == FileType.image && file.preview != null) {
      return _buildImagePreview();
    } else if (fileType == FileType.text && file.preview != null) {
      return _buildTextPreview();
    } else if (fileType == FileType.code && file.preview != null) {
      return _buildCodePreview();
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 8),
              Text(
                'Image Preview',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextPreview() {
    final lines = file.preview!.split('\n');
    final displayLines = previewLines != null 
        ? lines.take(previewLines!).toList() 
        : lines;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...displayLines.map((line) => Text(
            line,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.grey[300],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
          if (lines.length > displayLines.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${lines.length - displayLines.length} more lines',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[500],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCodePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Text(
        file.preview!,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: Color(0xFFD4D4D4),
        ),
        maxLines: previewLines ?? 10,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: file.metadata!.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        );
      }).toList(),
    );
  }

  FileType _getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'];
    const codeExts = ['dart', 'js', 'ts', 'py', 'java', 'cpp', 'c', 'go', 'rs', 'rb'];
    const textExts = ['txt', 'md', 'json', 'yaml', 'yml', 'xml', 'csv'];
    const documentExts = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];
    const archiveExts = ['zip', 'tar', 'gz', 'rar', '7z'];
    const audioExts = ['mp3', 'wav', 'ogg', 'flac', 'm4a'];
    const videoExts = ['mp4', 'avi', 'mov', 'mkv', 'webm'];
    
    if (imageExts.contains(ext)) return FileType.image;
    if (codeExts.contains(ext)) return FileType.code;
    if (textExts.contains(ext)) return FileType.text;
    if (documentExts.contains(ext)) return FileType.document;
    if (archiveExts.contains(ext)) return FileType.archive;
    if (audioExts.contains(ext)) return FileType.audio;
    if (videoExts.contains(ext)) return FileType.video;
    
    return FileType.other;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// File data class
class FileData {
  final String name;
  final String path;
  final int sizeBytes;
  final String? extension;
  final DateTime? modifiedAt;
  final DateTime? createdAt;
  final String? preview;
  final Map<String, dynamic>? metadata;
  final String? mimeType;

  const FileData({
    required this.name,
    required this.path,
    required this.sizeBytes,
    this.extension,
    this.modifiedAt,
    this.createdAt,
    this.preview,
    this.metadata,
    this.mimeType,
  });

  String get sizeFormatted {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$sizeBytes B';
  }
}

/// File type enum
enum FileType {
  image(Icons.image, Colors.purple),
  code(Icons.code, Colors.blue),
  text(Icons.description, Colors.grey),
  document(Icons.insert_drive_file, Colors.orange),
  archive(Icons.folder_zip, Colors.brown),
  audio(Icons.audiotrack, Colors.pink),
  video(Icons.videocam, Colors.red),
  other(Icons.insert_drive_file, Colors.grey);

  final IconData icon;
  final Color color;

  const FileType(this.icon, this.color);
}

/// File list card - displays multiple files
class FileListCard extends StatelessWidget {
  final List<FileData> files;
  final String? title;
  final Function(FileData)? onFileTap;
  final Function(FileData)? onFileLongPress;

  const FileListCard({
    super.key,
    required this.files,
    this.title,
    this.onFileTap,
    this.onFileLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF00D4AA), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title ?? 'Files',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${files.length} files',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folder card - specialized for directories
class FolderCard extends StatelessWidget {
  final String name;
  final String? path;
  final int? itemCount;
  final int? subfolderCount;
  final DateTime? modifiedAt;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FolderCard({
    super.key,
    required this.name,
    this.path,
    this.itemCount,
    this.subfolderCount,
    this.modifiedAt,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (path != null)
                      Text(
                        path!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (itemCount != null) ...[
                          Icon(Icons.description, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '$itemCount files',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                        if (subfolderCount != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.folder, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '$subfolderCount folders',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}