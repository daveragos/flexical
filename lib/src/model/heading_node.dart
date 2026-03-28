import 'element_node.dart';
import 'node.dart';

/// A heading block node (h1 through h6).
class HeadingNode extends ElementNode {
  HeadingNode({
    required this.tag,
    super.children,
    super.direction,
    super.format,
    super.indent,
  }) : super(type: 'heading');

  /// The heading level tag: "h1", "h2", "h3", etc.
  final String tag;

  /// Convenience getter for heading level as integer.
  int get level => int.tryParse(tag.replaceAll('h', '')) ?? 1;

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'tag': tag};

  @override
  HeadingNode copy() => HeadingNode(
    tag: tag,
    children: children.map((c) => c.copy()).toList(),
    direction: direction,
    format: format,
    indent: indent,
  );

  factory HeadingNode.fromJson(
    Map<String, dynamic> json,
    List<LexicalNode> children,
  ) {
    return HeadingNode(
      tag: json['tag'] as String? ?? 'h1',
      children: children,
      direction: json['direction'] as String? ?? 'ltr',
      format: json['format']?.toString() ?? '',
      indent: json['indent'] as int? ?? 0,
    );
  }
}
