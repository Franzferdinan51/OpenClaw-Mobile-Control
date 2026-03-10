/// Skill category types
enum SkillCategory {
  automation,
  productivity,
  communication,
  media,
  data,
  security,
  ai,
  developer,
  apple,
  games,
  system,
  other,
}

extension SkillCategoryExtension on SkillCategory {
  String get displayName {
    switch (this) {
      case SkillCategory.automation:
        return 'Automation';
      case SkillCategory.productivity:
        return 'Productivity';
      case SkillCategory.communication:
        return 'Communication';
      case SkillCategory.media:
        return 'Media';
      case SkillCategory.data:
        return 'Data';
      case SkillCategory.security:
        return 'Security';
      case SkillCategory.ai:
        return 'AI';
      case SkillCategory.developer:
        return 'Developer';
      case SkillCategory.apple:
        return 'Apple';
      case SkillCategory.games:
        return 'Games';
      case SkillCategory.system:
        return 'System';
      case SkillCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case SkillCategory.automation:
        return '⚙️';
      case SkillCategory.productivity:
        return '📊';
      case SkillCategory.communication:
        return '💬';
      case SkillCategory.media:
        return '🎬';
      case SkillCategory.data:
        return '📈';
      case SkillCategory.security:
        return '🔐';
      case SkillCategory.ai:
        return '🤖';
      case SkillCategory.developer:
        return '💻';
      case SkillCategory.apple:
        return '🍎';
      case SkillCategory.games:
        return '🎮';
      case SkillCategory.system:
        return '🖥️';
      case SkillCategory.other:
        return '📦';
    }
  }

  static SkillCategory fromString(String value) {
    return SkillCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SkillCategory.other,
    );
  }
}

/// Model representing a skill from ClawHub
class Skill {
  final String id;
  final String slug;
  final String name;
  final String description;
  final String fullDescription;
  final SkillCategory category;
  final String version;
  final String author;
  final String? authorUrl;
  final bool installed;
  final String icon;
  final List<String> tags;
  final int? downloads;
  final double? rating;
  final int? reviewCount;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final List<String>? dependencies;
  final List<String>? permissions;
  final String? homepage;
  final String? repository;
  final String? license;
  final List<SkillReview>? reviews;
  final List<String>? installationInstructions;

  const Skill({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.fullDescription,
    required this.category,
    required this.version,
    required this.author,
    this.authorUrl,
    required this.installed,
    required this.icon,
    required this.tags,
    this.downloads,
    this.rating,
    this.reviewCount,
    this.publishedAt,
    this.updatedAt,
    this.dependencies,
    this.permissions,
    this.homepage,
    this.repository,
    this.license,
    this.reviews,
    this.installationInstructions,
  });

  /// Get display name with icon
  String get displayName => '$icon $name';

  /// Get short description for cards
  String get shortDescription => description;

  /// Get formatted download count
  String get formattedDownloads {
    if (downloads == null) return '0';
    if (downloads! >= 1000000) {
      return '${(downloads! / 1000000).toStringAsFixed(1)}M';
    } else if (downloads! >= 1000) {
      return '${(downloads! / 1000).toStringAsFixed(1)}K';
    }
    return downloads.toString();
  }

  /// Get formatted rating
  String get formattedRating {
    if (rating == null) return 'N/A';
    return rating!.toStringAsFixed(1);
  }

  /// Create a copy with modifications
  Skill copyWith({
    String? id,
    String? slug,
    String? name,
    String? description,
    String? fullDescription,
    SkillCategory? category,
    String? version,
    String? author,
    String? authorUrl,
    bool? installed,
    String? icon,
    List<String>? tags,
    int? downloads,
    double? rating,
    int? reviewCount,
    DateTime? publishedAt,
    DateTime? updatedAt,
    List<String>? dependencies,
    List<String>? permissions,
    String? homepage,
    String? repository,
    String? license,
    List<SkillReview>? reviews,
    List<String>? installationInstructions,
  }) {
    return Skill(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      fullDescription: fullDescription ?? this.fullDescription,
      category: category ?? this.category,
      version: version ?? this.version,
      author: author ?? this.author,
      authorUrl: authorUrl ?? this.authorUrl,
      installed: installed ?? this.installed,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
      downloads: downloads ?? this.downloads,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dependencies: dependencies ?? this.dependencies,
      permissions: permissions ?? this.permissions,
      homepage: homepage ?? this.homepage,
      repository: repository ?? this.repository,
      license: license ?? this.license,
      reviews: reviews ?? this.reviews,
      installationInstructions: installationInstructions ?? this.installationInstructions,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'description': description,
      'fullDescription': fullDescription,
      'category': category.name,
      'version': version,
      'author': author,
      'authorUrl': authorUrl,
      'installed': installed,
      'icon': icon,
      'tags': tags,
      'downloads': downloads,
      'rating': rating,
      'reviewCount': reviewCount,
      'publishedAt': publishedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'dependencies': dependencies,
      'permissions': permissions,
      'homepage': homepage,
      'repository': repository,
      'license': license,
      'reviews': reviews?.map((r) => r.toJson()).toList(),
      'installationInstructions': installationInstructions,
    };
  }

  /// Create from JSON map
  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String? ?? json['slug'] as String? ?? '',
      slug: json['slug'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Skill',
      description: json['description'] as String? ?? json['shortDescription'] as String? ?? '',
      fullDescription: json['fullDescription'] as String? ?? json['description'] as String? ?? '',
      category: SkillCategoryExtension.fromString(json['category'] as String? ?? 'other'),
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'Unknown',
      authorUrl: json['authorUrl'] as String?,
      installed: json['installed'] as bool? ?? false,
      icon: json['icon'] as String? ?? '📦',
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
      downloads: json['downloads'] as int?,
      rating: json['rating'] as double?,
      reviewCount: json['reviewCount'] as int?,
      publishedAt: json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      dependencies: json['dependencies'] != null ? List<String>.from(json['dependencies'] as List) : null,
      permissions: json['permissions'] != null ? List<String>.from(json['permissions'] as List) : null,
      homepage: json['homepage'] as String?,
      repository: json['repository'] as String?,
      license: json['license'] as String?,
      reviews: json['reviews'] != null
          ? (json['reviews'] as List).map((r) => SkillReview.fromJson(r)).toList()
          : null,
      installationInstructions: json['installationInstructions'] != null
          ? List<String>.from(json['installationInstructions'] as List)
          : null,
    );
  }
}

/// Model for skill reviews
class SkillReview {
  final String id;
  final String author;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  const SkillReview({
    required this.id,
    required this.author,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SkillReview.fromJson(Map<String, dynamic> json) {
    return SkillReview(
      id: json['id'] as String? ?? '',
      author: json['author'] as String? ?? 'Anonymous',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Model for skill installation status
class SkillInstallationStatus {
  final String skillId;
  final bool isInstalled;
  final String? installedVersion;
  final DateTime? installedAt;
  final String? installationPath;

  const SkillInstallationStatus({
    required this.skillId,
    required this.isInstalled,
    this.installedVersion,
    this.installedAt,
    this.installationPath,
  });

  factory SkillInstallationStatus.fromJson(Map<String, dynamic> json) {
    return SkillInstallationStatus(
      skillId: json['skillId'] as String? ?? '',
      isInstalled: json['isInstalled'] as bool? ?? false,
      installedVersion: json['installedVersion'] as String?,
      installedAt: json['installedAt'] != null ? DateTime.tryParse(json['installedAt'] as String) : null,
      installationPath: json['installationPath'] as String?,
    );
  }
}