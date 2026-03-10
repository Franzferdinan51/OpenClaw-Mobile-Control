# Implementation Plan for Cherry-Picked Features

**Target Version:** v2.1  
**Timeline:** 2-4 weeks  
**Priority:** Top 10 features from cherry_picked_features.md

---

## 📋 Overview

This document provides step-by-step implementation guides for the top 10 features identified in the research. Each feature includes:
- Prerequisites
- Code structure
- Implementation steps
- Testing checklist
- Integration notes

---

## 🚀 Phase 1: Core Features (Week 1-2)

### Feature 1: Chat Export (Markdown, PDF, JSON, TXT)

**Estimated Time:** 4-6 hours  
**Priority:** HIGH  
**Difficulty:** EASY

#### Step 1: Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  share_plus: ^7.2.1
  pdf: ^3.10.7
  path_provider: ^2.1.1
  printing: ^5.12.0  # For PDF preview
```

#### Step 2: Create Export Service

```dart
// lib/services/export_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

enum ExportFormat {
  markdown,
  pdf,
  json,
  txt,
}

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Export a single conversation
  Future<void> exportConversation(
    Conversation conversation, {
    required ExportFormat format,
    bool shareImmediately = true,
  }) async {
    final content = await _generateContent(conversation, format);
    final fileName = _getFileName(conversation, format);
    final file = await _saveFile(content, fileName, format);

    if (shareImmediately) {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Chat: ${conversation.title}',
      );
    }
  }

  /// Export multiple conversations
  Future<void> exportMultiple(
    List<Conversation> conversations, {
    required ExportFormat format,
  }) async {
    final archive = await _createArchive(conversations, format);
    await Share.shareXFiles(
      [XFile(archive.path)],
      subject: 'Exported ${conversations.length} conversations',
    );
  }

  /// Generate content based on format
  Future<dynamic> _generateContent(
    Conversation conversation,
    ExportFormat format,
  ) async {
    switch (format) {
      case ExportFormat.markdown:
        return _toMarkdown(conversation);
      case ExportFormat.pdf:
        return await _toPdf(conversation);
      case ExportFormat.json:
        return _toJson(conversation);
      case ExportFormat.txt:
        return _toText(conversation);
    }
  }

  /// Convert to Markdown
  String _toMarkdown(Conversation conversation) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('# ${conversation.title}');
    buffer.writeln('');
    buffer.writeln('**Date:** ${_formatDate(conversation.createdAt)}');
    if (conversation.agentId != null) {
      buffer.writeln('**Agent:** ${conversation.agentName ?? "Unknown"}');
    }
    buffer.writeln('---');
    buffer.writeln('');

    // Messages
    for (final message in conversation.messages) {
      final role = message.role == 'user' ? '👤 **You**' : '🤖 **AI**';
      buffer.writeln('### $role');
      buffer.writeln('');
      buffer.writeln(message.content);
      buffer.writeln('');
      if (message.timestamp != null) {
        buffer.writeln('> ${_formatTime(message.timestamp!)}');
        buffer.writeln('');
      }
    }

    // Footer
    buffer.writeln('---');
    buffer.writeln('*Exported from DuckBot on ${_formatDate(DateTime.now())}*');

    return buffer.toString();
  }

  /// Convert to PDF
  Future<Uint8List> _toPdf(Conversation conversation) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        header: (context) => pw.Header(
          level: 0,
          child: pw.Text(
            conversation.title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          pw.Text(
            'Date: ${_formatDate(conversation.createdAt)}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
          ),
          if (conversation.agentId != null)
            pw.Text(
              'Agent: ${conversation.agentName ?? "Unknown"}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
            ),
          pw.SizedBox(height: 24),
          ...conversation.messages.map((message) => _buildPdfMessage(message)),
          pw.SizedBox(height: 32),
          pw.Divider(),
          pw.Text(
            'Exported from DuckBot on ${_formatDate(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfMessage(ChatMessage message) {
    final isUser = message.role == 'user';
    return pw.Container(
      margin: pw.EdgeInsets.symmetric(vertical: 8),
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: isUser ? PdfColors.blue50 : PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            isUser ? '👤 You' : '🤖 AI',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: isUser ? PdfColors.blue : PdfColors.green,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(message.content),
          if (message.timestamp != null)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                _formatTime(message.timestamp!),
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ),
        ],
      ),
    );
  }

  /// Convert to JSON
  String _toJson(Conversation conversation) {
    final data = {
      'version': '2.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'conversation': {
        'id': conversation.id,
        'title': conversation.title,
        'createdAt': conversation.createdAt.toIso8601String(),
        'agentId': conversation.agentId,
        'agentName': conversation.agentName,
        'messages': conversation.messages.map((m) => {
          'id': m.id,
          'role': m.role,
          'content': m.content,
          'timestamp': m.timestamp?.toIso8601String(),
        }).toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Convert to plain text
  String _toText(Conversation conversation) {
    final buffer = StringBuffer();

    buffer.writeln('Conversation: ${conversation.title}');
    buffer.writeln('Date: ${_formatDate(conversation.createdAt)}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final message in conversation.messages) {
      final prefix = message.role == 'user' ? '[You]' : '[AI]';
      buffer.writeln('$prefix: ${message.content}');
      buffer.writeln();
    }

    buffer.writeln('=' * 50);
    buffer.writeln('Exported from DuckBot');

    return buffer.toString();
  }

  /// Save file to device
  Future<File> _saveFile(
    dynamic content,
    String fileName,
    ExportFormat format,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');

    if (content is Uint8List) {
      await file.writeAsBytes(content);
    } else {
      await file.writeAsString(content);
    }

    return file;
  }

  /// Generate filename
  String _getFileName(Conversation conversation, ExportFormat format) {
    final safeTitle = conversation.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, 30);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final extension = _getExtension(format);
    return '${safeTitle}_$timestamp.$extension';
  }

  String _getExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.markdown:
        return 'md';
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.json:
        return 'json';
      case ExportFormat.txt:
        return 'txt';
    }
  }

  /// Create ZIP archive of multiple conversations
  Future<File> _createArchive(
    List<Conversation> conversations,
    ExportFormat format,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final archiveDir = Directory('${directory.path}/export_temp');
    await archiveDir.create(recursive: true);

    // Write each conversation
    for (final conv in conversations) {
      final content = await _generateContent(conv, format);
      final fileName = _getFileName(conv, format);
      final file = File('${archiveDir.path}/$fileName');

      if (content is Uint8List) {
        await file.writeAsBytes(content);
      } else {
        await file.writeAsString(content);
      }
    }

    // TODO: Create ZIP using archive package
    // For now, just return first file
    return File('${archiveDir.path}/${_getFileName(conversations.first, format)}');
  }

  // Helper methods
  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
}
```

#### Step 3: Add Export UI to Chat Screen

```dart
// In chat_screen.dart, add to AppBar actions

PopupMenuButton<ExportFormat>(
  icon: Icon(Icons.share),
  onSelected: (format) async {
    await ExportService().exportConversation(
      currentConversation,
      format: format,
    );
  },
  itemBuilder: (context) => [
    PopupMenuItem(
      value: ExportFormat.markdown,
      child: Row(
        children: [
          Icon(Icons.description, color: Colors.blue),
          SizedBox(width: 8),
          Text('Export as Markdown'),
        ],
      ),
    ),
    PopupMenuItem(
      value: ExportFormat.pdf,
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: Colors.red),
          SizedBox(width: 8),
          Text('Export as PDF'),
        ],
      ),
    ),
    PopupMenuItem(
      value: ExportFormat.json,
      child: Row(
        children: [
          Icon(Icons.code, color: Colors.green),
          SizedBox(width: 8),
          Text('Export as JSON'),
        ],
      ),
    ),
    PopupMenuItem(
      value: ExportFormat.txt,
      child: Row(
        children: [
          Icon(Icons.text_snippet, color: Colors.grey),
          SizedBox(width: 8),
          Text('Export as Text'),
        ],
      ),
    ),
  ],
),
```

#### Step 4: Testing Checklist

- [ ] Export single conversation to Markdown
- [ ] Export single conversation to PDF
- [ ] Export single conversation to JSON
- [ ] Export single conversation to TXT
- [ ] Share dialog appears with correct file
- [ ] File content is correct
- [ ] PDF formatting is readable
- [ ] JSON is valid and parseable
- [ ] Timestamps are correct
- [ ] Works on Android

---

### Feature 2: Prompt Templates Library

**Estimated Time:** 3-4 hours  
**Priority:** HIGH  
**Difficulty:** EASY

#### Step 1: Create Prompt Template Model

```dart
// lib/models/prompt_template.dart

class PromptTemplate {
  final String id;
  final String name;
  final String description;
  final String template;
  final List<String> variables;
  final String category;
  final bool isCustom;
  final DateTime createdAt;

  const PromptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    this.variables = const [],
    required this.category,
    this.isCustom = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Apply variables to template
  String apply(Map<String, String> values) {
    String result = template;
    for (final variable in variables) {
      result = result.replaceAll(
        '{{$variable}}',
        values[variable] ?? '',
      );
    }
    return result;
  }

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      template: json['template'],
      variables: List<String>.from(json['variables'] ?? []),
      category: json['category'],
      isCustom: json['isCustom'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'template': template,
    'variables': variables,
    'category': category,
    'isCustom': isCustom,
    'createdAt': createdAt.toIso8601String(),
  };
}

enum PromptCategory {
  writing,
  coding,
  analysis,
  creative,
  business,
  learning,
  productivity,
  custom,
}
```

#### Step 2: Create Built-in Templates

```dart
// lib/data/built_in_templates.dart

class BuiltInTemplates {
  static List<PromptTemplate> get all => [
    // Writing
    PromptTemplate(
      id: 'summarize',
      name: 'Summarize Text',
      description: 'Create a concise summary of any text',
      template: '''Summarize the following text in {{length}} words or less. 
Focus on the main points and key takeaways.

Text to summarize:
{{text}}''',
      variables: ['length', 'text'],
      category: 'writing',
    ),
    PromptTemplate(
      id: 'rewrite',
      name: 'Rewrite Text',
      description: 'Rewrite text in a different style',
      template: '''Rewrite the following text in a {{style}} tone:

{{text}}''',
      variables: ['style', 'text'],
      category: 'writing',
    ),
    PromptTemplate(
      id: 'grammar-check',
      name: 'Grammar Check',
      description: 'Check and fix grammar issues',
      template: '''Check the following text for grammar, spelling, and punctuation errors.
Provide the corrected version and explain the changes:

{{text}}''',
      variables: ['text'],
      category: 'writing',
    ),

    // Coding
    PromptTemplate(
      id: 'code-review',
      name: 'Code Review',
      description: 'Review code for issues and improvements',
      template: '''Review this {{language}} code for:
1. Bugs or errors
2. Security vulnerabilities
3. Performance issues
4. Best practices violations
5. Code style improvements

```{{language}}
{{code}}
```

Provide specific suggestions for improvement.''',
      variables: ['language', 'code'],
      category: 'coding',
    ),
    PromptTemplate(
      id: 'explain-code',
      name: 'Explain Code',
      description: 'Explain what code does in plain English',
      template: '''Explain what this code does in simple terms:

```{{language}}
{{code}}
```

Include:
- Overall purpose
- Step-by-step breakdown
- Key concepts used''',
      variables: ['language', 'code'],
      category: 'coding',
    ),
    PromptTemplate(
      id: 'debug',
      name: 'Debug Help',
      description: 'Debug code with error messages',
      template: '''I'm getting this error in my {{language}} code:

Error: {{error}}

Code:
```{{language}}
{{code}}
```

Help me understand what's wrong and how to fix it.''',
      variables: ['language', 'error', 'code'],
      category: 'coding',
    ),

    // Analysis
    PromptTemplate(
      id: 'pros-cons',
      name: 'Pros and Cons',
      description: 'Analyze pros and cons of a topic',
      template: '''Create a pros and cons analysis for:

{{topic}}

Provide:
- At least 5 pros
- At least 5 cons
- A balanced conclusion
- Key considerations''',
      variables: ['topic'],
      category: 'analysis',
    ),
    PromptTemplate(
      id: 'compare',
      name: 'Compare Options',
      description: 'Compare multiple options',
      template: '''Compare the following options:

{{options}}

Create a comparison covering:
1. Key features
2. Advantages and disadvantages
3. Best use cases for each
4. Recommendation''',
      variables: ['options'],
      category: 'analysis',
    ),

    // Creative
    PromptTemplate(
      id: 'story-starter',
      name: 'Story Starter',
      description: 'Generate a creative story beginning',
      template: '''Write the opening paragraph of a {{genre}} story about:

{{premise}}

Make it engaging and hook the reader immediately.''',
      variables: ['genre', 'premise'],
      category: 'creative',
    ),
    PromptTemplate(
      id: 'brainstorm',
      name: 'Brainstorm Ideas',
      description: 'Generate creative ideas',
      template: '''Brainstorm {{count}} creative ideas for:

{{topic}}

Be innovative, diverse, and provide brief descriptions for each idea.''',
      variables: ['count', 'topic'],
      category: 'creative',
    ),

    // Business
    PromptTemplate(
      id: 'email',
      name: 'Write Email',
      description: 'Compose a professional email',
      template: '''Write a {{tone}} email about:

Subject: {{subject}}

Context: {{context}}

Include appropriate greeting and closing.''',
      variables: ['tone', 'subject', 'context'],
      category: 'business',
    ),
    PromptTemplate(
      id: 'meeting-notes',
      name: 'Meeting Notes',
      description: 'Format meeting notes',
      template: '''Convert these rough meeting notes into a structured format:

{{notes}}

Include:
- Meeting title
- Attendees (if mentioned)
- Key discussion points
- Decisions made
- Action items
- Next steps''',
      variables: ['notes'],
      category: 'business',
    ),

    // Learning
    PromptTemplate(
      id: 'explain-like-5',
      name: 'ELI5',
      description: 'Explain like I\'m 5 years old',
      template: '''Explain this concept in simple terms a 5-year-old could understand:

{{concept}}

Use analogies and examples from everyday life.''',
      variables: ['concept'],
      category: 'learning',
    ),
    PromptTemplate(
      id: 'study-guide',
      name: 'Study Guide',
      description: 'Create a study guide',
      template: '''Create a study guide for:

{{topic}}

Include:
1. Key concepts and definitions
2. Important facts
3. Practice questions
4. Memory techniques
5. Additional resources''',
      variables: ['topic'],
      category: 'learning',
    ),

    // Productivity
    PromptTemplate(
      id: 'task-breakdown',
      name: 'Task Breakdown',
      description: 'Break down a complex task',
      template: '''Break down this task into smaller, manageable steps:

{{task}}

For each step include:
- Description
- Estimated time
- Dependencies
- Tools/resources needed''',
      variables: ['task'],
      category: 'productivity',
    ),
    PromptTemplate(
      id: 'weekly-plan',
      name: 'Weekly Planner',
      description: 'Plan your week',
      template: '''Help me plan my week with these goals and commitments:

Goals: {{goals}}
Commitments: {{commitments}}

Create a balanced weekly schedule that:
1. Prioritizes important tasks
2. Includes breaks
3. Allows flexibility
4. Considers energy levels''',
      variables: ['goals', 'commitments'],
      category: 'productivity',
    ),
  ];

  static List<PromptTemplate> byCategory(String category) {
    return all.where((t) => t.category == category).toList();
  }

  static List<String> get categories => [
    'writing',
    'coding',
    'analysis',
    'creative',
    'business',
    'learning',
    'productivity',
  ];
}
```

#### Step 3: Create Templates Screen

```dart
// lib/screens/templates_screen.dart

import 'package:flutter/material.dart';
import '../models/prompt_template.dart';
import '../data/built_in_templates.dart';
import '../services/template_service.dart';

class TemplatesScreen extends StatefulWidget {
  final Function(String)? onSelect;

  const TemplatesScreen({Key? key, this.onSelect}) : super(key: key);

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PromptTemplate> _customTemplates = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: BuiltInTemplates.categories.length + 1, // +1 for custom
      vsync: this,
    );
    _loadCustomTemplates();
  }

  Future<void> _loadCustomTemplates() async {
    final templates = await TemplateService().getCustomTemplates();
    setState(() => _customTemplates = templates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prompt Templates'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'All'),
            ...BuiltInTemplates.categories.map((c) => Tab(text: _capitalize(c))),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _createCustomTemplate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search templates...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Templates list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplatesList(BuiltInTemplates.all),
                ...BuiltInTemplates.categories.map(
                  (c) => _buildTemplatesList(BuiltInTemplates.byCategory(c)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesList(List<PromptTemplate> templates) {
    // Filter by search query
    final filtered = _searchQuery.isEmpty
        ? templates
        : templates.where((t) =>
            t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.description.toLowerCase().contains(_searchQuery.toLowerCase()),
          ).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No templates found'),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final template = filtered[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(PromptTemplate template) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _useTemplate(template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getCategoryIcon(template.category),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (template.isCustom)
                    Chip(
                      label: Text('Custom', style: TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                template.description,
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (template.variables.isNotEmpty) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: template.variables
                      .map((v) => Chip(
                            label: Text('{{$v}}', style: TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getCategoryIcon(String category) {
    switch (category) {
      case 'writing':
        return Icon(Icons.edit, color: Colors.blue);
      case 'coding':
        return Icon(Icons.code, color: Colors.green);
      case 'analysis':
        return Icon(Icons.analytics, color: Colors.orange);
      case 'creative':
        return Icon(Icons.palette, color: Colors.purple);
      case 'business':
        return Icon(Icons.business, color: Colors.teal);
      case 'learning':
        return Icon(Icons.school, color: Colors.indigo);
      case 'productivity':
        return Icon(Icons.task_alt, color: Colors.amber);
      default:
        return Icon(Icons.article, color: Colors.grey);
    }
  }

  void _useTemplate(PromptTemplate template) {
    if (template.variables.isEmpty) {
      // No variables, use directly
      widget.onSelect?.call(template.template);
      Navigator.pop(context);
      return;
    }

    // Show variable input dialog
    _showVariableDialog(template);
  }

  Future<void> _showVariableDialog(PromptTemplate template) async {
    final controllers = <String, TextEditingController>{};
    for (final v in template.variables) {
      controllers[v] = TextEditingController();
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: template.variables.map((v) {
              return Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: controllers[v],
                  decoration: InputDecoration(
                    labelText: _capitalize(v),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: v == 'code' || v == 'text' ? 4 : 1,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use Template'),
          ),
        ],
      ),
    );

    if (result == true) {
      final values = <String, String>{};
      for (final entry in controllers.entries) {
        values[entry.key] = entry.value.text;
      }
      final prompt = template.apply(values);
      widget.onSelect?.call(prompt);
      Navigator.pop(context);
    }

    // Cleanup
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Future<void> _createCustomTemplate() async {
    final result = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => _CreateTemplateDialog(),
    );

    if (result != null) {
      await TemplateService().saveCustomTemplate(result);
      _loadCustomTemplates();
    }
  }

  String _capitalize(String s) {
    return s[0].toUpperCase() + s.substring(1);
  }
}
```

#### Step 4: Create Template Service

```dart
// lib/services/template_service.dart

class TemplateService {
  static final TemplateService _instance = TemplateService._internal();
  factory TemplateService() => _instance;
  TemplateService._internal();

  static const String _storageKey = 'custom_templates';

  Future<List<PromptTemplate>> getCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json == null) return [];

    final list = jsonDecode(json) as List;
    return list.map((e) => PromptTemplate.fromJson(e)).toList();
  }

  Future<void> saveCustomTemplate(PromptTemplate template) async {
    final templates = await getCustomTemplates();
    templates.add(template);
    await _saveAll(templates);
  }

  Future<void> deleteCustomTemplate(String id) async {
    final templates = await getCustomTemplates();
    templates.removeWhere((t) => t.id == id);
    await _saveAll(templates);
  }

  Future<void> _saveAll(List<PromptTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(templates.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }
}
```

#### Step 5: Integration in Chat Screen

```dart
// In chat_screen.dart, add template button to input area

Row(
  children: [
    // Template button
    IconButton(
      icon: Icon(Icons.auto_awesome),
      tooltip: 'Prompt Templates',
      onPressed: () async {
        final template = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => TemplatesScreen(
              onSelect: (prompt) => Navigator.pop(context, prompt),
            ),
          ),
        );
        if (template != null) {
          _controller.text = template;
        }
      },
    ),
    // Existing input field...
  ],
),
```

---

### Feature 3: Global Search

**Estimated Time:** 4-6 hours  
**Priority:** HIGH  
**Difficulty:** MEDIUM

#### Implementation coming in next message...

---

## 📁 Project Structure After Implementation

```
lib/
├── models/
│   ├── prompt_template.dart       # NEW
│   ├── export_config.dart         # NEW
│   └── search_result.dart         # NEW
├── services/
│   ├── export_service.dart        # NEW
│   ├── template_service.dart      # NEW
│   └── search_service.dart        # NEW
├── screens/
│   ├── templates_screen.dart      # NEW
│   ├── search_screen.dart         # NEW
│   └── chat_screen.dart           # MODIFIED (add export, templates)
├── data/
│   └── built_in_templates.dart    # NEW
└── widgets/
    ├── export_button.dart         # NEW
    └── template_picker.dart       # NEW
```

---

## 🧪 Testing Plan

### Unit Tests
- [ ] Export service generates correct formats
- [ ] Template variables are replaced correctly
- [ ] Search returns correct results

### Integration Tests
- [ ] Export → Share flow works
- [ ] Template → Chat flow works
- [ ] Search → Navigate to message works

### Manual Tests
- [ ] All export formats work on device
- [ ] Templates UI is responsive
- [ ] Search is fast with many conversations

---

## 📊 Success Metrics

| Feature | Metric | Target |
|---------|--------|--------|
| Chat Export | % users who export | > 10% |
| Templates | Templates used per week | > 5 |
| Search | Searches per session | > 2 |

---

## 🚢 Release Checklist

- [ ] All features implemented
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Manual testing complete
- [ ] Documentation updated
- [ ] README updated
- [ ] Changelog updated
- [ ] Version bumped to 2.1.0
- [ ] APK tested on device
- [ ] Release created on GitHub

---

**Document Version:** 1.0  
**Last Updated:** March 10, 2026