import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_attachment.dart';

/// Service for handling file attachments in chat
class ChatAttachmentService {
  final String baseUrl;
  final String? token;
  final Uuid _uuid = const Uuid();

  ChatAttachmentService({
    this.baseUrl = 'http://localhost:18789',
    this.token,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Supported file extensions by category
  static const Map<String, List<String>> supportedExtensions = {
    'images': ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'],
    'documents': ['pdf', 'txt', 'md', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'rtf', 'csv'],
    'code': ['js', 'ts', 'py', 'dart', 'java', 'kt', 'swift', 'go', 'rs', 'c', 'cpp', 'h', 'hpp', 'cs', 'rb', 'php', 'html', 'css', 'json', 'yaml', 'yml', 'xml', 'sql', 'sh', 'bash', 'jsx', 'tsx', 'vue', 'svelte'],
    'audio': ['mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac', 'wma'],
    'video': ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'],
  };

  /// Get all supported extensions
  static List<String> get allSupportedExtensions =>
      supportedExtensions.values.expand((e) => e).toList();

  /// Check if a file extension is supported
  static bool isSupported(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    return allSupportedExtensions.contains(ext);
  }

  /// Get attachment type from file extension
  static AttachmentType getTypeFromExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    
    if (supportedExtensions['images']!.contains(ext)) {
      return AttachmentType.image;
    }
    if (supportedExtensions['video']!.contains(ext)) {
      return AttachmentType.video;
    }
    if (supportedExtensions['audio']!.contains(ext)) {
      return AttachmentType.audio;
    }
    if (supportedExtensions['code']!.contains(ext)) {
      return AttachmentType.code;
    }
    if (supportedExtensions['documents']!.contains(ext)) {
      return AttachmentType.document;
    }
    return AttachmentType.unknown;
  }

  /// Get MIME type from file extension
  static String? getMimeType(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final mimeTypes = <String, String>{
      // Images
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      // Documents
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'md': 'text/markdown',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'csv': 'text/csv',
      'rtf': 'application/rtf',
      // Audio
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'm4a': 'audio/mp4',
      'flac': 'audio/flac',
      'aac': 'audio/aac',
      // Video
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      // Code
      'js': 'application/javascript',
      'ts': 'application/typescript',
      'py': 'text/x-python',
      'dart': 'application/dart',
      'java': 'text/x-java-source',
      'json': 'application/json',
      'xml': 'application/xml',
      'html': 'text/html',
      'css': 'text/css',
      'yaml': 'application/x-yaml',
      'yml': 'application/x-yaml',
      'sql': 'application/sql',
      'sh': 'application/x-sh',
      'bash': 'application/x-sh',
    };
    return mimeTypes[ext];
  }

  /// Create a local attachment from a file
  ChatAttachment createLocalAttachment(File file) {
    final fileName = file.path.split('/').last;
    final extension = fileName.split('.').last;
    final fileSize = file.lengthSync();
    final type = getTypeFromExtension(extension);
    final mimeType = getMimeType(extension);

    return ChatAttachment(
      id: _uuid.v4(),
      fileName: fileName,
      originalFileName: fileName,
      filePath: file.path,
      type: type,
      fileSize: fileSize,
      mimeType: mimeType,
      uploadedAt: DateTime.now(),
      uploadStatus: UploadStatus.pending,
      uploadProgress: 0,
    );
  }

  /// Upload a file to the gateway
  Future<ChatAttachment> uploadFile(
    File file, {
    void Function(double progress)? onProgress,
    String? sessionId,
  }) async {
    final attachment = createLocalAttachment(file);
    
    try {
      // Create multipart request
      final uri = Uri.parse('$baseUrl/api/chat/attachments/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_headers)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      if (sessionId != null) {
        request.fields['sessionId'] = sessionId;
      }

      // Send request
      final streamedResponse = await request.send();
      
      // Track progress
      if (onProgress != null) {
        streamedResponse.stream.listen(
          (chunk) {
            // Progress tracking would require content-length
          },
          onDone: () {
            onProgress(1.0);
          },
        );
      }

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ChatAttachment.fromJson(json['attachment'] ?? json);
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      // Return attachment with error status
      return attachment.copyWith(
        uploadStatus: UploadStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Upload multiple files
  Future<List<ChatAttachment>> uploadFiles(
    List<File> files, {
    void Function(int index, double progress)? onProgress,
    String? sessionId,
  }) async {
    final results = <ChatAttachment>[];
    
    for (int i = 0; i < files.length; i++) {
      final result = await uploadFile(
        files[i],
        onProgress: onProgress != null ? (p) => onProgress(i, p) : null,
        sessionId: sessionId,
      );
      results.add(result);
    }
    
    return results;
  }

  /// Download an attachment
  Future<File> downloadAttachment(
    ChatAttachment attachment, {
    void Function(double progress)? onProgress,
    String? customPath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/attachments/${attachment.id}/download');
      final request = http.Request('GET', uri)..headers.addAll(_headers);

      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      // Determine save path
      String savePath;
      if (customPath != null) {
        savePath = customPath;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${dir.path}/downloads');
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }
        savePath = '${downloadsDir.path}/${attachment.fileName}';
      }

      // Write to file
      final file = File(savePath);
      final sink = file.openWrite();
      
      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (onProgress != null && contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      });

      await sink.close();
      return file;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an attachment
  Future<bool> deleteAttachment(String attachmentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chat/attachments/$attachmentId'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting attachment: $e');
      return false;
    }
  }

  /// Get attachment info
  Future<ChatAttachment?> getAttachment(String attachmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/attachments/$attachmentId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ChatAttachment.fromJson(json['attachment'] ?? json);
      }
    } catch (e) {
      print('Error getting attachment: $e');
    }
    return null;
  }

  /// Get file preview info (for code files, text files)
  Future<String?> getFilePreview(ChatAttachment attachment) async {
    if (attachment.type != AttachmentType.code && 
        attachment.type != AttachmentType.document) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/attachments/${attachment.id}/preview'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['preview'] ?? json['content'];
      }
    } catch (e) {
      print('Error getting file preview: $e');
    }
    return null;
  }

  /// Generate thumbnail for an image
  Future<String?> generateThumbnail(ChatAttachment attachment) async {
    if (!attachment.isImage) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/attachments/${attachment.id}/thumbnail'),
        headers: _headers,
        body: jsonEncode({
          'width': 200,
          'height': 200,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['thumbnailUrl'] ?? json['url'];
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
    }
    return null;
  }
}