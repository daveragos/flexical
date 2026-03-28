import 'node.dart';

/// Base class for nodes that can contain children (block-level nodes).
///
/// Maps to the Lexical `ElementNode` concept. Paragraphs, headings, quotes,
/// lists, and list items all extend this.
abstract class ElementNode extends LexicalNode {
  ElementNode({
    required super.type,
    List<LexicalNode>? children,
    this.direction = 'ltr',
    this.format = '',
    this.indent = 0,
  }) : children = children ?? [];

  /// Child nodes (typically [TextNode]s or nested [ElementNode]s).
  final List<LexicalNode> children;

  /// Text direction: "ltr" or "rtl".
  String direction;

  /// Block-level format.
  String format;

  /// Indentation level.
  int indent;

  /// Extracts all plain text from this element by walking child text nodes.
  String get plainText {
    final buf = StringBuffer();
    for (final child in children) {
      if (child is ElementNode) {
        buf.write(child.plainText);
      } else {
        // TextNode or LineBreakNode
        final json = child.toJson();
        buf.write(json['text'] ?? '\n');
      }
    }
    return buf.toString();
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'version': version,
    'children': children.map((c) => c.toJson()).toList(),
    'direction': direction,
    'format': format,
    'indent': indent,
  };
}
