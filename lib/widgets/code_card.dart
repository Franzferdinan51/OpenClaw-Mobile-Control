import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'info_card.dart';

/// Code card for displaying code with syntax highlighting
/// 
/// Features:
/// - Syntax highlighting
/// - Line numbers
/// - Copy to clipboard
/// - Language detection
/// - Collapsible code blocks
/// - File path display
class CodeCard extends InfoCard {
  final String code;
  final String? language;
  final String? filePath;
  final bool showLineNumbers;
  final bool showCopyButton;
  final bool showLanguage;
  final int? maxLines;
  final double fontSize;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool showStats;

  const CodeCard({
    super.key,
    super.title,
    super.subtitle,
    super.leading,
    super.trailing,
    super.accentColor,
    super.onTap,
    super.onLongPress,
    super.actions,
    super.isLoading,
    super.errorMessage,
    super.padding,
    super.margin,
    super.enableSwipe,
    super.swipeLeftAction,
    super.swipeRightAction,
    required this.code,
    this.language,
    this.filePath,
    this.showLineNumbers = true,
    this.showCopyButton = true,
    this.showLanguage = true,
    this.maxLines,
    this.fontSize = 13,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.showStats = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    return _CodeCardContent(
      code: code,
      language: language,
      filePath: filePath,
      showLineNumbers: showLineNumbers,
      showCopyButton: showCopyButton,
      showLanguage: showLanguage,
      maxLines: maxLines,
      fontSize: fontSize,
      collapsible: collapsible,
      initiallyExpanded: initiallyExpanded,
      showStats: showStats,
    );
  }
}

class _CodeCardContent extends StatefulWidget {
  final String code;
  final String? language;
  final String? filePath;
  final bool showLineNumbers;
  final bool showCopyButton;
  final bool showLanguage;
  final int? maxLines;
  final double fontSize;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool showStats;

  const _CodeCardContent({
    required this.code,
    this.language,
    this.filePath,
    required this.showLineNumbers,
    required this.showCopyButton,
    required this.showLanguage,
    this.maxLines,
    required this.fontSize,
    required this.collapsible,
    required this.initiallyExpanded,
    required this.showStats,
  });

  @override
  State<_CodeCardContent> createState() => _CodeCardContentState();
}

class _CodeCardContentState extends State<_CodeCardContent> {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File path (if provided)
        if (widget.filePath != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.filePath!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Code container
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(displayLanguage, lineCount),
              
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
        ),
      ],
    );
  }

  Widget _buildHeader(String displayLanguage, int lineCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          // Language badge
          if (widget.showLanguage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getLanguageColor(displayLanguage).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getLanguageColor(displayLanguage).withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getLanguageColor(displayLanguage),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayLanguage.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getLanguageColor(displayLanguage),
                    ),
                  ),
                ],
              ),
            ),
          
          const Spacer(),
          
          // Stats
          if (widget.showStats) ...[
            Icon(Icons.code, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              '$lineCount lines',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.text_fields, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              '${widget.code.length} chars',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
          
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
              color: Colors.grey[500],
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
                  color: _copied ? Colors.green : Colors.grey[500],
                ),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: _copied ? 'Copied!' : 'Copy code',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeContent(List<String> lines) {
    final effectiveMaxHeight = widget.maxLines != null
        ? widget.maxLines! * (widget.fontSize + 6)
        : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: effectiveMaxHeight ?? 400,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(lines.length, (index) {
                  return _buildCodeLine(lines[index]);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeLine(String line) {
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
      'markdown': [RegExp(r'^#+\s|^```|^\*\s|^\-\s|^\d+\.\s')],
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
      'markdown': Color(0xFF083FA1),
    };

    return colors[language.toLowerCase()] ?? Colors.grey;
  }

  List<_Token> _tokenizeLine(String line) {
    final tokens = <_Token>[];
    
    final patterns = <_PatternRule>[
      // Strings
      _PatternRule(RegExp(r"""["][^"]*["]|'[^']*'|`[^`]*`"""), const Color(0xFFCE9178)),
      // Comments
      _PatternRule(RegExp(r'//.*$|#.*$|/\*[\s\S]*?\*/'), const Color(0xFF6A9955)),
      // Keywords
      _PatternRule(RegExp(r'\b(if|else|for|while|return|function|class|const|let|var|import|export|from|async|await|try|catch|throw|new|this|super|extends|implements|interface|type|enum|def|self|True|False|None|final|void|static|public|private|protected)\b'), const Color(0xFFC586C0)),
      // Numbers
      _PatternRule(RegExp(r'\b\d+\.?\d*\b'), const Color(0xFFB5CEA8)),
      // Booleans and null
      _PatternRule(RegExp(r'\b(true|false|null|undefined)\b'), const Color(0xFF569CD6)),
      // Functions
      _PatternRule(RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()'), const Color(0xFFDCDCAA)),
      // Operators
      _PatternRule(RegExp(r'[+\-*/%=<>!&|^~?:]'), const Color(0xFFD4D4D4)),
    ];

    var remaining = line;
    
    while (remaining.isNotEmpty) {
      var matched = false;
      
      for (final rule in patterns) {
        final match = rule.pattern.firstMatch(remaining);
        if (match != null && match.start == 0) {
          tokens.add(_Token(match.group(0)!, rule.color));
          remaining = remaining.substring(match.end);
          matched = true;
          break;
        }
      }
      
      if (!matched) {
        tokens.add(_Token(remaining[0], const Color(0xFFD4D4D4)));
        remaining = remaining.substring(1);
      }
    }
    
    return tokens;
  }
}

class _PatternRule {
  final RegExp pattern;
  final Color color;

  _PatternRule(this.pattern, this.color);
}

class _Token {
  final String text;
  final Color color;

  _Token(this.text, this.color);
}

/// Inline code widget for short code snippets in text
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
        border: Border.all(color: Colors.grey[700]!),
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

/// Code snippet card - specialized for small code snippets
class CodeSnippetCard extends StatelessWidget {
  final String code;
  final String? language;
  final String? description;
  final VoidCallback? onRun;
  final VoidCallback? onCopy;

  const CodeSnippetCard({
    super.key,
    required this.code,
    this.language,
    this.description,
    this.onRun,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return CodeCard(
      code: code,
      language: language,
      title: description,
      showStats: false,
      maxLines: 10,
      actions: [
        if (onRun != null)
          InfoCardAction(
            icon: Icons.play_arrow,
            label: 'Run',
            color: Colors.green,
            onAction: onRun!,
          ),
        if (onCopy != null)
          InfoCardAction(
            icon: Icons.copy,
            label: 'Copy',
            color: Colors.blue,
            onAction: onCopy!,
          ),
      ],
    );
  }
}

/// Terminal output card - specialized for terminal/command output
class TerminalOutputCard extends StatelessWidget {
  final String output;
  final String? command;
  final int? exitCode;
  final Duration? executionTime;
  final VoidCallback? onCopy;

  const TerminalOutputCard({
    super.key,
    required this.output,
    this.command,
    this.exitCode,
    this.executionTime,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = exitCode == null || exitCode == 0;
    
    return CodeCard(
      code: output,
      language: 'bash',
      title: command ?? 'Terminal Output',
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      trailing: executionTime != null
          ? Text(
              '${executionTime!.inMilliseconds}ms',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            )
          : null,
      accentColor: isSuccess ? Colors.green : Colors.red,
      showLineNumbers: false,
    );
  }
}