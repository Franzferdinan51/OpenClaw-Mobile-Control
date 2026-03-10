/// Attachment types supported by chat
enum AttachmentType {
  image,
  document,
  code,
  audio,
  video,
  unknown,
}

/// Model for file attachments in chat messages
class ChatAttachment {
  final String id;
  final String fileName;
  final String? originalFileName;
  final String filePath;
  final AttachmentType type;
  final int fileSize;
  final String? mimeType;
  final String? thumbnailUrl;
  final DateTime uploadedAt;
  final String? uploadedBy;
  final UploadStatus uploadStatus;
  final double uploadProgress;
  final String? errorMessage;

  ChatAttachment({
    required this.id,
    required this.fileName,
    this.originalFileName,
    required this.filePath,
    required this.type,
    required this.fileSize,
    this.mimeType,
    this.thumbnailUrl,
    required this.uploadedAt,
    this.uploadedBy,
    this.uploadStatus = UploadStatus.completed,
    this.uploadProgress = 1.0,
    this.errorMessage,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] ?? json['attachmentId'] ?? '',
      fileName: json['fileName'] ?? json['filename'] ?? '',
      originalFileName: json['originalFileName'],
      filePath: json['filePath'] ?? json['url'] ?? json['path'] ?? '',
      type: _parseType(json['type'] ?? json['mimeType'] ?? ''),
      fileSize: json['fileSize'] ?? json['size'] ?? 0,
      mimeType: json['mimeType'],
      thumbnailUrl: json['thumbnailUrl'] ?? json['thumbnail'],
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      uploadedBy: json['uploadedBy'],
      uploadStatus: _parseStatus(json['uploadStatus']),
      uploadProgress: (json['uploadProgress'] ?? 1.0).toDouble(),
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'originalFileName': originalFileName,
    'filePath': filePath,
    'type': type.name,
    'fileSize': fileSize,
    'mimeType': mimeType,
    'thumbnailUrl': thumbnailUrl,
    'uploadedAt': uploadedAt.toIso8601String(),
    'uploadedBy': uploadedBy,
    'uploadStatus': uploadStatus.name,
    'uploadProgress': uploadProgress,
    'errorMessage': errorMessage,
  };

  static AttachmentType _parseType(String value) {
    final lower = value.toLowerCase();
    if (lower.startsWith('image/') || 
        ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].any((ext) => lower.contains(ext))) {
      return AttachmentType.image;
    }
    if (lower.startsWith('video/') ||
        ['mp4', 'mov', 'avi', 'mkv', 'webm'].any((ext) => lower.contains(ext))) {
      return AttachmentType.video;
    }
    if (lower.startsWith('audio/') ||
        ['mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac'].any((ext) => lower.contains(ext))) {
      return AttachmentType.audio;
    }
    if (['pdf', 'txt', 'md', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].any((ext) => lower.contains(ext))) {
      return AttachmentType.document;
    }
    if (['js', 'ts', 'py', 'dart', 'java', 'kt', 'swift', 'go', 'rs', 'c', 'cpp', 'h', 'hpp', 'cs', 'rb', 'php', 'html', 'css', 'json', 'yaml', 'yml', 'xml', 'sql', 'sh', 'bash'].any((ext) => lower.contains(ext))) {
      return AttachmentType.code;
    }
    return AttachmentType.unknown;
  }

  static UploadStatus _parseStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return UploadStatus.pending;
      case 'uploading':
        return UploadStatus.uploading;
      case 'completed':
      case 'success':
        return UploadStatus.completed;
      case 'failed':
      case 'error':
        return UploadStatus.failed;
      default:
        return UploadStatus.completed;
    }
  }

  /// Get human-readable file size
  String get displayFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get file extension
  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : '';
  }

  /// Check if this is an image
  bool get isImage => type == AttachmentType.image;

  /// Check if upload is in progress
  bool get isUploading => uploadStatus == UploadStatus.uploading;

  /// Check if upload failed
  bool get hasFailed => uploadStatus == UploadStatus.failed;

  /// Create a copy with updated fields
  ChatAttachment copyWith({
    String? id,
    String? fileName,
    String? originalFileName,
    String? filePath,
    AttachmentType? type,
    int? fileSize,
    String? mimeType,
    String? thumbnailUrl,
    DateTime? uploadedAt,
    String? uploadedBy,
    UploadStatus? uploadStatus,
    double? uploadProgress,
    String? errorMessage,
  }) {
    return ChatAttachment(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      originalFileName: originalFileName ?? this.originalFileName,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Upload status for attachments
enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
}