import 'element_node.dart';
import 'node.dart';

/// A paragraph block node — the default block type.
class ParagraphNode extends ElementNode {
  ParagraphNode({super.children, super.direction, super.format, super.indent})
    : super(type: 'paragraph');

  @override
  ParagraphNode copy() => ParagraphNode(
    children: children.map((c) => c.copy()).toList(),
    direction: direction,
    format: format,
    indent: indent,
  );

  factory ParagraphNode.fromJson(
    Map<String, dynamic> json,
    List<LexicalNode> children,
  ) {
    return ParagraphNode(
      children: children,
      direction: json['direction'] as String? ?? 'ltr',
      format: json['format']?.toString() ?? '',
      indent: json['indent'] as int? ?? 0,
    );
  }
}
