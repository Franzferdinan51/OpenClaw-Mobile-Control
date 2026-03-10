import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'code_block.dart';

/// Markdown renderer widget with full markdown support
class MarkdownRenderer extends StatelessWidget {
  final String markdown;
  final void Function(String)? onLinkTap;
  final double baseFontSize;
  final bool selectable;

  const MarkdownRenderer({
    super.key,
    required this.markdown,
    this.onLinkTap,
    this.baseFontSize = 14,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final nodes = _parseMarkdown(markdown);
    
    return _buildNodes(nodes, context);
  }

  Widget _buildNodes(List<_MdNode> nodes, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes.map((node) => _buildNode(node, context)).toList(),
    );
  }

  Widget _buildNode(_MdNode node, BuildContext context) {
    switch (node.type) {
      case _NodeType.heading:
        return _buildHeading(node);
      case _NodeType.paragraph:
        return _buildParagraph(node);
      case _NodeType.codeBlock:
        return _buildCodeBlock(node);
      case _NodeType.inlineCode:
        return _buildInlineCode(node);
      case _NodeType.list:
        return _buildList(node);
      case _NodeType.blockquote:
        return _buildBlockquote(node);
      case _NodeType.table:
        return _buildTable(node);
      case _NodeType.horizontalRule:
        return _buildHorizontalRule();
      case _NodeType.image:
        return _buildImage(node);
      case _NodeType.checkbox:
        return _buildCheckbox(node);
      case _NodeType.text:
      default:
        return _buildText(node);
    }
  }

  Widget _buildHeading(_MdNode node) {
    final level = node.level ?? 1;
    final sizes = [32.0, 28.0, 24.0, 20.0, 18.0, 16.0];
    final size = sizes[(level - 1).clamp(0, 5)];
    
    return Padding(
      padding: EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        node.text ?? '',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(_MdNode node) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildRichText(node.children ?? [], baseFontSize),
    );
  }

  Widget _buildText(_MdNode node) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(node.text ?? ''),
    );
  }

  Widget _buildRichText(List<_MdNode> children, double fontSize) {
    final spans = children.map((child) => _nodeToSpan(child)).toList();
    
    return SelectableText.rich(
      TextSpan(
        children: spans.isEmpty ? [TextSpan(text: '')] : spans,
        style: TextStyle(fontSize: fontSize, color: Colors.white),
      ),
    );
  }

  TextSpan _nodeToSpan(_MdNode node) {
    final style = _getTextStyle(node);
    
    if (node.type == _NodeType.link && node.url != null) {
      return TextSpan(
        text: node.text ?? node.url,
        style: style?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (onLinkTap != null) {
              onLinkTap!(node.url!);
            } else {
              launchUrl(Uri.parse(node.url!));
            }
          },
      );
    }
    
    if (node.children != null && node.children!.isNotEmpty) {
      return TextSpan(
        children: node.children!.map((c) => _nodeToSpan(c)).toList(),
        style: style,
      );
    }
    
    return TextSpan(text: node.text ?? '', style: style);
  }

  TextStyle? _getTextStyle(_MdNode node) {
    switch (node.type) {
      case _NodeType.bold:
        return const TextStyle(fontWeight: FontWeight.bold);
      case _NodeType.italic:
        return const TextStyle(fontStyle: FontStyle.italic);
      case _NodeType.strikethrough:
        return const TextStyle(decoration: TextDecoration.lineThrough);
      case _NodeType.code:
        return TextStyle(
          fontFamily: 'monospace',
          color: const Color(0xFF00D4AA),
          backgroundColor: Colors.grey[800],
        );
      case _NodeType.link:
        return TextStyle(color: Colors.blue);
      default:
        return null;
    }
  }

  Widget _buildCodeBlock(_MdNode node) {
    return CodeBlock(
      code: node.text ?? '',
      language: node.language,
      showLineNumbers: true,
      fontSize: 12,
    );
  }

  Widget _buildInlineCode(_MdNode node) {
    return InlineCode(code: node.text ?? '');
  }

  Widget _buildList(_MdNode node) {
    final items = node.children ?? [];
    final isOrdered = node.ordered ?? false;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bullet or number
                SizedBox(
                  width: 24,
                  child: Text(
                    isOrdered ? '${index + 1}.' : '•',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                // Content
                Expanded(
                  child: item.children != null
                      ? _buildRichText(item.children!, 14)
                      : Text(item.text ?? ''),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlockquote(_MdNode node) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          left: BorderSide(
            color: Colors.grey[600]!,
            width: 4,
          ),
        ),
      ),
      child: node.children != null
          ? _buildRichText(node.children!, 14)
          : Text(
              node.text ?? '',
              style: TextStyle(
                color: Colors.grey[300],
                fontStyle: FontStyle.italic,
              ),
            ),
    );
  }

  Widget _buildTable(_MdNode node) {
    final headers = node.tableHeaders ?? [];
    final rows = node.tableRows ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: Colors.grey[700]!),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[800]),
              children: headers.map((header) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  header,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )).toList(),
            ),
            // Data rows
            ...rows.map((row) => TableRow(
              children: row.map((cell) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(cell),
              )).toList(),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalRule() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 1,
      color: Colors.grey[700],
    );
  }

  Widget _buildImage(_MdNode node) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: node.url != null
                ? Image.network(
                    node.url!,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: Colors.grey[800],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  )
                : Container(
                    height: 100,
                    color: Colors.grey[800],
                    child: const Center(child: Icon(Icons.image)),
                  ),
          ),
          if (node.text != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                node.text!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(_MdNode node) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Checkbox(
            value: node.checked ?? false,
            onChanged: (_) {}, // Read-only for now
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: Text(
              node.text ?? '',
              style: TextStyle(
                decoration: (node.checked ?? false)
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Markdown parser
  List<_MdNode> _parseMarkdown(String markdown) {
    final lines = markdown.split('\n');
    final nodes = <_MdNode>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // Empty line
      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      // Heading
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        nodes.add(_MdNode(
          type: _NodeType.heading,
          level: headingMatch.group(1)!.length,
          children: _parseInline(headingMatch.group(2)!),
        ));
        i++;
        continue;
      }

      // Code block
      if (line.startsWith('```')) {
        final lang = line.substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        nodes.add(_MdNode(
          type: _NodeType.codeBlock,
          text: codeLines.join('\n'),
          language: lang.isNotEmpty ? lang : null,
        ));
        i++;
        continue;
      }

      // Horizontal rule
      if (RegExp(r'^[-*_]{3,}$').hasMatch(line.trim())) {
        nodes.add(_MdNode(type: _NodeType.horizontalRule));
        i++;
        continue;
      }

      // Blockquote
      if (line.startsWith('>')) {
        final quoteLines = <String>[line.substring(1).trim()];
        i++;
        while (i < lines.length && lines[i].startsWith('>')) {
          quoteLines.add(lines[i].substring(1).trim());
          i++;
        }
        nodes.add(_MdNode(
          type: _NodeType.blockquote,
          children: _parseInline(quoteLines.join(' ')),
        ));
        continue;
      }

      // Table
      if (line.contains('|') && i + 1 < lines.length && lines[i + 1].contains('|')) {
        final headerLine = line;
        final separatorLine = lines[i + 1];
        
        if (RegExp(r'^[\s|:-]+$').hasMatch(separatorLine)) {
          final headers = headerLine.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final rows = <List<String>>[];
          
          i += 2;
          while (i < lines.length && lines[i].contains('|')) {
            rows.add(lines[i].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList());
            i++;
          }
          
          nodes.add(_MdNode(
            type: _NodeType.table,
            tableHeaders: headers,
            tableRows: rows,
          ));
          continue;
        }
      }

      // List (unordered)
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final items = <_MdNode>[];
        while (i < lines.length && (lines[i].startsWith('- ') || lines[i].startsWith('* '))) {
          items.add(_MdNode(
            children: _parseInline(lines[i].substring(2)),
          ));
          i++;
        }
        nodes.add(_MdNode(
          type: _NodeType.list,
          children: items,
          ordered: false,
        ));
        continue;
      }

      // List (ordered)
      final orderedMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(line);
      if (orderedMatch != null) {
        final items = <_MdNode>[];
        while (i < lines.length) {
          final match = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(lines[i]);
          if (match == null) break;
          items.add(_MdNode(
            children: _parseInline(match.group(2)!),
          ));
          i++;
        }
        nodes.add(_MdNode(
          type: _NodeType.list,
          children: items,
          ordered: true,
        ));
        continue;
      }

      // Checkbox
      final checkboxMatch = RegExp(r'^- \[([ xX])\]\s+(.+)$').firstMatch(line);
      if (checkboxMatch != null) {
        nodes.add(_MdNode(
          type: _NodeType.checkbox,
          checked: checkboxMatch.group(1)!.toLowerCase() == 'x',
          text: checkboxMatch.group(2),
        ));
        i++;
        continue;
      }

      // Image
      final imageMatch = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(line);
      if (imageMatch != null && imageMatch.start == 0) {
        nodes.add(_MdNode(
          type: _NodeType.image,
          text: imageMatch.group(1),
          url: imageMatch.group(2),
        ));
        i++;
        continue;
      }

      // Paragraph (default)
      final paraLines = <String>[line];
      i++;
      while (i < lines.length &&
             lines[i].trim().isNotEmpty &&
             !lines[i].startsWith('#') &&
             !lines[i].startsWith('```') &&
             !lines[i].startsWith('- ') &&
             !lines[i].startsWith('* ') &&
             !lines[i].startsWith('> ') &&
             !RegExp(r'^\d+\.\s').hasMatch(lines[i])) {
        paraLines.add(lines[i]);
        i++;
      }
      nodes.add(_MdNode(
        type: _NodeType.paragraph,
        children: _parseInline(paraLines.join(' ')),
      ));
    }

    return nodes;
  }

  List<_MdNode> _parseInline(String text) {
    final nodes = <_MdNode>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      // Bold + Italic
      var match = RegExp(r'\*\*\*(.+?)\*\*\*').firstMatch(remaining);
      if (match != null) {
        if (match.start > 0) {
          nodes.add(_MdNode(text: remaining.substring(0, match.start)));
        }
        nodes.add(_MdNode(
          type: _NodeType.bold,
          children: [_MdNode(type: _NodeType.italic, text: match.group(1))],
        ));
        remaining = remaining.substring(match.end);
        continue;
      }

      // Bold
      match = RegExp(r'\*\*(.+?)\*\*|__(.+?)__').firstMatch(remaining);
      if (match != null) {
        if (match.start > 0) {
          nodes.add(_MdNode(text: remaining.substring(0, match.start)));
        }
        nodes.add(_MdNode(
          type: _NodeType.bold,
          text: match.group(1) ?? match.group(2),
        ));
        remaining = remaining.substring(match.end);
        continue;
      }

      // Italic
      match = RegExp(r'\*(.+?)\*|_(.+?)_').firstMatch(remaining);
      if (match != null) {
        if (match.start > 0) {
          nodes.add(_MdNode(text: remaining.substring(0, match.start)));
        }
        nodes.add(_MdNode(
          type: _NodeType.italic,
          text: match.group(1) ?? match.group(2),
        ));
        remaining = remaining.substring(match.end);
        continue;
      }

      // Strikethrough
      match = RegExp(r'~~(.+?)~~').firstMatch(remaining);
      if (match != null) {
        if (match.start > 0) {
          nodes.add(_MdNode(text: remaining.substring(0, match.start)));
        }
        nodes.add(_MdNode(
          type: _NodeType.strikethrough,
          text: match.group(1),
        ));
        remaining = remaining.substring(match.end);
        continue;
      }

      // Inline code
      match = RegExp(r'`([^`]+)`').firstMatch(remaining);
      if (match != null) {
        if (match.start > 0) {
          nodes.add(_MdNode(text: remaining.substring(0, match.start)));
        }
        nodes.add(_MdNode(
          type: _NodeType.code,
          text: match.group(1),
        ));
        remaining = remaining.substring(match.end);
        continue;
      }

      // Link
      match = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').firstMatch(remaining);
      if (match != null) {
        if (match.start > 0) {
          nodes.add(_MdNode(text: remaining.substring(0, match.start)));
        }
        nodes.add(_MdNode(
          type: _NodeType.link,
          text: match.group(1),
          url: match.group(2),
        ));
        remaining = remaining.substring(match.end);
        continue;
      }

      // Image (inline)
      match = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(remaining);
      if (match != null) {
        if (match.start > 0) {
          nodes.add(_MdNode(text: remaining.substring(0, match.start)));
        }
        nodes.add(_MdNode(
          type: _NodeType.image,
          text: match.group(1),
          url: match.group(2),
        ));
        remaining = remaining.substring(match.end);
        continue;
      }

      // No match, add as text
      nodes.add(_MdNode(text: remaining));
      break;
    }

    return nodes;
  }
}

enum _NodeType {
  text,
  paragraph,
  heading,
  bold,
  italic,
  strikethrough,
  code,
  codeBlock,
  inlineCode,
  link,
  image,
  list,
  blockquote,
  table,
  horizontalRule,
  checkbox,
}

class _MdNode {
  final _NodeType type;
  final String? text;
  final String? url;
  final int? level;
  final String? language;
  final bool? ordered;
  final bool? checked;
  final List<_MdNode>? children;
  final List<String>? tableHeaders;
  final List<List<String>>? tableRows;

  _MdNode({
    this.type = _NodeType.text,
    this.text,
    this.url,
    this.level,
    this.language,
    this.ordered,
    this.checked,
    this.children,
    this.tableHeaders,
    this.tableRows,
  });
}