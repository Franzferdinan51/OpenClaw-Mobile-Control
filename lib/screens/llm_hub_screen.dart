import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// LLM Hub - Compare Claude, ChatGPT, Gemini side-by-side
class LlmHubScreen extends StatefulWidget {
  const LlmHubScreen({super.key});

  @override
  State<LlmHubScreen> createState() => _LlmHubScreenState();
}

class _LlmHubScreenState extends State<LlmHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();
  
  // API configurations (user configurable)
  String _openaiKey = '';
  String _anthropicKey = '';
  String _googleKey = '';
  
  // Selected model for each provider
  String _selectedOpenAI = 'gpt-4o';
  String _selectedClaude = 'claude-sonnet-4-20250514';
  String _selectedGemini = 'gemini-2.0-flash';
  
  // Response storage
  final Map<String, List<ChatMessage>> _chatHistory = {
    'openai': [],
    'claude': [],
    'gemini': [],
  };
  
  bool _isLoading = false;
  String? _selectedTab;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedTab = 'openai';
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = ['openai', 'claude', 'gemini'][_tabController.index];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'OpenAI', icon: Icon(Icons.bolt)),
            Tab(text: 'Claude', icon: Icon(Icons.psychology)),
            Tab(text: 'Gemini', icon: Icon(Icons.auto_awesome)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab('openai', 'GPT-4o', _selectedOpenAI),
                _buildChatTab('claude', 'Claude', _selectedClaude),
                _buildChatTab('gemini', 'Gemini', _selectedGemini),
              ],
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatTab(String provider, String title, String model) {
    final messages = _chatHistory[provider] ?? [];
    
    return Column(
      children: [
        // Model selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[850],
          child: Row(
            children: [
              Text('$title Model:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _getModelForProvider(provider),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _getModelOptions(provider)
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => _setModelForProvider(provider, v!),
                ),
              ),
            ],
          ),
        ),
        // Chat messages
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Ask a question to $title',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configure API keys in settings',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[700] : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  size: 14,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  isUser ? 'You' : 'AI',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              msg.content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promptController,
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _sendPrompt(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isLoading ? null : _sendPrompt,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    _promptController.clear();
    
    // Add user message to all tabs
    for (final provider in _chatHistory.keys) {
      _chatHistory[provider]!.add(ChatMessage(role: 'user', content: prompt));
    }
    
    setState(() => _isLoading = true);

    try {
      String response;
      
      if (_selectedTab == 'openai') {
        response = await _callOpenAI(prompt);
      } else if (_selectedTab == 'claude') {
        response = await _callClaude(prompt);
      } else {
        response = await _callGemini(prompt);
      }
      
      _chatHistory[_selectedTab]!.add(ChatMessage(role: 'assistant', content: response));
      
    } catch (e) {
      _chatHistory[_selectedTab]!.add(ChatMessage(
        role: 'assistant', 
        content: 'Error: $e',
      ));
    }

    setState(() => _isLoading = false);
  }

  Future<String> _callOpenAI(String prompt) async {
    if (_openaiKey.isEmpty) {
      return 'Please configure your OpenAI API key in settings';
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_openaiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _selectedOpenAI,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 2000,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI API error: ${response.body}');
    }
  }

  Future<String> _callClaude(String prompt) async {
    if (_anthropicKey.isEmpty) {
      return 'Please configure your Anthropic API key in settings';
    }

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _anthropicKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _selectedClaude,
        'max_tokens': 2000,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'];
    } else {
      throw Exception('Claude API error: ${response.body}');
    }
  }

  Future<String> _callGemini(String prompt) async {
    if (_googleKey.isEmpty) {
      return 'Please configure your Google AI API key in settings';
    }

    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_selectedGemini:generateContent?key=$_googleKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Gemini API error: ${response.body}');
    }
  }

  void _showSettings() {
    final openaiController = TextEditingController(text: _openaiKey);
    final claudeController = TextEditingController(text: _anthropicKey);
    final geminiController = TextEditingController(text: _googleKey);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: openaiController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'OpenAI API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bolt),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: claudeController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Anthropic (Claude) API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.psychology),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: geminiController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Google AI (Gemini) API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.auto_awesome),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _openaiKey = openaiController.text.trim();
                    _anthropicKey = claudeController.text.trim();
                    _googleKey = geminiController.text.trim();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings saved')),
                  );
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getModelForProvider(String provider) {
    switch (provider) {
      case 'openai': return _selectedOpenAI;
      case 'claude': return _selectedClaude;
      case 'gemini': return _selectedGemini;
      default: return '';
    }
  }

  void _setModelForProvider(String provider, String model) {
    setState(() {
      switch (provider) {
        case 'openai': _selectedOpenAI = model; break;
        case 'claude': _selectedClaude = model; break;
        case 'gemini': _selectedGemini = model; break;
      }
    });
  }

  List<String> _getModelOptions(String provider) {
    switch (provider) {
      case 'openai':
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-4', 'gpt-3.5-turbo'];
      case 'claude':
        return ['claude-sonnet-4-20250514', 'claude-opus-4-20250514', 'claude-3-5-sonnet-20241022', 'claude-3-haiku-20240307'];
      case 'gemini':
        return ['gemini-2.0-flash', 'gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-1.0-pro'];
      default:
        return [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String role;
  final String content;
  
  ChatMessage({required this.role, required this.content});
}