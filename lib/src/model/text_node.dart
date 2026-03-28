import 'node.dart';

/// Bitmask constants for inline text formatting.
///
/// These match the Lexical JS editor specification exactly.
abstract final class TextFormat {
  static const int bold = 1; // bit 0
  static const int italic = 2; // bit 1
  static const int strikethrough = 4; // bit 2
  static const int underline = 8; // bit 3
  static const int code = 16; // bit 4
  static const int subscript = 32; // bit 5
  static const int superscript = 64; // bit 6
  static const int highlight = 128; // bit 7

  /// Returns true if [format] has the given [flag] set.
  static bool has(int format, int flag) => (format & flag) != 0;

  /// Returns [format] with [flag] toggled.
  static int toggle(int format, int flag) => format ^ flag;
}

/// A leaf node containing text content with optional formatting.
class TextNode extends LexicalNode {
  TextNode({
    required this.text,
    this.format = 0,
    this.detail = 0,
    this.mode = 'normal',
    this.style = '',
  }) : super(type: 'text');

  /// The text content.
  String text;

  /// Bitmask of active formats (see [TextFormat]).
  int format;

  /// Detail flags.
  int detail;

  /// Text mode: "normal", "token", or "segmented".
  String mode;

  /// Inline CSS style string.
  String style;

  // Convenience getters
  bool get isBold => TextFormat.has(format, TextFormat.bold);
  bool get isItalic => TextFormat.has(format, TextFormat.italic);
  bool get isUnderline => TextFormat.has(format, TextFormat.underline);
  bool get isStrikethrough => TextFormat.has(format, TextFormat.strikethrough);
  bool get isCode => TextFormat.has(format, TextFormat.code);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'version': version,
    'text': text,
    'format': format,
    'detail': detail,
    'mode': mode,
    'style': style,
  };

  @override
  TextNode copy() => TextNode(
    text: text,
    format: format,
    detail: detail,
    mode: mode,
    style: style,
  );

  /// Creates a [TextNode] from a Lexical JSON map.
  factory TextNode.fromJson(Map<String, dynamic> json) => TextNode(
    text: json['text'] as String? ?? '',
    format: json['format'] as int? ?? 0,
    detail: json['detail'] as int? ?? 0,
    mode: json['mode'] as String? ?? 'normal',
    style: json['style'] as String? ?? '',
  );
}
