import 'dart:convert';

import 'package:http/http.dart' as http;

class TermuxHubTool {
  final String id;
  final String name;
  final String description;
  final String category;
  final String installCommand;
  final String repoUrl;
  final String author;
  final bool requireRoot;
  final String? license;
  final int? starCount;

  const TermuxHubTool({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.installCommand,
    required this.repoUrl,
    required this.author,
    required this.requireRoot,
    this.license,
    this.starCount,
  });
}

class TermuxHubService {
  static const String repoUrl = 'https://github.com/maazm7d/TermuxHub';
  static const String metadataUrl =
      'https://raw.githubusercontent.com/maazm7d/TermuxHub/main/metadata/metadata.json';
  static const String repoStatsUrl =
      'https://raw.githubusercontent.com/maazm7d/TermuxHub/main/metadata/repo_stats.json';
  static const String starsUrl =
      'https://raw.githubusercontent.com/maazm7d/TermuxHub/main/metadata/stars.json';

  static const String _safeCategory = 'Utilities & Dev';
  static final RegExp _unsafeKeywordPattern = RegExp(
    r'(pentest|phish|phishing|malware|exploit|brute|recon|osint|social engineering|payload|adb|fastboot|shizuku|reverse|forensic|cracker)',
    caseSensitive: false,
  );

  Future<List<TermuxHubTool>> fetchCatalog() async {
    final responses = await Future.wait([
      http.get(Uri.parse(metadataUrl)),
      http.get(Uri.parse(repoStatsUrl)),
      http.get(Uri.parse(starsUrl)),
    ]);

    final metadataResponse = responses[0];
    if (metadataResponse.statusCode != 200) {
      throw Exception(
          'TermuxHub metadata request failed with HTTP ${metadataResponse.statusCode}');
    }

    final metadataJson =
        jsonDecode(metadataResponse.body) as Map<String, dynamic>;
    final repoStatsJson = responses[1].statusCode == 200
        ? jsonDecode(responses[1].body) as Map<String, dynamic>
        : const <String, dynamic>{};
    final starsJson = responses[2].statusCode == 200
        ? jsonDecode(responses[2].body) as Map<String, dynamic>
        : const <String, dynamic>{};

    final stats =
        (repoStatsJson['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stars =
        (starsJson['stars'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tools =
        (metadataJson['tools'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];

    final filtered = <TermuxHubTool>[];
    for (final raw in tools) {
      final category = (raw['category'] ?? '').toString().trim();
      final name = (raw['name'] ?? '').toString().trim();
      final description = (raw['description'] ?? '').toString().trim();
      final installCommand = (raw['install'] ?? '').toString().trim();
      final combinedText = '$name $description $installCommand';

      if (category != _safeCategory) {
        continue;
      }

      if (_unsafeKeywordPattern.hasMatch(combinedText)) {
        continue;
      }

      final id = (raw['id'] ?? '').toString().trim();
      final statEntry = stats[id] as Map<String, dynamic>?;

      filtered.add(
        TermuxHubTool(
          id: id,
          name: name,
          description: description,
          category: category,
          installCommand: installCommand,
          repoUrl: (raw['repo'] ?? '').toString().trim(),
          author: (raw['author'] ?? '').toString().trim(),
          requireRoot: raw['requireRoot'] == true,
          license: statEntry?['license']?.toString(),
          starCount: stars[id] is num ? (stars[id] as num).toInt() : null,
        ),
      );
    }

    filtered.sort((a, b) {
      final starCompare = (b.starCount ?? 0).compareTo(a.starCount ?? 0);
      if (starCompare != 0) {
        return starCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }
}
