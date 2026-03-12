import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'termux_run_command_service.dart';

enum OpenClawBackupScope {
  full,
  configOnly,
  noWorkspace,
}

enum OpenClawBackupStatus {
  completed,
  pending,
  failed,
}

class OpenClawBackupAvailability {
  final bool termuxInstalled;
  final bool runCommandPermissionGranted;
  final bool openClawCliAvailable;
  final bool requiresAllowExternalApps;
  final String? openClawVersion;
  final String summary;

  const OpenClawBackupAvailability({
    required this.termuxInstalled,
    required this.runCommandPermissionGranted,
    required this.openClawCliAvailable,
    required this.requiresAllowExternalApps,
    required this.summary,
    this.openClawVersion,
  });

  bool get isAvailable =>
      termuxInstalled &&
      runCommandPermissionGranted &&
      openClawCliAvailable &&
      !requiresAllowExternalApps;
}

class OpenClawBackupRecord {
  final String id;
  final String archivePath;
  final DateTime createdAt;
  final OpenClawBackupScope scope;
  final OpenClawBackupStatus status;
  final bool verified;
  final String? message;
  final DateTime? lastVerifiedAt;

  const OpenClawBackupRecord({
    required this.id,
    required this.archivePath,
    required this.createdAt,
    required this.scope,
    required this.status,
    required this.verified,
    this.message,
    this.lastVerifiedAt,
  });

  OpenClawBackupRecord copyWith({
    String? archivePath,
    DateTime? createdAt,
    OpenClawBackupScope? scope,
    OpenClawBackupStatus? status,
    bool? verified,
    String? message,
    DateTime? lastVerifiedAt,
  }) {
    return OpenClawBackupRecord(
      id: id,
      archivePath: archivePath ?? this.archivePath,
      createdAt: createdAt ?? this.createdAt,
      scope: scope ?? this.scope,
      status: status ?? this.status,
      verified: verified ?? this.verified,
      message: message ?? this.message,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }

  String get filename => archivePath.split('/').last;

  String get scopeLabel {
    switch (scope) {
      case OpenClawBackupScope.full:
        return 'Full';
      case OpenClawBackupScope.configOnly:
        return 'Config only';
      case OpenClawBackupScope.noWorkspace:
        return 'No workspace';
    }
  }

  String get statusLabel {
    switch (status) {
      case OpenClawBackupStatus.completed:
        return verified ? 'Verified' : 'Created';
      case OpenClawBackupStatus.pending:
        return 'Running';
      case OpenClawBackupStatus.failed:
        return 'Failed';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'archivePath': archivePath,
        'createdAt': createdAt.toIso8601String(),
        'scope': scope.name,
        'status': status.name,
        'verified': verified,
        'message': message,
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
      };

  factory OpenClawBackupRecord.fromJson(Map<String, dynamic> json) {
    OpenClawBackupScope parseScope(String? value) {
      return OpenClawBackupScope.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => OpenClawBackupScope.full,
      );
    }

    OpenClawBackupStatus parseStatus(String? value) {
      return OpenClawBackupStatus.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => OpenClawBackupStatus.completed,
      );
    }

    return OpenClawBackupRecord(
      id: json['id']?.toString() ?? '',
      archivePath: json['archivePath']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      scope: parseScope(json['scope']?.toString()),
      status: parseStatus(json['status']?.toString()),
      verified: json['verified'] == true,
      message: json['message']?.toString(),
      lastVerifiedAt:
          DateTime.tryParse(json['lastVerifiedAt']?.toString() ?? ''),
    );
  }
}

class OpenClawBackupActionResult {
  final bool success;
  final bool pending;
  final String message;
  final OpenClawBackupRecord? record;

  const OpenClawBackupActionResult({
    required this.success,
    required this.pending,
    required this.message,
    this.record,
  });
}

class OpenClawBackupService extends ChangeNotifier {
  static const String _recordsKey = 'openclaw_native_backup_records_v1';
  static const String _termuxHome = '/data/data/com.termux/files/home';
  static const String _backupRoot = '$_termuxHome/duckbot-backups';

  final TermuxRunCommandService _bridge = TermuxRunCommandService();

  bool _isInitialized = false;
  bool _isBusy = false;
  String? _lastError;
  List<OpenClawBackupRecord> _records = const [];
  OpenClawBackupAvailability? _availability;

  bool get isBusy => _isBusy;
  String? get lastError => _lastError;
  List<OpenClawBackupRecord> get records => List.unmodifiable(_records);
  OpenClawBackupAvailability? get availability => _availability;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadRecords();
    _isInitialized = true;
  }

  Future<List<OpenClawBackupRecord>> getBackups() async {
    await initialize();
    return records;
  }

  Future<OpenClawBackupAvailability> getAvailability({
    bool forceRefresh = false,
  }) async {
    await initialize();
    if (!forceRefresh && _availability != null) {
      return _availability!;
    }

    final termuxInstalled = await _bridge.isTermuxInstalled();
    if (!termuxInstalled) {
      return _availability = const OpenClawBackupAvailability(
        termuxInstalled: false,
        runCommandPermissionGranted: false,
        openClawCliAvailable: false,
        requiresAllowExternalApps: false,
        summary: 'Install Termux to use native OpenClaw backups on-device.',
      );
    }

    final hasRunCommandPermission = await _bridge.hasRunCommandPermission();
    if (!hasRunCommandPermission) {
      return _availability = const OpenClawBackupAvailability(
        termuxInstalled: true,
        runCommandPermissionGranted: false,
        openClawCliAvailable: false,
        requiresAllowExternalApps: false,
        summary:
            'Grant RUN_COMMAND permission before DuckBot can invoke native OpenClaw backup commands.',
      );
    }

    final result = await _bridge.runCommandDetailed(
      script: 'command -v openclaw >/dev/null 2>&1 && openclaw --version',
      label: 'Check OpenClaw CLI',
      description: 'Verify the native OpenClaw CLI is installed in Termux',
      waitForResultMs: 5000,
    );

    if (result.requiresAllowExternalApps) {
      return _availability = const OpenClawBackupAvailability(
        termuxInstalled: true,
        runCommandPermissionGranted: true,
        openClawCliAvailable: false,
        requiresAllowExternalApps: true,
        summary:
            'Termux blocked external app commands. Enable allow-external-apps=true in ~/.termux/termux.properties.',
      );
    }

    if (!result.ok) {
      return _availability = const OpenClawBackupAvailability(
        termuxInstalled: true,
        runCommandPermissionGranted: true,
        openClawCliAvailable: false,
        requiresAllowExternalApps: false,
        summary:
            'OpenClaw CLI is not available in Termux yet. Finish the local OpenClaw node setup first.',
      );
    }

    final version =
        result.stdout?.split('\n').map((line) => line.trim()).firstWhere(
              (line) => line.isNotEmpty,
              orElse: () => '',
            );

    return _availability = OpenClawBackupAvailability(
      termuxInstalled: true,
      runCommandPermissionGranted: true,
      openClawCliAvailable: true,
      requiresAllowExternalApps: false,
      openClawVersion: version?.isEmpty == true ? null : version,
      summary: version == null || version.isEmpty
          ? 'Native OpenClaw backup is ready in Termux.'
          : 'Native OpenClaw backup is ready in Termux ($version).',
    );
  }

  Future<OpenClawBackupActionResult> createBackup({
    OpenClawBackupScope scope = OpenClawBackupScope.full,
  }) async {
    final availability = await getAvailability(forceRefresh: true);
    if (!availability.isAvailable) {
      _lastError = availability.summary;
      return OpenClawBackupActionResult(
        success: false,
        pending: false,
        message: availability.summary,
      );
    }

    return _runTrackedCommand(
      label: 'OpenClaw Backup',
      description: 'Create a native OpenClaw backup archive',
      scope: scope,
      buildScript: (archivePath) {
        final flags = <String>['--verify', '--json'];
        if (scope == OpenClawBackupScope.configOnly) {
          flags.add('--only-config');
        } else if (scope == OpenClawBackupScope.noWorkspace) {
          flags.add('--no-include-workspace');
        }

        return '''
mkdir -p "$_backupRoot"
openclaw backup create --output "$archivePath" ${flags.join(' ')}
''';
      },
    );
  }

  Future<OpenClawBackupActionResult> verifyBackup(String archivePath) async {
    final availability = await getAvailability(forceRefresh: true);
    if (!availability.isAvailable) {
      _lastError = availability.summary;
      return OpenClawBackupActionResult(
        success: false,
        pending: false,
        message: availability.summary,
      );
    }

    return _runTrackedCommand(
      label: 'Verify OpenClaw Backup',
      description: 'Validate a native OpenClaw backup archive',
      scope: OpenClawBackupScope.full,
      archivePath: archivePath,
      createRecord: false,
      buildScript: (path) => 'openclaw backup verify "$path" --json',
      onSuccess: (record, json) async {
        if (record == null) {
          return;
        }

        await _upsertRecord(record.copyWith(
          status: OpenClawBackupStatus.completed,
          verified: true,
          lastVerifiedAt: DateTime.now(),
          message: 'Archive verified successfully.',
        ));
      },
    );
  }

  Future<bool> deleteBackup(OpenClawBackupRecord record) async {
    final availability = await getAvailability(forceRefresh: true);
    if (!availability.isAvailable) {
      _lastError = availability.summary;
      return false;
    }

    _isBusy = true;
    notifyListeners();

    try {
      final escapedPath = _shellQuote(record.archivePath);
      final result = await _bridge.runCommandDetailed(
        script: 'rm -f $escapedPath',
        label: 'Delete OpenClaw Backup',
        description: 'Delete a native OpenClaw backup archive',
        waitForResultMs: 4000,
      );

      if (!result.ok || result.pending) {
        _lastError = _describeTermuxFailure(
          result,
          fallback: 'Could not delete backup archive.',
        );
        return false;
      }

      _records = _records.where((entry) => entry.id != record.id).toList();
      await _persistRecords();
      return true;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String buildRestoreGuide({String? archivePath}) {
    final target = archivePath ?? '<archive-path>';
    return '''
OpenClaw does not currently expose a first-party "backup restore" CLI command.

Recommended restore flow:
1. Verify the archive first:
   openclaw backup verify "$target"
2. Stop the target gateway/node before restoring any state.
3. Prefer host-native migration/setup flows when available, such as hosted /setup/export imports.
4. If you must restore manually, extract the archive on the target host and use the top-level manifest.json to map payload contents back to the host paths recorded in the archive.

Archive:
$target
''';
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) {
      _records = const [];
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _records = const [];
        return;
      }

      _records = decoded
          .whereType<Map>()
          .map((entry) =>
              OpenClawBackupRecord.fromJson(Map<String, dynamic>.from(entry)))
          .where((entry) => entry.id.isNotEmpty && entry.archivePath.isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      _records = const [];
    }
  }

  Future<void> _persistRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final payload =
        jsonEncode(_records.map((entry) => entry.toJson()).toList());
    await prefs.setString(_recordsKey, payload);
  }

  Future<void> _upsertRecord(OpenClawBackupRecord record) async {
    final next = [..._records.where((entry) => entry.id != record.id), record]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _records = next;
    await _persistRecords();
    notifyListeners();
  }

  Future<OpenClawBackupActionResult> _runTrackedCommand({
    required String label,
    required String description,
    required OpenClawBackupScope scope,
    required String Function(String archivePath) buildScript,
    Future<void> Function(
      OpenClawBackupRecord? record,
      Map<String, dynamic>? json,
    )? onSuccess,
    String? archivePath,
    bool createRecord = true,
  }) async {
    _isBusy = true;
    _lastError = null;
    notifyListeners();

    final now = DateTime.now().toUtc();
    final generatedArchivePath = archivePath ?? _buildArchivePath(now);
    final recordId = '${now.microsecondsSinceEpoch}-${scope.name}';
    OpenClawBackupRecord? record;

    if (createRecord) {
      record = OpenClawBackupRecord(
        id: recordId,
        archivePath: generatedArchivePath,
        createdAt: now,
        scope: scope,
        status: OpenClawBackupStatus.pending,
        verified: false,
        message: 'Command sent to Termux.',
      );
      await _upsertRecord(record);
    }

    try {
      final result = await _bridge.runCommandDetailed(
        script: buildScript(generatedArchivePath),
        label: label,
        description: description,
        waitForResultMs: 10000,
      );

      if (result.requiresAllowExternalApps) {
        const message =
            'Termux blocked the command. Enable allow-external-apps=true, reload Termux settings, then retry.';
        _lastError = message;
        if (record != null) {
          await _upsertRecord(record.copyWith(
            status: OpenClawBackupStatus.failed,
            message: message,
          ));
        }
        return OpenClawBackupActionResult(
          success: false,
          pending: false,
          message: message,
          record: record,
        );
      }

      if (!result.ok) {
        final message = _describeTermuxFailure(
          result,
          fallback: 'OpenClaw command failed.',
        );
        _lastError = message;
        if (record != null) {
          await _upsertRecord(record.copyWith(
            status: OpenClawBackupStatus.failed,
            message: message,
          ));
        }
        return OpenClawBackupActionResult(
          success: false,
          pending: false,
          message: message,
          record: record,
        );
      }

      final json = _tryParseJsonObject(result.stdout);
      final resolvedArchivePath =
          json?['archivePath']?.toString() ?? generatedArchivePath;
      final createdAt =
          DateTime.tryParse(json?['createdAt']?.toString() ?? '') ?? now;
      final verified = json?['verified'] == true;

      if (record != null) {
        record = record.copyWith(
          archivePath: resolvedArchivePath,
          createdAt: createdAt,
          status: result.pending
              ? OpenClawBackupStatus.pending
              : OpenClawBackupStatus.completed,
          verified: verified,
          message: result.pending
              ? 'Command accepted. Check Termux for completion.'
              : verified
                  ? 'Archive created and verified.'
                  : 'Archive created.',
        );
        await _upsertRecord(record);
      }

      if (onSuccess != null) {
        await onSuccess(record, json);
      }

      return OpenClawBackupActionResult(
        success: true,
        pending: result.pending,
        message: result.pending
            ? 'Command accepted by Termux. Watch the Termux session for completion.'
            : verified
                ? 'Archive created and verified.'
                : 'Command completed successfully.',
        record: record,
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _buildArchivePath(DateTime timestamp) {
    final safeTimestamp = timestamp.toIso8601String().replaceAll(':', '-');
    return '$_backupRoot/$safeTimestamp-openclaw-backup.tar.gz';
  }

  Map<String, dynamic>? _tryParseJsonObject(String? stdout) {
    if (stdout == null) return null;
    final trimmed = stdout.trim();
    if (trimmed.isEmpty) return null;

    try {
      final direct = jsonDecode(trimmed);
      if (direct is Map<String, dynamic>) {
        return direct;
      }
    } catch (_) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start == -1 || end <= start) {
        return null;
      }

      try {
        final partial = jsonDecode(trimmed.substring(start, end + 1));
        if (partial is Map<String, dynamic>) {
          return partial;
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  String _describeTermuxFailure(
    TermuxCommandResult result, {
    required String fallback,
  }) {
    if (result.errorMessage != null && result.errorMessage!.trim().isNotEmpty) {
      return result.errorMessage!.trim();
    }
    if (result.stderr != null && result.stderr!.trim().isNotEmpty) {
      return result.stderr!.trim();
    }
    if (result.stdout != null && result.stdout!.trim().isNotEmpty) {
      return result.stdout!.trim();
    }
    return fallback;
  }

  String _shellQuote(String input) {
    return "'${input.replaceAll("'", "'\"'\"'")}'";
  }
}
