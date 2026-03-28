import 'package:flutter/material.dart';

/// Theme data for the Flexical editor.
///
/// Controls the visual appearance of text, blocks, toolbar, and the editor
/// container. Falls back to the ambient [ThemeData] when values are null.
class FlexicalTheme {
  const FlexicalTheme({
    this.textStyle,
    this.headingStyles,
    this.quoteDecoration,
    this.quotePadding,
    this.quoteTextStyle,
    this.bulletColor,
    this.toolbarColor,
    this.toolbarIconColor,
    this.toolbarActiveIconColor,
    this.toolbarDividerColor,
    this.editorPadding,
    this.editorDecoration,
    this.cursorColor,
    this.selectionColor,
    this.placeholderStyle,
  });

  /// A minimal const fallback with all null values.
  const FlexicalTheme.fallback()
    : textStyle = null,
      headingStyles = null,
      quoteDecoration = null,
      quotePadding = null,
      quoteTextStyle = null,
      bulletColor = null,
      toolbarColor = null,
      toolbarIconColor = null,
      toolbarActiveIconColor = null,
      toolbarDividerColor = null,
      editorPadding = null,
      editorDecoration = null,
      cursorColor = null,
      selectionColor = null,
      placeholderStyle = null;

  /// Default text style for paragraph content.
  final TextStyle? textStyle;

  /// Styles for heading levels h1 through h6.
  /// Index 0 = h1, index 1 = h2, etc.
  final List<TextStyle>? headingStyles;

  /// Decoration for block quotes (e.g. left border).
  final BoxDecoration? quoteDecoration;

  /// Padding inside block quotes.
  final EdgeInsets? quotePadding;

  /// Text style override for block quote content.
  final TextStyle? quoteTextStyle;

  /// Color for bullet points.
  final Color? bulletColor;

  /// Background color of the toolbar.
  final Color? toolbarColor;

  /// Color of inactive toolbar icons.
  final Color? toolbarIconColor;

  /// Color of active toolbar icons.
  final Color? toolbarActiveIconColor;

  /// Color of toolbar dividers.
  final Color? toolbarDividerColor;

  /// Padding around the editor content area.
  final EdgeInsets? editorPadding;

  /// Decoration for the editor container.
  final BoxDecoration? editorDecoration;

  /// Color of the text cursor.
  final Color? cursorColor;

  /// Color of the text selection highlight.
  final Color? selectionColor;

  /// Text style for the placeholder hint.
  final TextStyle? placeholderStyle;

  /// Creates a sensible default theme derived from [ThemeData].
  factory FlexicalTheme.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return FlexicalTheme(
      textStyle: theme.textTheme.bodyLarge,
      headingStyles: [
        theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold) ??
            const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold) ??
            const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold) ??
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ],
      quoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            width: 3,
          ),
        ),
      ),
      quotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      quoteTextStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
        fontStyle: FontStyle.italic,
      ),
      bulletColor: isDark ? Colors.white70 : Colors.black87,
      toolbarColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      toolbarIconColor: isDark ? Colors.white70 : Colors.grey.shade700,
      toolbarActiveIconColor: theme.colorScheme.primary,
      toolbarDividerColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      editorPadding: const EdgeInsets.all(16),
      cursorColor: theme.colorScheme.primary,
      selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      placeholderStyle: TextStyle(
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      ),
    );
  }

  /// Copies this theme with the given overrides.
  FlexicalTheme copyWith({
    TextStyle? textStyle,
    List<TextStyle>? headingStyles,
    BoxDecoration? quoteDecoration,
    EdgeInsets? quotePadding,
    TextStyle? quoteTextStyle,
    Color? bulletColor,
    Color? toolbarColor,
    Color? toolbarIconColor,
    Color? toolbarActiveIconColor,
    Color? toolbarDividerColor,
    EdgeInsets? editorPadding,
    BoxDecoration? editorDecoration,
    Color? cursorColor,
    Color? selectionColor,
    TextStyle? placeholderStyle,
  }) {
    return FlexicalTheme(
      textStyle: textStyle ?? this.textStyle,
      headingStyles: headingStyles ?? this.headingStyles,
      quoteDecoration: quoteDecoration ?? this.quoteDecoration,
      quotePadding: quotePadding ?? this.quotePadding,
      quoteTextStyle: quoteTextStyle ?? this.quoteTextStyle,
      bulletColor: bulletColor ?? this.bulletColor,
      toolbarColor: toolbarColor ?? this.toolbarColor,
      toolbarIconColor: toolbarIconColor ?? this.toolbarIconColor,
      toolbarActiveIconColor:
          toolbarActiveIconColor ?? this.toolbarActiveIconColor,
      toolbarDividerColor: toolbarDividerColor ?? this.toolbarDividerColor,
      editorPadding: editorPadding ?? this.editorPadding,
      editorDecoration: editorDecoration ?? this.editorDecoration,
      cursorColor: cursorColor ?? this.cursorColor,
      selectionColor: selectionColor ?? this.selectionColor,
      placeholderStyle: placeholderStyle ?? this.placeholderStyle,
    );
  }
}
