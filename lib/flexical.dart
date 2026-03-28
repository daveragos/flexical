/// Flexical — A native Flutter rich text editor that outputs Lexical JSON.
///
/// Use [FlexicalEditor] and [FlexicalController] to embed a rich text editor
/// in your app. The editor produces Lexical-compatible JSON that can be
/// rendered on any platform that supports the Lexical format.
///
/// ```dart
/// final controller = FlexicalController();
///
/// FlexicalEditor(
///   controller: controller,
///   placeholder: 'Start writing...',
/// );
///
/// // Get Lexical JSON output:
/// final json = controller.toJson();
/// ```

library;

// Model
export 'src/model/node.dart';
export 'src/model/text_node.dart';
export 'src/model/element_node.dart';
export 'src/model/paragraph_node.dart';
export 'src/model/heading_node.dart';
export 'src/model/quote_node.dart';
export 'src/model/list_node.dart';
export 'src/model/linebreak_node.dart';
export 'src/model/document.dart';

// Serialization
export 'src/serialization/serializer.dart';
export 'src/serialization/deserializer.dart';

// Editor
export 'src/editor/controller.dart';

// Widgets
export 'src/widgets/flexical_editor.dart';
export 'src/widgets/flexical_toolbar.dart';

// Theme
export 'src/theme/flexical_theme.dart';
