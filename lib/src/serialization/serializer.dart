import 'dart:convert';

import '../model/document.dart';

/// Serialises a [FlexicalDocument] to Lexical JSON.
///
/// The document model already knows how to `toJson()`, but this class
/// provides the convenience of encoding to a JSON string directly.
class FlexicalSerializer {
  const FlexicalSerializer();

  /// Converts a [FlexicalDocument] to a Lexical JSON map.
  Map<String, dynamic> serialize(FlexicalDocument document) =>
      document.toJson();

  /// Converts a [FlexicalDocument] to a JSON-encoded string.
  String serializeToString(FlexicalDocument document) =>
      jsonEncode(document.toJson());
}
