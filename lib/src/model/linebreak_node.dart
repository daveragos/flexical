import 'node.dart';

/// A line break node — represents a hard line break within a block.
class LineBreakNode extends LexicalNode {
  LineBreakNode() : super(type: 'linebreak');

  @override
  Map<String, dynamic> toJson() => {'type': type, 'version': version};

  @override
  LineBreakNode copy() => LineBreakNode();

  factory LineBreakNode.fromJson(Map<String, dynamic> _) => LineBreakNode();
}
