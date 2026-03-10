/// Node Approval Service
/// 
/// Manages pending node pairing requests and approvals.
/// Works with NodeHostService to handle the approval workflow.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/node_connection.dart';
import 'node_host_service.dart';

/// Pending node pairing request
class PendingNodeRequest {
  final String id;
  final String name;
  final String ip;
  final DeviceType deviceType;
  final DateTime requestedAt;
  final String? userAgent;
  final String? token;
  final Map<String, dynamic> metadata;

  PendingNodeRequest({
    required this.id,
    required this.name,
    required this.ip,
    this.deviceType = DeviceType.unknown,
    DateTime? requestedAt,
    this.userAgent,
    this.token,
    this.metadata = const {},
  }) : requestedAt = requestedAt ?? DateTime.now();

  /// Display name for UI
  String get displayName => name.isNotEmpty ? name : ip;

  /// Time since request
  String get timeAgo {
    final diff = DateTime.now().difference(requestedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Device type icon
  IconData get deviceIcon {
    switch (deviceType) {
      case DeviceType.android:
        return Icons.phone_android;
      case DeviceType.ios:
        return Icons.phone_iphone;
      case DeviceType.desktop:
        return Icons.computer;
      case DeviceType.server:
        return Icons.dns;
      case DeviceType.iot:
        return Icons.router;
      case DeviceType.unknown:
        return Icons.device_unknown;
    }
  }

  /// Device type display name
  String get deviceTypeLabel {
    switch (deviceType) {
      case DeviceType.android:
        return 'Android';
      case DeviceType.ios:
        return 'iOS';
      case DeviceType.desktop:
        return 'Desktop';
      case DeviceType.server:
        return 'Server';
      case DeviceType.iot:
        return 'IoT Device';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }

  factory PendingNodeRequest.fromNodeConnection(NodeConnection conn) {
    return PendingNodeRequest(
      id: conn.id,
      name: conn.name,
      ip: conn.ip,
      deviceType: conn.deviceType,
      requestedAt: conn.connectedAt,
      userAgent: conn.userAgent,
      token: conn.authToken,
      metadata: conn.metadata,
    );
  }

  factory PendingNodeRequest.fromJson(Map<String, dynamic> json) {
    return PendingNodeRequest(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      deviceType: DeviceType.values.firstWhere(
        (e) => e.name == json['device_type'],
        orElse: () => DeviceType.unknown,
      ),
      requestedAt: json['requested_at'] != null
          ? DateTime.tryParse(json['requested_at']) ?? DateTime.now()
          : DateTime.now(),
      userAgent: json['user_agent'],
      token: json['token'],
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'device_type': deviceType.name,
    'requested_at': requestedAt.toIso8601String(),
    'user_agent': userAgent,
    'token': token,
    'metadata': metadata,
  };
}

/// Approved node record
class ApprovedNode {
  final String id;
  final String name;
  final String ip;
  final DeviceType deviceType;
  final DateTime approvedAt;
  final String? approvedBy;
  final bool isWhitelisted;
  final DateTime lastConnected;
  final int connectionCount;

  ApprovedNode({
    required this.id,
    required this.name,
    required this.ip,
    this.deviceType = DeviceType.unknown,
    DateTime? approvedAt,
    this.approvedBy,
    this.isWhitelisted = false,
    DateTime? lastConnected,
    this.connectionCount = 1,
  }) : approvedAt = approvedAt ?? DateTime.now(),
       lastConnected = lastConnected ?? DateTime.now();

  String get displayName => name.isNotEmpty ? name : ip;

  factory ApprovedNode.fromJson(Map<String, dynamic> json) {
    return ApprovedNode(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      deviceType: DeviceType.values.firstWhere(
        (e) => e.name == json['device_type'],
        orElse: () => DeviceType.unknown,
      ),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at']) ?? DateTime.now()
          : DateTime.now(),
      approvedBy: json['approved_by'],
      isWhitelisted: json['is_whitelisted'] ?? false,
      lastConnected: json['last_connected'] != null
          ? DateTime.tryParse(json['last_connected']) ?? DateTime.now()
          : DateTime.now(),
      connectionCount: json['connection_count'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'device_type': deviceType.name,
    'approved_at': approvedAt.toIso8601String(),
    'approved_by': approvedBy,
    'is_whitelisted': isWhitelisted,
    'last_connected': lastConnected.toIso8601String(),
    'connection_count': connectionCount,
  };

  ApprovedNode copyWith({
    String? id,
    String? name,
    String? ip,
    DeviceType? deviceType,
    DateTime? approvedAt,
    String? approvedBy,
    bool? isWhitelisted,
    DateTime? lastConnected,
    int? connectionCount,
  }) {
    return ApprovedNode(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      deviceType: deviceType ?? this.deviceType,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      isWhitelisted: isWhitelisted ?? this.isWhitelisted,
      lastConnected: lastConnected ?? this.lastConnected,
      connectionCount: connectionCount ?? this.connectionCount,
    );
  }
}

/// Node Approval Service
/// 
/// Manages pending pairing requests and approved nodes.
/// Integrates with NodeHostService for real-time updates.
class NodeApprovalService extends ChangeNotifier {
  static const String _pendingKey = 'node_pending_requests';
  static const String _approvedKey = 'node_approved_nodes';
  static const String _autoApproveKey = 'node_auto_approve';

  final NodeHostService? _hostService;
  
  List<PendingNodeRequest> _pendingRequests = [];
  List<ApprovedNode> _approvedNodes = [];
  bool _autoApprove = false;
  StreamSubscription<NodeHostEvent>? _eventSubscription;

  NodeApprovalService({NodeHostService? hostService}) : _hostService = hostService {
    _loadFromStorage();
    _listenToHostEvents();
  }

  /// List of pending requests
  List<PendingNodeRequest> get pendingRequests => List.unmodifiable(_pendingRequests);

  /// List of approved nodes
  List<ApprovedNode> get approvedNodes => List.unmodifiable(_approvedNodes);

  /// Number of pending requests
  int get pendingCount => _pendingRequests.length;

  /// Whether auto-approve is enabled
  bool get autoApproveEnabled => _autoApprove;

  /// Stream of approval events
  final StreamController<NodeApprovalEvent> _eventController = 
      StreamController<NodeApprovalEvent>.broadcast();
  Stream<NodeApprovalEvent> get eventStream => _eventController.stream;

  /// Initialize with host service
  void setHostService(NodeHostService hostService) {
    _eventSubscription?.cancel();
    _eventSubscription = hostService.eventStream.listen(_handleHostEvent);
  }

  /// Load data from storage
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load pending requests
      final pendingJson = prefs.getStringList(_pendingKey) ?? [];
      _pendingRequests = pendingJson
          .map((j) => PendingNodeRequest.fromJson(
              Map<String, dynamic>.from(_parseJson(j))))
          .toList();
      
      // Load approved nodes
      final approvedJson = prefs.getStringList(_approvedKey) ?? [];
      _approvedNodes = approvedJson
          .map((j) => ApprovedNode.fromJson(
              Map<String, dynamic>.from(_parseJson(j))))
          .toList();
      
      // Load auto-approve setting
      _autoApprove = prefs.getBool(_autoApproveKey) ?? false;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load node approval data: $e');
    }
  }

  /// Save data to storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setStringList(
        _pendingKey,
        _pendingRequests.map((r) => _toJson(r.toJson())).toList(),
      );
      
      await prefs.setStringList(
        _approvedKey,
        _approvedNodes.map((n) => _toJson(n.toJson())).toList(),
      );
      
      await prefs.setBool(_autoApproveKey, _autoApprove);
    } catch (e) {
      debugPrint('Failed to save node approval data: $e');
    }
  }

  /// Get pending requests
  Future<List<PendingNodeRequest>> getPendingRequests() async {
    return _pendingRequests;
  }

  /// Approve a pending request
  Future<bool> approveNode(String nodeId) async {
    final index = _pendingRequests.indexWhere((r) => r.id == nodeId);
    if (index == -1) return false;

    final request = _pendingRequests[index];
    
    // Create approved node
    final approvedNode = ApprovedNode(
      id: request.id,
      name: request.name,
      ip: request.ip,
      deviceType: request.deviceType,
    );
    
    // Remove from pending, add to approved
    _pendingRequests.removeAt(index);
    _approvedNodes.add(approvedNode);
    
    // Approve in host service
    try {
      await _hostService?.approveConnection(nodeId);
    } catch (e) {
      debugPrint('Failed to approve in host service: $e');
    }
    
    await _saveToStorage();
    notifyListeners();
    
    _eventController.add(NodeApprovalEvent.nodeApproved(nodeId, request));
    return true;
  }

  /// Reject a pending request
  Future<bool> rejectNode(String nodeId) async {
    final index = _pendingRequests.indexWhere((r) => r.id == nodeId);
    if (index == -1) return false;

    final request = _pendingRequests[index];
    _pendingRequests.removeAt(index);
    
    // Reject in host service
    try {
      await _hostService?.rejectConnection(nodeId);
    } catch (e) {
      debugPrint('Failed to reject in host service: $e');
    }
    
    await _saveToStorage();
    notifyListeners();
    
    _eventController.add(NodeApprovalEvent.nodeRejected(nodeId, request));
    return true;
  }

  /// Set auto-approve mode
  Future<void> setAutoApprove(bool enabled) async {
    _autoApprove = enabled;
    await _saveToStorage();
    notifyListeners();
    
    _eventController.add(NodeApprovalEvent.autoApproveChanged(enabled));
    
    // If enabled, approve all pending
    if (enabled && _pendingRequests.isNotEmpty) {
      for (final request in List.from(_pendingRequests)) {
        await approveNode(request.id);
      }
    }
  }

  /// Get approved nodes
  Future<List<ApprovedNode>> getApprovedNodes() async {
    return _approvedNodes;
  }

  /// Remove an approved node
  Future<bool> removeApprovedNode(String nodeId) async {
    final index = _approvedNodes.indexWhere((n) => n.id == nodeId);
    if (index == -1) return false;

    _approvedNodes.removeAt(index);
    await _saveToStorage();
    notifyListeners();
    
    _eventController.add(NodeApprovalEvent.nodeRemoved(nodeId));
    return true;
  }

  /// Toggle whitelist for approved node
  Future<void> toggleWhitelist(String nodeId) async {
    final index = _approvedNodes.indexWhere((n) => n.id == nodeId);
    if (index == -1) return;

    _approvedNodes[index] = _approvedNodes[index].copyWith(
      isWhitelisted: !_approvedNodes[index].isWhitelisted,
    );
    
    await _saveToStorage();
    notifyListeners();
  }

  /// Add a pending request manually (for testing or external sources)
  void addPendingRequest(PendingNodeRequest request) {
    // Check if already pending
    if (_pendingRequests.any((r) => r.id == request.id)) return;
    
    // Check if already approved
    if (_approvedNodes.any((n) => n.id == request.id)) return;
    
    // Auto-approve if enabled
    if (_autoApprove) {
      final approvedNode = ApprovedNode(
        id: request.id,
        name: request.name,
        ip: request.ip,
        deviceType: request.deviceType,
      );
      _approvedNodes.add(approvedNode);
      _saveToStorage();
      notifyListeners();
      return;
    }
    
    _pendingRequests.add(request);
    _saveToStorage();
    notifyListeners();
    
    _eventController.add(NodeApprovalEvent.requestReceived(request));
  }

  /// Handle events from host service
  void _listenToHostEvents() {
    if (_hostService == null) return;
    _eventSubscription = _hostService!.eventStream.listen(_handleHostEvent);
  }

  void _handleHostEvent(NodeHostEvent event) {
    if (event is ConnectionPendingEvent) {
      // Find the connection in host service
      final connection = _hostService?.connections.firstWhere(
        (c) => c.id == event.connectionId,
        orElse: () => NodeConnection(
          id: event.connectionId,
          name: '',
          ip: event.ip,
          status: ConnectionStatus.pending,
        ),
      );
      
      if (connection != null) {
        addPendingRequest(PendingNodeRequest.fromNodeConnection(connection));
      }
    } else if (event is ConnectionApprovedEvent) {
      // Remove from pending if present
      _pendingRequests.removeWhere((r) => r.id == event.connectionId);
      notifyListeners();
    } else if (event is ConnectionRejectedEvent) {
      // Remove from pending if present
      _pendingRequests.removeWhere((r) => r.id == event.connectionId);
      notifyListeners();
    }
  }

  /// Clear all pending requests
  Future<void> clearPendingRequests() async {
    _pendingRequests.clear();
    await _saveToStorage();
    notifyListeners();
  }

  /// Clear all approved nodes
  Future<void> clearApprovedNodes() async {
    _approvedNodes.clear();
    await _saveToStorage();
    notifyListeners();
  }

  String _toJson(Map<String, dynamic> map) {
    return map.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  Map<String, dynamic> _parseJson(String str) {
    final map = <String, dynamic>{};
    for (final pair in str.split('&')) {
      final kv = pair.split('=');
      if (kv.length == 2) {
        map[kv[0]] = kv[1];
      }
    }
    return map;
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
    super.dispose();
  }
}

/// Events emitted by NodeApprovalService
sealed class NodeApprovalEvent {
  const NodeApprovalEvent();

  const factory NodeApprovalEvent.requestReceived(PendingNodeRequest request) = 
      RequestReceivedEvent;
  const factory NodeApprovalEvent.nodeApproved(String nodeId, PendingNodeRequest request) = 
      NodeApprovedEvent;
  const factory NodeApprovalEvent.nodeRejected(String nodeId, PendingNodeRequest request) = 
      NodeRejectedEvent;
  const factory NodeApprovalEvent.nodeRemoved(String nodeId) = 
      NodeRemovedEvent;
  const factory NodeApprovalEvent.autoApproveChanged(bool enabled) = 
      AutoApproveChangedEvent;
}

class RequestReceivedEvent implements NodeApprovalEvent {
  final PendingNodeRequest request;
  const RequestReceivedEvent(this.request);
}

class NodeApprovedEvent implements NodeApprovalEvent {
  final String nodeId;
  final PendingNodeRequest request;
  const NodeApprovedEvent(this.nodeId, this.request);
}

class NodeRejectedEvent implements NodeApprovalEvent {
  final String nodeId;
  final PendingNodeRequest request;
  const NodeRejectedEvent(this.nodeId, this.request);
}

class NodeRemovedEvent implements NodeApprovalEvent {
  final String nodeId;
  const NodeRemovedEvent(this.nodeId);
}

class AutoApproveChangedEvent implements NodeApprovalEvent {
  final bool enabled;
  const AutoApproveChangedEvent(this.enabled);
}

/// Provider for NodeApprovalService
class NodeApprovalProvider extends ChangeNotifier {
  NodeApprovalService? _service;
  NodeHostService? _hostService;
  
  List<PendingNodeRequest> _pendingRequests = [];
  List<ApprovedNode> _approvedNodes = [];
  bool _autoApprove = false;
  bool _initialized = false;

  NodeApprovalProvider();

  /// Initialize with optional host service
  Future<void> initialize({NodeHostService? hostService}) async {
    if (_initialized) return;
    
    _hostService = hostService;
    _service = NodeApprovalService(hostService: hostService);
    
    _pendingRequests = await _service!.getPendingRequests();
    _approvedNodes = await _service!.getApprovedNodes();
    _autoApprove = _service!.autoApproveEnabled;
    
    _service!.addListener(_onServiceChanged);
    _initialized = true;
    
    notifyListeners();
  }

  void _onServiceChanged() {
    if (_service == null) return;
    _pendingRequests = _service!.pendingRequests;
    _approvedNodes = _service!.approvedNodes;
    _autoApprove = _service!.autoApproveEnabled;
    notifyListeners();
  }

  List<PendingNodeRequest> get pendingRequests => _pendingRequests;
  List<ApprovedNode> get approvedNodes => _approvedNodes;
  int get pendingCount => _pendingRequests.length;
  bool get autoApproveEnabled => _autoApprove;
  bool get hasPendingRequests => _pendingRequests.isNotEmpty;

  Future<void> approveNode(String nodeId) async {
    await _service?.approveNode(nodeId);
  }

  Future<void> rejectNode(String nodeId) async {
    await _service?.rejectNode(nodeId);
  }

  Future<void> setAutoApprove(bool enabled) async {
    await _service?.setAutoApprove(enabled);
  }

  Future<void> removeApprovedNode(String nodeId) async {
    await _service?.removeApprovedNode(nodeId);
  }

  Future<void> toggleWhitelist(String nodeId) async {
    await _service?.toggleWhitelist(nodeId);
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceChanged);
    _service?.dispose();
    super.dispose();
  }
}