import 'element_node.dart';
import 'node.dart';

/// A block quote node.
class QuoteNode extends ElementNode {
  QuoteNode({super.children, super.direction, super.format, super.indent})
    : super(type: 'quote');

  @override
  QuoteNode copy() => QuoteNode(
    children: children.map((c) => c.copy()).toList(),
    direction: direction,
    format: format,
    indent: indent,
  );

  factory QuoteNode.fromJson(
    Map<String, dynamic> json,
    List<LexicalNode> children,
  ) {
    return QuoteNode(
      children: children,
      direction: json['direction'] as String? ?? 'ltr',
      format: json['format']?.toString() ?? '',
      indent: json['indent'] as int? ?? 0,
    );
  }
}
