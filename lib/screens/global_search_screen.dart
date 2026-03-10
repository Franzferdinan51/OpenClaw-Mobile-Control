import 'package:flutter/material.dart';
import '../services/global_search_service.dart';
import '../services/gateway_service.dart';
import '../data/agency_agents.dart';
import 'agent_detail_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';

/// Global search screen with search bar, filters, and results
class GlobalSearchScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const GlobalSearchScreen({super.key, this.gatewayService});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final GlobalSearchService _searchService;
  
  List<SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  String? _error;
  
  // Filter state
  Set<SearchCategory> _selectedCategories = {
    SearchCategory.messages,
    SearchCategory.agents,
    SearchCategory.nodes,
    SearchCategory.settings,
    SearchCategory.actions,
  };

  @override
  void initState() {
    super.initState();
    _searchService = GlobalSearchService(gatewayService: widget.gatewayService);
    _loadRecentSearches();
    
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final recent = await _searchService.getRecentSearches();
    setState(() {
      _recentSearches = recent;
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _searchService.search(query);
      
      // Filter by selected categories
      final filteredResults = results.where((r) => _selectedCategories.contains(r.categoryEnum)).toList();
      
      // Save to recent searches
      await _searchService.saveRecentSearch(query);
      
      setState(() {
        _results = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    // Debounce search
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text == query && query.isNotEmpty) {
        _performSearch(query);
      }
    });
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _results = [];
    });
  }

  void _toggleCategory(SearchCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        if (_selectedCategories.length > 1) { // Keep at least one category
          _selectedCategories.remove(category);
        }
      } else {
        _selectedCategories.add(category);
      }
    });
    
    // Re-run search with new filters
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _onResultTap(SearchResult result) {
    // Navigate based on result category
    switch (result.categoryEnum) {
      case SearchCategory.messages:
        _navigateToMessage(result);
        break;
      case SearchCategory.agents:
        _navigateToAgent(result);
        break;
      case SearchCategory.nodes:
        _navigateToNode(result);
        break;
      case SearchCategory.settings:
        _navigateToSetting(result);
        break;
      case SearchCategory.actions:
        _executeAction(result);
        break;
    }
  }

  void _navigateToMessage(SearchResult result) {
    // Navigate to chat screen
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
    
    // Show snackbar with message preview
    if (result.metadata?['content'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Found: "${result.title}"',
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToAgent(SearchResult result) {
    Navigator.pop(context);
    
    final metadata = result.metadata;
    
    // Check if it's an agent from library
    if (metadata?['agentId'] != null) {
      final agent = AgencyAgentsData.allAgents.firstWhere(
        (a) => a.id == metadata!['agentId'],
        orElse: () => AgencyAgentsData.allAgents.first,
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgentDetailScreen(
            agent: agent,
            onActivate: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatScreen(),
                ),
              );
            },
          ),
        ),
      );
    } else if (metadata?['sessionKey'] != null) {
      // Active agent session - navigate to chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatScreen(),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agent: ${metadata?['agentName']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToNode(SearchResult result) {
    Navigator.pop(context);
    
    // Navigate to dashboard and show node info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Node: ${result.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToSetting(SearchResult result) {
    Navigator.pop(context);
    
    // Navigate to settings screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
    
    // Show hint about specific setting
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${result.title}...'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _executeAction(SearchResult result) {
    Navigator.pop(context);
    
    final actionId = result.metadata?['actionId'];
    
    // Execute action based on ID
    switch (actionId) {
      case 'status':
      case 'photo':
      case 'analyze':
      case 'backup':
      case 'restart':
      case 'update':
      case 'weather':
      case 'forecast':
      case 'chat':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatScreen(),
          ),
        );
        break;
      case 'research':
      case 'code':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatScreen(),
          ),
        );
        break;
      case 'termux':
      case 'logs':
      case 'workflows':
      case 'tasks':
      case 'models':
        // Navigate to appropriate screen
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action: ${result.title}'),
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
              tooltip: 'Clear search',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          
          // Category filters
          _buildCategoryFilters(),
          
          // Results or recent searches
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _searchController.text.isEmpty
                        ? _buildRecentSearches()
                        : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search messages, agents, nodes, settings...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: _performSearch,
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: SearchCategory.values.map((category) {
          final isSelected = _selectedCategories.contains(category);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category.label),
              avatar: Icon(
                category.icon,
                size: 16,
                color: isSelected ? Colors.white : category.color,
              ),
              selected: isSelected,
              selectedColor: category.color,
              onSelected: (_) => _toggleCategory(category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _searchService.clearRecentSearches();
                  setState(() {
                    _recentSearches = [];
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                trailing: IconButton(
                  icon: const Icon(Icons.north_west),
                  onPressed: () => _onRecentSearchTap(query),
                  tooltip: 'Search again',
                ),
                onTap: () => _onRecentSearchTap(query),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return _buildNoResultsState();
    }

    // Group results by category
    final groupedResults = <SearchCategory, List<SearchResult>>{};
    for (final result in _results) {
      groupedResults.putIfAbsent(result.categoryEnum, () => []).add(result);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedResults.length,
      itemBuilder: (context, index) {
        final category = groupedResults.keys.elementAt(index);
        final results = groupedResults[category]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(category.icon, size: 20, color: category.color),
                  const SizedBox(width: 8),
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: category.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${results.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: category.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Results for this category
            ...results.map((result) => _buildResultCard(result)),
            
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildResultCard(SearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: result.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(result.icon, color: result.color),
        ),
        title: Text(
          result.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: result.subtitle != null
            ? Text(
                result.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _onResultTap(result),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Search Everything',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Find messages, agents, nodes,\nsettings, and actions',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip('weather'),
              _buildSuggestionChip('chat'),
              _buildSuggestionChip('agent'),
              _buildSuggestionChip('settings'),
              _buildSuggestionChip('backup'),
              _buildSuggestionChip('restart'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String query) {
    return ActionChip(
      label: Text(query),
      onPressed: () => _onRecentSearchTap(query),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Results Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'No results for "${_searchController.text}"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Try different keywords or check filters',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Search Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'An error occurred while searching',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _performSearch(_searchController.text),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}