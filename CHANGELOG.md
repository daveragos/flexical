## 0.1.0

- Initial release
- Rich text editor widget (`FlexicalEditor`) with inline formatting toolbar
- Outputs **Lexical JSON** — cross-platform compatible with Meta's Lexical framework
- Inline formatting: bold, italic, underline, strikethrough, code
- Block types: paragraphs, headings (H1–H3), block quotes, bullet lists, numbered lists
- Lexical-standard keyboard behaviors:
  - Enter splits blocks, creates new paragraphs
  - Enter on empty heading/quote exits to paragraph
  - Enter on empty list item exits the list
  - Backspace at start of a block merges with previous
  - Backspace at start of a list item exits to paragraph
  - Bullet ↔ Number list switching
  - Toggle-off for all block types
- Undo/redo support
- Preview mode toggle
- Fully customizable theming via `FlexicalTheme`
- Read-only rendering mode
- Serialization/deserialization of Lexical JSON documents
