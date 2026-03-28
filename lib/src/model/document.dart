import 'element_node.dart';
import 'paragraph_node.dart';
import 'text_node.dart';

/// The root document containing the block-level node tree.
///
/// This is the top-level container in the Lexical document model.
/// It serialises to `{ "root": { ... } }`.
class FlexicalDocument {
  FlexicalDocument({List<ElementNode>? children})
    : children =
          children ??
          [
            ParagraphNode(children: [TextNode(text: '')]),
          ];

  /// The top-level block nodes (paragraphs, headings, lists, etc.).
  final List<ElementNode> children;

  /// Creates an empty document with a single empty paragraph.
  factory FlexicalDocument.empty() => FlexicalDocument();

  /// Serialises the entire document to Lexical JSON format.
  Map<String, dynamic> toJson() => {
    'root': {
      'type': 'root',
      'version': 1,
      'children': children.map((c) => c.toJson()).toList(),
      'direction': 'ltr',
      'format': '',
      'indent': 0,
    },
  };

  /// Extracts all plain text from the document.
  String get plainText => children.map((c) => c.plainText).join('\n');

  /// Deep-clone this document.
  FlexicalDocument copy() => FlexicalDocument(
    children: children.map((c) => c.copy() as ElementNode).toList(),
  );

  @override
  String toString() => 'FlexicalDocument(blocks: ${children.length})';
}
