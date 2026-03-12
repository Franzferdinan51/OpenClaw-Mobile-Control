import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GatewayDeviceIdentity {
  final String deviceId;
  final String publicKey;
  final String privateKey;

  const GatewayDeviceIdentity({
    required this.deviceId,
    required this.publicKey,
    required this.privateKey,
  });
}

class GatewayDeviceAuthToken {
  final String token;
  final List<String> scopes;

  const GatewayDeviceAuthToken({
    required this.token,
    required this.scopes,
  });
}

class GatewayDeviceIdentityService {
  GatewayDeviceIdentityService._();

  static const String _identityKey = 'openclaw_device_identity_v1';
  static const String _deviceTokenPrefix = 'openclaw_device_token_v1';
  static final GatewayDeviceIdentityService instance =
      GatewayDeviceIdentityService._();
  static final Ed25519 _algorithm = Ed25519();
  static final Sha256 _sha256 = Sha256();

  Future<GatewayDeviceIdentity> loadOrCreateIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_identityKey);
    if (raw != null && raw.isNotEmpty) {
      final parsed = _parseIdentity(raw);
      if (parsed != null) {
        return parsed;
      }
    }

    final keyPair = await _algorithm.newKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = publicKey.bytes;
    final deviceId = await _fingerprintPublicKey(publicKeyBytes);

    final identity = GatewayDeviceIdentity(
      deviceId: deviceId,
      publicKey: _base64UrlEncode(publicKeyBytes),
      privateKey: _base64UrlEncode(privateKeyBytes),
    );

    await prefs.setString(
      _identityKey,
      jsonEncode({
        'version': 1,
        'deviceId': identity.deviceId,
        'publicKey': identity.publicKey,
        'privateKey': identity.privateKey,
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    return identity;
  }

  Future<String> signPayload(
    GatewayDeviceIdentity identity,
    String payload,
  ) async {
    final privateKeyBytes = _base64UrlDecode(identity.privateKey);
    final publicKeyBytes = _base64UrlDecode(identity.publicKey);
    final signature = await _algorithm.sign(
      utf8.encode(payload),
      keyPair: SimpleKeyPairData(
        privateKeyBytes,
        publicKey: SimplePublicKey(
          publicKeyBytes,
          type: KeyPairType.ed25519,
        ),
        type: KeyPairType.ed25519,
      ),
    );
    return _base64UrlEncode(signature.bytes);
  }

  Future<GatewayDeviceAuthToken?> loadDeviceToken({
    required String deviceId,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deviceTokenStorageKey(deviceId, role));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final token = decoded['token']?.toString().trim() ?? '';
      if (token.isEmpty) {
        return null;
      }
      final scopes = (decoded['scopes'] as List<dynamic>? ?? const <dynamic>[])
          .map((scope) => scope.toString())
          .where((scope) => scope.isNotEmpty)
          .toList();
      return GatewayDeviceAuthToken(token: token, scopes: scopes);
    } catch (_) {
      return null;
    }
  }

  Future<void> storeDeviceToken({
    required String deviceId,
    required String role,
    required String token,
    List<String> scopes = const <String>[],
  }) async {
    if (token.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _deviceTokenStorageKey(deviceId, role),
      jsonEncode({
        'token': token.trim(),
        'scopes': scopes,
        'storedAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  String buildAuthPayloadV3({
    required String deviceId,
    required String clientId,
    required String clientMode,
    required String role,
    required List<String> scopes,
    required int signedAtMs,
    required String nonce,
    String? token,
    String? platform,
    String? deviceFamily,
  }) {
    final normalizedToken = token ?? '';
    return <String>[
      'v3',
      deviceId,
      clientId,
      clientMode,
      role,
      scopes.join(','),
      signedAtMs.toString(),
      normalizedToken,
      nonce,
      _normalizeDeviceMetadataForAuth(platform),
      _normalizeDeviceMetadataForAuth(deviceFamily),
    ].join('|');
  }

  GatewayDeviceIdentity? _parseIdentity(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final publicKey = decoded['publicKey']?.toString() ?? '';
      final privateKey = decoded['privateKey']?.toString() ?? '';
      if (publicKey.isEmpty || privateKey.isEmpty) {
        return null;
      }
      return GatewayDeviceIdentity(
        deviceId: decoded['deviceId']?.toString() ??
            publicKey.hashCode.toRadixString(16),
        publicKey: publicKey,
        privateKey: privateKey,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _fingerprintPublicKey(List<int> publicKeyBytes) async {
    final digest = await _sha256.hash(publicKeyBytes);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _deviceTokenStorageKey(String deviceId, String role) =>
      '$_deviceTokenPrefix:${deviceId.trim()}:${role.trim()}';

  String _normalizeDeviceMetadataForAuth(String? value) {
    if (value == null) {
      return '';
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 32),
    );
  }

  String _base64UrlEncode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  List<int> _base64UrlDecode(String value) {
    final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    final padding = '=' * ((4 - normalized.length % 4) % 4);
    return base64.decode('$normalized$padding');
  }
}
