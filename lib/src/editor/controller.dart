import 'package:flutter/foundation.dart';

import '../model/document.dart';
import '../model/element_node.dart';
import '../model/heading_node.dart';
import '../model/linebreak_node.dart';
import '../model/list_node.dart';
import '../model/node.dart';
import '../model/paragraph_node.dart';
import '../model/quote_node.dart';
import '../model/text_node.dart';
import '../serialization/deserializer.dart';

/// Selection within the editor, tracking block index and text offset.
class FlexicalSelection {
  const FlexicalSelection({
    required this.blockIndex,
    required this.offset,
    this.extentBlockIndex,
    this.extentOffset,
  });

  /// The index of the block where the selection starts.
  final int blockIndex;

  /// The character offset within the block where the selection starts.
  final int offset;

  /// The index of the block where the selection ends.
  /// If null, the selection is assumed to be collapsed at [blockIndex].
  final int? extentBlockIndex;

  /// The character offset within the block where the selection ends.
  /// If null, the selection is assumed to be collapsed at [offset].
  final int? extentOffset;

  /// Whether this selection is collapsed (cursor, no range).
  bool get isCollapsed =>
      (extentBlockIndex == null || extentBlockIndex == blockIndex) &&
      (extentOffset == null || extentOffset == offset);

  /// Returns the effective block index where the selection ends.
  int get effectiveExtentBlock => extentBlockIndex ?? blockIndex;

  /// Returns the effective character offset where the selection ends.
  int get effectiveExtentOffset => extentOffset ?? offset;

  /// Creates a copy of this selection with given fields replaced.
  FlexicalSelection copyWith({
    int? blockIndex,
    int? offset,
    int? extentBlockIndex,
    int? extentOffset,
  }) => FlexicalSelection(
    blockIndex: blockIndex ?? this.blockIndex,
    offset: offset ?? this.offset,
    extentBlockIndex: extentBlockIndex ?? this.extentBlockIndex,
    extentOffset: extentOffset ?? this.extentOffset,
  );

  /// Creates a collapsed selection at the given position.
  factory FlexicalSelection.collapsed({
    required int blockIndex,
    required int offset,
  }) => FlexicalSelection(blockIndex: blockIndex, offset: offset);

  @override
  String toString() =>
      'FlexicalSelection(block: $blockIndex, offset: $offset'
      '${isCollapsed ? '' : ', extent: $effectiveExtentBlock:$effectiveExtentOffset'})';
}

/// The controller that manages the document, selection, and editing operations.
///
/// This is the main entry point for programmatic interaction with the editor.
class FlexicalController extends ChangeNotifier {
  /// Creates a [FlexicalController] with an optional initial [document].
  ///
  /// If [readOnly] is true, the editor will render the content using
  /// an external reader and disable all editing operations.
  FlexicalController({FlexicalDocument? document, this.readOnly = false})
    : _document = document ?? FlexicalDocument.empty(),
      _selection = FlexicalSelection.collapsed(blockIndex: 0, offset: 0);

  FlexicalDocument _document;
  FlexicalSelection _selection;

  /// Whether the editor is in read-only mode.
  final bool readOnly;

  // Undo/redo stacks
  final List<_HistoryEntry> _undoStack = [];
  final List<_HistoryEntry> _redoStack = [];
  static const int _maxHistory = 100;

  /// Pending format for next typed characters. null = use format at cursor.
  int? _pendingFormat;

  /// The current document.
  FlexicalDocument get document => _document;

  /// The current selection.
  FlexicalSelection get selection => _selection;

  /// Whether undo is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Returns the current block type for toolbar state.
  ///
  /// Possible values: 'paragraph', 'heading:h1', 'heading:h2', 'heading:h3',
  /// 'quote', 'list:bullet', 'list:number'.
  String get currentBlockType {
    if (_selection.blockIndex >= _document.children.length) return 'paragraph';
    final block = _document.children[_selection.blockIndex];
    if (block is HeadingNode) return 'heading:${block.tag}';
    if (block is QuoteNode) return 'quote';
    if (block is ListNode) return 'list:${block.listType}';
    return 'paragraph';
  }

  // ---------------------------------------------------------------------------
  // Document loading
  // ---------------------------------------------------------------------------

  /// Replaces the document with a new one, clearing history.
  void setDocument(FlexicalDocument doc) {
    _undoStack.clear();
    _redoStack.clear();
    _document = doc;
    _pendingFormat = null;
    _selection = FlexicalSelection.collapsed(blockIndex: 0, offset: 0);
    notifyListeners();
  }

  /// Loads a document from Lexical JSON.
  void loadJson(Map<String, dynamic> json) {
    setDocument(const FlexicalDeserializer().deserialize(json));
  }

  /// Returns the current document as Lexical JSON.
  Map<String, dynamic> toJson() => _document.toJson();

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  /// Updates the selection. Clears pending format when block changes.
  void updateSelection(FlexicalSelection newSelection) {
    if (newSelection.blockIndex != _selection.blockIndex) {
      _pendingFormat = null;
    }
    _selection = newSelection;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Text insertion (programmatic)
  // ---------------------------------------------------------------------------

  /// Inserts text at the current cursor position.
  void insertText(String text) {
    if (readOnly) return;
    _saveHistory();

    final block = _document.children[_selection.blockIndex];
    _insertTextInBlock(block, _selection.offset, text);
    _selection = FlexicalSelection.collapsed(
      blockIndex: _selection.blockIndex,
      offset: _selection.offset + text.length,
    );
    notifyListeners();
  }

  /// Deletes the character before the cursor (backspace).
  void deleteBackward() {
    if (readOnly) return;
    if (_selection.offset == 0 && _selection.blockIndex == 0) return;
    _saveHistory();

    if (_selection.offset == 0) {
      _mergeWithPreviousBlock(_selection.blockIndex);
    } else {
      final block = _document.children[_selection.blockIndex];
      _deleteCharInBlock(block, _selection.offset - 1);
      _selection = _selection.copyWith(offset: _selection.offset - 1);
    }
    notifyListeners();
  }

  /// Handles the Enter key — splits the current block.
  void insertLineBreak() {
    if (readOnly) return;
    _saveHistory();

    final blockIndex = _selection.blockIndex;
    final block = _document.children[blockIndex];
    final offset = _selection.offset;
    final fullText = block.plainText;

    final textBefore = fullText.substring(0, offset);
    final textAfter = fullText.substring(offset);

    block.children
      ..clear()
      ..add(TextNode(text: textBefore));

    final newBlock = ParagraphNode(children: [TextNode(text: textAfter)]);
    _document.children.insert(blockIndex + 1, newBlock);

    _selection = FlexicalSelection.collapsed(
      blockIndex: blockIndex + 1,
      offset: 0,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Gets the active format (pending format if set, otherwise format at cursor).
  int get currentFormat =>
      _pendingFormat ?? getBlockFormat(_selection.blockIndex);

  /// Returns the format of the first text node in the block at [blockIndex].
  int getBlockFormat(int blockIndex) {
    if (blockIndex >= _document.children.length) return 0;
    final block = _document.children[blockIndex];
    for (final child in block.children) {
      if (child is TextNode) return child.format;
    }
    return 0;
  }

  /// Sets the format to be applied to the next inserted text.
  ///
  /// This is used internally to carry formatting across block splits.
  void setPendingFormat(int format) {
    _pendingFormat = format;
  }

  /// Toggles a format flag for the NEXT typed characters (pending format).
  ///
  /// Does NOT modify existing text — only affects what gets typed next.
  void toggleFormat(int formatFlag) {
    if (readOnly) return;
    final current = _pendingFormat ?? getBlockFormat(_selection.blockIndex);
    _pendingFormat = TextFormat.toggle(current, formatFlag);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Text change handling (called by the editor widget)
  // ---------------------------------------------------------------------------

  /// Called by the editor when a block's text content changes (user typing).
  ///
  /// Computes the diff between [oldText] and [newText] and updates the
  /// block's text nodes, applying the pending format to inserted characters.
  void handleBlockTextChange(
    int blockIndex,
    String oldText,
    String newText,
    int cursorPos,
  ) {
    if (readOnly) return;
    _saveHistory();

    final block = _document.children[blockIndex];
    final lenDiff = newText.length - oldText.length;

    if (lenDiff > 0) {
      // Text was inserted.
      final insertPos = cursorPos - lenDiff;
      final insertedText = newText.substring(insertPos, cursorPos);
      final format =
          _pendingFormat ?? _getFormatAtOffset(block.children, insertPos);

      _insertFormattedText(block, insertPos, insertedText, format);
    } else if (lenDiff < 0) {
      // Text was deleted.
      final deletePos = cursorPos;
      final deleteCount = -lenDiff;
      _deleteFormattedText(block, deletePos, deleteCount);
    }

    _selection = FlexicalSelection.collapsed(
      blockIndex: blockIndex,
      offset: cursorPos,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Block type changes
  // ---------------------------------------------------------------------------

  /// Converts the block at [blockIndex] to a [ParagraphNode].
  void setBlockToParagraph(int blockIndex) => _convertBlock(
    blockIndex,
    (children) => ParagraphNode(children: children),
  );

  /// Converts the block at [blockIndex] to a [HeadingNode] with [tag].
  ///
  /// If already the same heading, converts back to paragraph.
  void setBlockToHeading(int blockIndex, String tag) {
    if (readOnly) return;
    final block = _document.children[blockIndex];

    // Toggle off: same heading → paragraph.
    if (block is HeadingNode && block.tag == tag) {
      setBlockToParagraph(blockIndex);
      return;
    }

    // If it's a list, unpack first then convert.
    if (block is ListNode) {
      _unpackListThenConvert(
        blockIndex,
        (children) => HeadingNode(tag: tag, children: children),
      );
      return;
    }

    _convertBlock(
      blockIndex,
      (children) => HeadingNode(tag: tag, children: children),
    );
  }

  /// Converts the block at [blockIndex] to a [QuoteNode].
  ///
  /// If already a quote, converts back to paragraph.
  void setBlockToQuote(int blockIndex) {
    if (readOnly) return;
    final block = _document.children[blockIndex];

    // Toggle off: quote → paragraph.
    if (block is QuoteNode) {
      setBlockToParagraph(blockIndex);
      return;
    }

    // If it's a list, unpack first then convert.
    if (block is ListNode) {
      _unpackListThenConvert(
        blockIndex,
        (children) => QuoteNode(children: children),
      );
      return;
    }

    _convertBlock(blockIndex, (children) => QuoteNode(children: children));
  }

  /// Wraps the block at [blockIndex] in a [ListNode] of [listType].
  ///
  /// - Same list type → converts back to paragraphs (toggle off)
  /// - Different list type → switches (bullet ↔ number)
  /// - Non-list → wraps in list
  void setBlockToList(int blockIndex, String listType) {
    if (readOnly) return;
    _saveHistory();

    final block = _document.children[blockIndex];

    if (block is ListNode) {
      if (block.listType == listType) {
        // Same type → toggle off: convert items back to paragraphs.
        final items = block.children.toList();
        _document.children.removeAt(blockIndex);

        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final para = ParagraphNode(
            children:
                item is ElementNode
                    ? item.children.map((c) => c.copy()).toList()
                    : [TextNode(text: '')],
          );
          _document.children.insert(blockIndex + i, para);
        }
      } else {
        // Different type → switch (e.g. bullet → number).
        block.listType = listType;
      }

      notifyListeners();
      return;
    }

    // Non-list → wrap in a list.
    final listItem = ListItemNode(
      children: block.children.map((c) => c.copy()).toList(),
    );
    final listNode = ListNode(listType: listType, children: [listItem]);
    _document.children[blockIndex] = listNode;
    notifyListeners();
  }

  /// Unpacks a list's first item and converts it to a different block type.
  void _unpackListThenConvert(
    int blockIndex,
    ElementNode Function(List<LexicalNode>) factory,
  ) {
    _saveHistory();
    final block = _document.children[blockIndex] as ListNode;
    final firstItem = block.children.first;
    final children =
        firstItem is ElementNode
            ? firstItem.children.map((c) => c.copy()).toList()
            : <LexicalNode>[TextNode(text: '')];

    // Replace list with converted block.
    _document.children[blockIndex] = factory(children);

    // If there were more list items, keep them as a separate list.
    if (block.children.length > 1) {
      final remainingItems = block.children.sublist(1);
      final remainingList = ListNode(
        listType: block.listType,
        children: remainingItems.map((c) => c.copy()).toList(),
      );
      _document.children.insert(blockIndex + 1, remainingList);
    }

    notifyListeners();
  }

  void _convertBlock(
    int blockIndex,
    ElementNode Function(List<LexicalNode>) factory,
  ) {
    if (readOnly) return;
    _saveHistory();

    final block = _document.children[blockIndex];
    final newBlock = factory(block.children.map((c) => c.copy()).toList());
    _document.children[blockIndex] = newBlock;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Undo / Redo
  // ---------------------------------------------------------------------------

  void undo() {
    if (!canUndo) return;
    final entry = _undoStack.removeLast();
    _redoStack.add(
      _HistoryEntry(document: _document.copy(), selection: _selection),
    );
    _document = entry.document;
    _selection = entry.selection;
    _pendingFormat = null;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final entry = _redoStack.removeLast();
    _undoStack.add(
      _HistoryEntry(document: _document.copy(), selection: _selection),
    );
    _document = entry.document;
    _selection = entry.selection;
    _pendingFormat = null;
    notifyListeners();
  }

  void _saveHistory() {
    _redoStack.clear();
    _undoStack.add(
      _HistoryEntry(document: _document.copy(), selection: _selection),
    );
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers — formatted text operations
  // ---------------------------------------------------------------------------

  /// Gets the format at [offset] by walking the text nodes.
  int _getFormatAtOffset(List<LexicalNode> children, int offset) {
    int acc = 0;
    for (final child in children) {
      if (child is TextNode) {
        if (offset >= acc && offset <= acc + child.text.length) {
          return child.format;
        }
        acc += child.text.length;
      }
    }
    // Return format of last text node.
    for (final child in children.reversed) {
      if (child is TextNode) return child.format;
    }
    return 0;
  }

  /// Inserts [text] at [offset] in [block] with the given [format].
  ///
  /// If the text node at the insertion point has the same format, it just
  /// extends the node. Otherwise, it splits the node and inserts a new one.
  void _insertFormattedText(
    ElementNode block,
    int offset,
    String text,
    int format,
  ) {
    int acc = 0;

    for (int i = 0; i < block.children.length; i++) {
      final node = block.children[i];
      if (node is TextNode) {
        final nodeEnd = acc + node.text.length;

        if (offset >= acc && offset <= nodeEnd) {
          if (node.format == format) {
            // Same format — just insert into the text.
            final insertAt = offset - acc;
            node.text =
                node.text.substring(0, insertAt) +
                text +
                node.text.substring(insertAt);
          } else {
            // Different format — split and insert a new node.
            final insertAt = offset - acc;
            final before = node.text.substring(0, insertAt);
            final after = node.text.substring(insertAt);

            final newNodes = <LexicalNode>[];
            if (before.isNotEmpty) {
              newNodes.add(TextNode(text: before, format: node.format));
            }
            newNodes.add(TextNode(text: text, format: format));
            if (after.isNotEmpty) {
              newNodes.add(TextNode(text: after, format: node.format));
            }

            block.children.removeAt(i);
            block.children.insertAll(i, newNodes);
          }
          return;
        }

        acc = nodeEnd;
      }
    }

    // Past all nodes — append.
    if (block.children.isNotEmpty &&
        block.children.last is TextNode &&
        (block.children.last as TextNode).format == format) {
      (block.children.last as TextNode).text += text;
    } else {
      block.children.add(TextNode(text: text, format: format));
    }
  }

  /// Deletes [count] characters starting at [offset] in [block].
  void _deleteFormattedText(ElementNode block, int offset, int count) {
    int remaining = count;
    int acc = 0;

    for (int i = 0; i < block.children.length && remaining > 0; i++) {
      final node = block.children[i];
      if (node is! TextNode) continue;

      final nodeEnd = acc + node.text.length;

      if (offset < nodeEnd && offset + remaining > acc) {
        final localStart = (offset - acc).clamp(0, node.text.length);
        final localEnd = (offset + remaining - acc).clamp(0, node.text.length);
        final deleted = localEnd - localStart;

        node.text =
            node.text.substring(0, localStart) + node.text.substring(localEnd);
        remaining -= deleted;
      }

      acc = nodeEnd;
    }

    // Remove empty text nodes (keep at least one).
    block.children.removeWhere((n) => n is TextNode && n.text.isEmpty);
    if (block.children.isEmpty) {
      block.children.add(TextNode(text: ''));
    }

    // Merge adjacent nodes with same format.
    _mergeAdjacentNodes(block);
  }

  /// Merges adjacent text nodes that share the same format.
  void _mergeAdjacentNodes(ElementNode block) {
    for (int i = block.children.length - 1; i > 0; i--) {
      final curr = block.children[i];
      final prev = block.children[i - 1];
      if (curr is TextNode && prev is TextNode && curr.format == prev.format) {
        prev.text += curr.text;
        block.children.removeAt(i);
      }
    }
  }

  /// Inserts text at [offset] (used by programmatic insertText).
  void _insertTextInBlock(ElementNode block, int offset, String text) {
    int acc = 0;
    for (final node in block.children) {
      if (node is TextNode) {
        if (acc + node.text.length >= offset) {
          final insertAt = offset - acc;
          node.text =
              node.text.substring(0, insertAt) +
              text +
              node.text.substring(insertAt);
          return;
        }
        acc += node.text.length;
      } else if (node is LineBreakNode) {
        acc += 1;
      }
    }

    if (block.children.isNotEmpty && block.children.last is TextNode) {
      (block.children.last as TextNode).text += text;
    } else {
      block.children.add(TextNode(text: text));
    }
  }

  void _deleteCharInBlock(ElementNode block, int charIndex) {
    int acc = 0;
    for (int i = 0; i < block.children.length; i++) {
      final node = block.children[i];
      if (node is TextNode) {
        if (acc + node.text.length > charIndex) {
          final deleteAt = charIndex - acc;
          node.text =
              node.text.substring(0, deleteAt) +
              node.text.substring(deleteAt + 1);
          if (node.text.isEmpty && block.children.length > 1) {
            block.children.removeAt(i);
          }
          return;
        }
        acc += node.text.length;
      } else if (node is LineBreakNode) {
        if (acc == charIndex) {
          block.children.removeAt(i);
          return;
        }
        acc += 1;
      }
    }
  }

  void _mergeWithPreviousBlock(int blockIndex) {
    if (blockIndex == 0) return;
    final prev = _document.children[blockIndex - 1];
    final curr = _document.children[blockIndex];

    final prevTextLen = prev.plainText.length;
    prev.children.addAll(curr.children.map((c) => c.copy()));
    _document.children.removeAt(blockIndex);

    _selection = FlexicalSelection.collapsed(
      blockIndex: blockIndex - 1,
      offset: prevTextLen,
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({required this.document, required this.selection});
  final FlexicalDocument document;
  final FlexicalSelection selection;
}
