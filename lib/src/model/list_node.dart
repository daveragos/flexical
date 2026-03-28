import 'element_node.dart';
import 'node.dart';

/// A list container node (unordered or ordered).
class ListNode extends ElementNode {
  ListNode({
    required this.listType,
    this.start = 1,
    super.children,
    super.direction,
    super.format,
    super.indent,
  }) : super(type: 'list');

  /// "bullet", "number", or "check".
  String listType;

  /// Starting number for ordered lists.
  final int start;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'listType': listType,
    'start': start,
    'tag': listType == 'number' ? 'ol' : 'ul',
  };

  @override
  ListNode copy() => ListNode(
    listType: listType,
    start: start,
    children: children.map((c) => c.copy()).toList(),
    direction: direction,
    format: format,
    indent: indent,
  );

  factory ListNode.fromJson(
    Map<String, dynamic> json,
    List<LexicalNode> children,
  ) {
    return ListNode(
      listType: json['listType'] as String? ?? 'bullet',
      start: json['start'] as int? ?? 1,
      children: children,
      direction: json['direction'] as String? ?? 'ltr',
      format: json['format']?.toString() ?? '',
      indent: json['indent'] as int? ?? 0,
    );
  }
}

/// A list item node — child of [ListNode].
class ListItemNode extends ElementNode {
  ListItemNode({
    this.value = 1,
    this.checked,
    super.children,
    super.direction,
    super.format,
    super.indent,
  }) : super(type: 'listitem');

  /// The item number/value.
  int value;

  /// For check lists, whether the item is checked.
  bool? checked;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['value'] = value;
    if (checked != null) {
      json['checked'] = checked;
    }
    return json;
  }

  @override
  ListItemNode copy() => ListItemNode(
    value: value,
    checked: checked,
    children: children.map((c) => c.copy()).toList(),
    direction: direction,
    format: format,
    indent: indent,
  );

  factory ListItemNode.fromJson(
    Map<String, dynamic> json,
    List<LexicalNode> children,
  ) {
    return ListItemNode(
      value: json['value'] as int? ?? 1,
      checked: json['checked'] as bool?,
      children: children,
      direction: json['direction'] as String? ?? 'ltr',
      format: json['format']?.toString() ?? '',
      indent: json['indent'] as int? ?? 0,
    );
  }
}
