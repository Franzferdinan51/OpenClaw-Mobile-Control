import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Code block widget with syntax highlighting and copy functionality
class CodeBlock extends StatefulWidget {
  final String code;
  final String? language;
  final bool showLineNumbers;
  final bool showCopyButton;
  final bool showLanguage;
  final int? maxLines;
  final double fontSize;
  final bool collapsible;
  final bool initiallyExpanded;

  const CodeBlock({
    super.key,
    required this.code,
    this.language,
    this.showLineNumbers = true,
    this.showCopyButton = true,
    this.showLanguage = true,
    this.maxLines,
    this.fontSize = 13,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _expanded = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.code.split('\n');
    final lineCount = lines.length;
    final displayLanguage = widget.language ?? _detectLanguage(widget.code);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                // Language badge
                if (widget.showLanguage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLanguageColor(displayLanguage).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      displayLanguage.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getLanguageColor(displayLanguage),
                      ),
                    ),
                  ),
                
                const Spacer(),
                
                // Line count
                Text(
                  '$lineCount lines',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                
                // Collapse button
                if (widget.collapsible) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: AnimatedRotation(
                      turns: _expanded ? 0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_less, size: 18),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: _expanded ? 'Collapse' : 'Expand',
                  ),
                ],
                
                // Copy button
                if (widget.showCopyButton) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _copyCode,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _copied ? Icons.check : Icons.copy,
                        size: 18,
                        key: ValueKey(_copied),
                        color: _copied ? Colors.green : Colors.grey,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: _copied ? 'Copied!' : 'Copy code',
                  ),
                ],
              ],
            ),
          ),
          
          // Code content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildCodeContent(lines),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeContent(List<String> lines) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 32,
          maxHeight: widget.maxLines != null
              ? widget.maxLines! * (widget.fontSize + 4)
              : double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line numbers
              if (widget.showLineNumbers)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(lines.length, (index) {
                      return Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: widget.fontSize,
                          fontFamily: 'monospace',
                          color: Colors.grey[600],
                        ),
                      );
                    }),
                  ),
                ),
              
              // Code
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(lines.length, (index) {
                    return _buildCodeLine(lines[index], index);
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeLine(String line, int index) {
    final tokens = _tokenizeLine(line);
    
    return RichText(
      text: TextSpan(
        children: tokens.map((token) {
          return TextSpan(
            text: token.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontFamily: 'monospace',
              color: token.color,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _detectLanguage(String code) {
    final patterns = {
      'dart': [RegExp(r'\b(class|void|var|final|const|import|package)\b')],
      'python': [RegExp(r'\b(def|class|import|from|if __name__|print\(|self\.)')],
      'javascript': [RegExp(r'\b(function|const|let|var|=>|console\.log|async)\b')],
      'typescript': [RegExp(r'\b(interface|type|enum|implements|: string|: number)\b')],
      'json': [RegExp(r'^\s*[\{\[]|"[\w]+"\s*:')],
      'yaml': [RegExp(r'^[\w-]+:|\s+-\s+')],
      'bash': [RegExp(r'#!/bin/bash|^\s*\$\s+|^\s*apt|^\s*brew')],
      'sql': [RegExp(r'\b(SELECT|FROM|WHERE|INSERT|UPDATE|DELETE)\b', caseSensitive: false)],
      'html': [RegExp(r'</?[a-z][\s\S]*>')],
      'css': [RegExp(r'\{[\s\S]*:[\s\S]*;[\s\S]*\}|@media')],
    };

    for (final entry in patterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(code)) {
          return entry.key;
        }
      }
    }

    return 'code';
  }

  Color _getLanguageColor(String language) {
    const colors = {
      'dart': Color(0xFF0175C2),
      'python': Color(0xFF3572A5),
      'javascript': Color(0xFFF7DF1E),
      'typescript': Color(0xFF3178C6),
      'json': Color(0xFF292929),
      'yaml': Color(0xFFCB171E),
      'bash': Color(0xFF4EAA25),
      'sql': Color(0xFFE38C00),
      'html': Color(0xFFE34F26),
      'css': Color(0xFF1572B6),
    };

    return colors[language.toLowerCase()] ?? Colors.grey;
  }

  List<_Token> _tokenizeLine(String line) {
    final tokens = <_Token>[];
    
    // Simple tokenization - can be enhanced with proper lexer
    final patterns = [
      // Strings (double, single quotes - template literals handled separately)
      (RegExp(r'"[^"]*"|' + r"'[^']*'"), Colors.orange),
      // Template literals (backtick strings)
      (RegExp(r'`[^`]*`'), Colors.orange),
      // Comments
      (RegExp(r'//.*$|#.*$|/\*[\s\S]*?\*/'), Colors.grey),
      // Keywords
      (RegExp(r'\b(if|else|for|while|return|function|class|const|let|var|import|export|from|async|await|try|catch|throw|new|this|super|extends|implements|interface|type|enum|def|self|True|False|None)\b'), const Color(0xFFC792EA)),
      // Numbers
      (RegExp(r'\b\d+\.?\d*\b'), Colors.purple),
      // Booleans and null
      (RegExp(r'\b(true|false|null|undefined)\b'), Colors.purple),
      // Functions
      (RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()'), const Color(0xFF82AAFF)),
      // Operators
      (RegExp(r'[+\-*/%=<>!&|^~?:]'), const Color(0xFF89DDFF)),
    ];

    var remaining = line;
    
    while (remaining.isNotEmpty) {
      var matched = false;
      
      for (final (pattern, color) in patterns) {
        final match = pattern.firstMatch(remaining);
        if (match != null && match.start == 0) {
          tokens.add(_Token(match.group(0)!, color));
          remaining = remaining.substring(match.end);
          matched = true;
          break;
        }
      }
      
      if (!matched) {
        // No match, take one character as plain text
        tokens.add(_Token(remaining[0], Colors.white));
        remaining = remaining.substring(1);
      }
    }
    
    return tokens;
  }
}

class _Token {
  final String text;
  final Color color;

  _Token(this.text, this.color);
}

/// Inline code widget for short code snippets
class InlineCode extends StatelessWidget {
  final String code;
  final double fontSize;

  const InlineCode({
    super.key,
    required this.code,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'monospace',
          color: const Color(0xFF00D4AA),
        ),
      ),
    );
  }
}