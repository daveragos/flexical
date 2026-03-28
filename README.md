# Flexical

A native Flutter rich text editor that outputs **Lexical JSON** — the format used by [Meta's Lexical framework](https://lexical.dev/).

Write rich text in Flutter, get cross-platform compatible JSON that works with Lexical on web, React Native, and anywhere else.

## Features

- **Inline formatting** — Bold, italic, underline, strikethrough, code
- **Block types** — Paragraphs, headings (H1–H3), block quotes, bullet & numbered lists
- **Lexical JSON output** — Serialize/deserialize documents in standard Lexical format
- **Standard keyboard behaviors** — Enter, backspace, list exit, block merging (matches Quill/Lexical UX)
- **Preview mode** — Toggle between editing and rendered preview
- **Undo/redo** — Full history support
- **Theming** — Customizable via `FlexicalTheme` or auto-derived from `ThemeData`
- **Read-only mode** — Render Lexical JSON without editing

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flexical: ^0.1.0
```

## Usage

```dart
import 'package:flexical/flexical.dart';

// Create a controller
final controller = FlexicalController();

// Embed the editor
FlexicalEditor(
  controller: controller,
  placeholder: 'Start writing...',
  onChanged: (json) {
    // json is a Map<String, dynamic> in Lexical format
    print(json);
  },
);

// Get Lexical JSON
final lexicalJson = controller.toJson();

// Load existing Lexical JSON
controller.loadJson(existingJson);
```

### Read-Only Rendering

```dart
final controller = FlexicalController(readOnly: true);
controller.loadJson(lexicalJson);

FlexicalEditor(
  controller: controller,
  showToolbar: false,
);
```

### Custom Theme

```dart
FlexicalEditor(
  controller: controller,
  theme: FlexicalTheme(
    textStyle: TextStyle(fontSize: 16),
    cursorColor: Colors.blue,
    toolbarColor: Colors.grey.shade100,
    bulletColor: Colors.black87,
  ),
);
```

## Lexical JSON Format

The editor outputs standard Lexical JSON:

```json
{
  "root": {
    "type": "root",
    "version": 1,
    "children": [
      {
        "type": "paragraph",
        "children": [
          { "type": "text", "text": "Hello ", "format": 0 },
          { "type": "text", "text": "world", "format": 1 }
        ]
      }
    ]
  }
}
```

Format flags: `1` = bold, `2` = italic, `4` = strikethrough, `8` = underline, `16` = code.

## License

MIT — see [LICENSE](LICENSE).
