import 'dart:convert';

/// Base class for all Lexical nodes.
///
/// Every node in the Lexical document tree extends this class.
/// Nodes are identified by [type] and carry a schema [version].
abstract class LexicalNode {
  LexicalNode({required this.type, this.version = 1});

  /// The Lexical node type identifier (e.g. "text", "paragraph", "heading").
  final String type;

  /// Schema version for forward/backward compatibility.
  final int version;

  /// Serialises this node to a Lexical-compatible JSON map.
  Map<String, dynamic> toJson();

  /// Deep-clone this node.
  LexicalNode copy();

  @override
  String toString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LexicalNode &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          version == other.version;

  @override
  int get hashCode => type.hashCode ^ version.hashCode;
}
