import '../model/document.dart';
import '../model/element_node.dart';
import '../model/heading_node.dart';
import '../model/linebreak_node.dart';
import '../model/list_node.dart';
import '../model/node.dart';
import '../model/paragraph_node.dart';
import '../model/quote_node.dart';
import '../model/text_node.dart';

/// Deserialises Lexical JSON into a [FlexicalDocument].
class FlexicalDeserializer {
  const FlexicalDeserializer();

  /// Parses a Lexical JSON map into a [FlexicalDocument].
  ///
  /// Expects the standard Lexical format: `{ "root": { "children": [...] } }`.
  FlexicalDocument deserialize(Map<String, dynamic> json) {
    final root = json['root'] as Map<String, dynamic>?;
    if (root == null) return FlexicalDocument.empty();

    final childrenJson = root['children'] as List<dynamic>?;
    if (childrenJson == null || childrenJson.isEmpty) {
      return FlexicalDocument.empty();
    }

    final children = <ElementNode>[];
    for (final childJson in childrenJson) {
      if (childJson is Map<String, dynamic>) {
        final node = _parseNode(childJson);
        if (node is ElementNode) {
          children.add(node);
        }
      }
    }

    return FlexicalDocument(children: children.isEmpty ? null : children);
  }

  /// Recursively parses a single node from JSON.
  LexicalNode _parseNode(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';

    switch (type) {
      case 'text':
        return TextNode.fromJson(json);
      case 'linebreak':
        return LineBreakNode.fromJson(json);
      case 'paragraph':
        return ParagraphNode.fromJson(json, _parseChildren(json));
      case 'heading':
        return HeadingNode.fromJson(json, _parseChildren(json));
      case 'quote':
        return QuoteNode.fromJson(json, _parseChildren(json));
      case 'list':
        return ListNode.fromJson(json, _parseChildren(json));
      case 'listitem':
        return ListItemNode.fromJson(json, _parseChildren(json));
      default:
        // Unknown node type — treat as paragraph to avoid data loss.
        return ParagraphNode.fromJson(json, _parseChildren(json));
    }
  }

  /// Parses the "children" array of an element node.
  List<LexicalNode> _parseChildren(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List<dynamic>?;
    if (childrenJson == null) return [];

    return childrenJson
        .whereType<Map<String, dynamic>>()
        .map(_parseNode)
        .toList();
  }
}
