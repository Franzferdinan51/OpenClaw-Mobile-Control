import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Favorite item model
class FavoriteItem {
  final String id;
  final String type;
  final String name;
  final String? description;
  final IconData? icon;
  final Map<String, dynamic>? data;
  final DateTime addedAt;

  FavoriteItem({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.icon,
    this.data,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'description': description,
    'icon': icon?.codePoint,
    'data': data,
    'addedAt': addedAt.toIso8601String(),
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'unknown',
      name: json['name'] ?? 'Unknown',
      description: json['description'],
      icon: json['icon'] != null ? IconData(json['icon'], fontFamily: 'MaterialIcons') : null,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt']) : DateTime.now(),
    );
  }
}

/// Favorites widget for managing favorite items
class FavoritesWidget extends StatefulWidget {
  final Function(FavoriteItem)? onItemTap;
  final Function(FavoriteItem)? onItemRemoved;
  final bool showAddButton;
  final String? filterType;

  const FavoritesWidget({
    super.key,
    this.onItemTap,
    this.onItemRemoved,
    this.showAddButton = true,
    this.filterType,
  });

  @override
  State<FavoritesWidget> createState() => _FavoritesWidgetState();
}

class _FavoritesWidgetState extends State<FavoritesWidget> {
  List<FavoriteItem> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('favorites');
    
    if (json != null) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        setState(() {
          _favorites = decoded.map((e) => FavoriteItem.fromJson(e)).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _favorites = [];
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'favorites',
      jsonEncode(_favorites.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _removeFavorite(FavoriteItem item) async {
    setState(() {
      _favorites.removeWhere((f) => f.id == item.id);
    });
    await _saveFavorites();
    widget.onItemRemoved?.call(item);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${item.name}" from favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _favorites.add(item);
              });
              await _saveFavorites();
            },
          ),
        ),
      );
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'action';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.star),
                SizedBox(width: 8),
                Text('Add Favorite'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter a name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'action',
                    'conversation',
                    'gateway',
                    'command',
                    'script',
                  ].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type[0].toUpperCase() + type.substring(1)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedType = value ?? 'action');
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  
                  final item = FavoriteItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: selectedType,
                    name: nameController.text,
                    description: descController.text.isEmpty ? null : descController.text,
                    icon: _getIconForType(selectedType),
                    addedAt: DateTime.now(),
                  );
                  
                  setState(() {
                    _favorites.add(item);
                  });
                  await _saveFavorites();
                  
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'action':
        return Icons.bolt;
      case 'conversation':
        return Icons.chat;
      case 'gateway':
        return Icons.wifi;
      case 'command':
        return Icons.terminal;
      case 'script':
        return Icons.code;
      default:
        return Icons.star;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'action':
        return Colors.orange;
      case 'conversation':
        return Colors.blue;
      case 'gateway':
        return Colors.green;
      case 'command':
        return Colors.purple;
      case 'script':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  List<FavoriteItem> get _filteredFavorites {
    if (widget.filterType == null) return _favorites;
    return _favorites.where((f) => f.type == widget.filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _filteredFavorites;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Favorites',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (favorites.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${favorites.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.showAddButton)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showAddDialog,
                    tooltip: 'Add favorite',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (favorites.isEmpty)
              _buildEmptyState()
            else
              _buildFavoritesList(favorites),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.star_border,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No favorites yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (widget.showAddButton)
              TextButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add your first favorite'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(List<FavoriteItem> favorites) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final item = favorites[index];
        final color = _getColorForType(item.type);
        
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _removeFavorite(item),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.icon ?? Icons.star,
                color: color,
              ),
            ),
            title: Text(item.name),
            subtitle: item.description != null
                ? Text(
                    item.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    '${item.type[0].toUpperCase()}${item.type.substring(1)} • ${DateFormat('MMM dd').format(item.addedAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: widget.onItemTap != null
                  ? () => widget.onItemTap!(item)
                  : null,
            ),
            onTap: widget.onItemTap != null
                ? () => widget.onItemTap!(item)
                : null,
          ),
        );
      },
    );
  }
}

/// Extension to add/remove favorites
extension FavoritesExtension on FavoritesWidget {
  static Future<void> addFavorite(FavoriteItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('favorites');
    
    List<FavoriteItem> favorites = [];
    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      favorites = decoded.map((e) => FavoriteItem.fromJson(e)).toList();
    }
    
    // Check if already exists
    if (!favorites.any((f) => f.id == item.id)) {
      favorites.add(item);
      await prefs.setString(
        'favorites',
        jsonEncode(favorites.map((e) => e.toJson()).toList()),
      );
    }
  }

  static Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('favorites');
    
    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      final favorites = decoded.map((e) => FavoriteItem.fromJson(e)).toList();
      favorites.removeWhere((f) => f.id == id);
      await prefs.setString(
        'favorites',
        jsonEncode(favorites.map((e) => e.toJson()).toList()),
      );
    }
  }

  static Future<bool> isFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('favorites');
    
    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.any((e) => FavoriteItem.fromJson(e).id == id);
    }
    return false;
  }

  static Future<List<FavoriteItem>> getAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('favorites');
    
    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.map((e) => FavoriteItem.fromJson(e)).toList();
    }
    return [];
  }
}