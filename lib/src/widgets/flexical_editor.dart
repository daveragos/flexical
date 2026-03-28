import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lexical_reader/flutter_lexical_reader.dart';

import '../editor/controller.dart';
import '../model/element_node.dart';
import '../model/heading_node.dart';
import '../model/list_node.dart';
import '../model/node.dart';
import '../model/paragraph_node.dart';
import '../model/quote_node.dart';
import '../model/text_node.dart';
import '../theme/flexical_theme.dart';
import 'flexical_toolbar.dart';

/// The main Flexical editor widget.
class FlexicalEditor extends StatefulWidget {
  const FlexicalEditor({
    super.key,
    required this.controller,
    this.placeholder = 'Start writing...',
    this.theme,
    this.showToolbar = true,
    this.toolbarConfig,
    this.minHeight = 150,
    this.maxHeight,
    this.autofocus = false,
    this.decoration,
    this.padding,
    this.onChanged,
  });

  /// The controller that manages the editor's document and selection.
  final FlexicalController controller;

  /// The text to display when the editor is empty.
  final String placeholder;

  /// The theme to use for the editor's appearance.
  /// If null, a default theme is derived from the ambient [ThemeData].
  final FlexicalTheme? theme;

  /// Whether to show the formatting toolbar.
  final bool showToolbar;

  /// An optional custom toolbar widget.
  final Widget? toolbarConfig;

  /// The minimum height of the editor area.
  final double minHeight;

  /// The maximum height of the editor area.
  final double? maxHeight;

  /// Whether the editor should be focused automatically.
  final bool autofocus;

  /// The decoration for the editor container.
  final BoxDecoration? decoration;

  /// The padding for the editor area.
  final EdgeInsets? padding;

  /// A callback that is called whenever the editor's content changes.
  final ValueChanged<Map<String, dynamic>>? onChanged;

  @override
  State<FlexicalEditor> createState() => _FlexicalEditorState();
}

class _FlexicalEditorState extends State<FlexicalEditor> {
  /// Block-level controllers, keyed by block index.
  final Map<int, _FormattedBlockController> _blockControllers = {};
  final Map<int, FocusNode> _blockFocusNodes = {};

  /// Stores the previous plain text per block for diffing on changes.
  final Map<int, String> _previousBlockTexts = {};

  /// List item controllers, keyed by "$blockIndex:$itemIndex".
  final Map<String, _FormattedBlockController> _listItemControllers = {};
  final Map<String, FocusNode> _listItemFocusNodes = {};
  final Map<String, String> _previousListItemTexts = {};

  FlexicalTheme? _themeOverride;
  FlexicalTheme get _theme => _themeOverride ?? const FlexicalTheme.fallback();

  /// Whether the editor is in preview mode.
  bool _isPreview = false;

  /// Prevents feedback loops during programmatic text updates.
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onDocumentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeOverride = widget.theme ?? FlexicalTheme.fromTheme(Theme.of(context));
    _syncAllControllers();
  }

  @override
  void didUpdateWidget(covariant FlexicalEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onDocumentChanged);
      widget.controller.addListener(_onDocumentChanged);
      _syncAllControllers();
    }
    _themeOverride = widget.theme ?? FlexicalTheme.fromTheme(Theme.of(context));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocumentChanged);
    for (final c in _blockControllers.values) {
      c.dispose();
    }
    for (final f in _blockFocusNodes.values) {
      f.dispose();
    }
    for (final c in _listItemControllers.values) {
      c.dispose();
    }
    for (final f in _listItemFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDocumentChanged() {
    if (_isSyncing) return;
    _syncAllControllers();
    widget.onChanged?.call(widget.controller.toJson());
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Controller syncing — NO ZWS, just plain text
  // ---------------------------------------------------------------------------

  void _syncAllControllers() {
    final doc = widget.controller.document;

    // Clean up stale block controllers.
    final staleBlockKeys =
        _blockControllers.keys.where((k) => k >= doc.children.length).toList();
    for (final key in staleBlockKeys) {
      _blockControllers.remove(key)?.dispose();
      _blockFocusNodes.remove(key)?.dispose();
      _previousBlockTexts.remove(key);
    }

    final activeListKeys = <String>{};

    for (int i = 0; i < doc.children.length; i++) {
      final block = doc.children[i];

      if (block is ListNode) {
        for (int j = 0; j < block.children.length; j++) {
          final key = '$i:$j';
          activeListKeys.add(key);
          _listItemControllers.putIfAbsent(
            key,
            () => _FormattedBlockController(),
          );
          _listItemFocusNodes.putIfAbsent(
            key,
            () => _createListItemFocusNode(i, j),
          );

          final item = block.children[j];
          final itemText = item is ElementNode ? item.plainText : '';
          final ctrl = _listItemControllers[key]!;
          if (ctrl.text != itemText) {
            ctrl.text = itemText;
          }
          _previousListItemTexts[key] = itemText;

          ctrl.updateFormatting(
            item is ElementNode ? item.children : [],
            _theme.textStyle ?? const TextStyle(fontSize: 16),
            _applyFormat,
          );
        }
        _blockControllers.remove(i)?.dispose();
        _blockFocusNodes.remove(i)?.dispose();
        _previousBlockTexts.remove(i);
      } else {
        _blockControllers.putIfAbsent(i, () => _FormattedBlockController());
        _blockFocusNodes.putIfAbsent(i, () => _createBlockFocusNode(i));

        final plainText = block.plainText;
        final ctrl = _blockControllers[i]!;
        if (ctrl.text != plainText) {
          ctrl.text = plainText;
        }
        _previousBlockTexts[i] = plainText;

        ctrl.updateFormatting(
          block.children,
          _getBaseStyle(block),
          _applyFormat,
        );
      }
    }

    final staleListKeys =
        _listItemControllers.keys
            .where((k) => !activeListKeys.contains(k))
            .toList();
    for (final key in staleListKeys) {
      _listItemControllers.remove(key)?.dispose();
      _listItemFocusNodes.remove(key)?.dispose();
      _previousListItemTexts.remove(key);
    }
  }

  // ---------------------------------------------------------------------------
  // FocusNode creation with onKeyEvent for backspace detection
  // ---------------------------------------------------------------------------

  FocusNode _createBlockFocusNode(int blockIndex) {
    return FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }

        final ctrl = _blockControllers[blockIndex];
        if (ctrl == null) return KeyEventResult.ignored;

        // Backspace at position 0 → merge with previous block.
        if (ctrl.selection.baseOffset == 0 &&
            ctrl.selection.extentOffset == 0 &&
            blockIndex > 0) {
          _handleBackspaceMergeWithText(blockIndex, ctrl.text);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
    );
  }

  FocusNode _createListItemFocusNode(int blockIndex, int itemIndex) {
    return FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }

        final key = '$blockIndex:$itemIndex';
        final ctrl = _listItemControllers[key];
        if (ctrl == null) return KeyEventResult.ignored;

        // Backspace at position 0 in a list item.
        if (ctrl.selection.baseOffset == 0 &&
            ctrl.selection.extentOffset == 0) {
          final block = widget.controller.document.children[blockIndex];
          if (block is ListNode) {
            _exitListItemWithText(block, blockIndex, itemIndex, ctrl.text);
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          widget.decoration ??
          _theme.editorDecoration ??
          BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showToolbar)
            widget.toolbarConfig ??
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: FlexicalToolbar(
                    controller: widget.controller,
                    theme: _theme,
                    onPreviewToggle: () {
                      setState(() => _isPreview = !_isPreview);
                    },
                    isPreview: _isPreview,
                  ),
                ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.minHeight,
                maxHeight: widget.maxHeight ?? double.infinity,
              ),
              child: SingleChildScrollView(
                padding:
                    widget.padding ??
                    _theme.editorPadding ??
                    const EdgeInsets.all(16),
                child:
                    (_isPreview || widget.controller.readOnly)
                        ? _buildPreview()
                        : _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return LexicalParser(sourceMap: widget.controller.toJson());
  }

  Widget _buildContent() {
    final doc = widget.controller.document;
    if (doc.children.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          widget.placeholder,
          style:
              _theme.placeholderStyle ?? TextStyle(color: Colors.grey.shade400),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < doc.children.length; i++)
          _buildBlock(doc.children[i], i),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Block rendering
  // ---------------------------------------------------------------------------

  Widget _buildBlock(ElementNode block, int blockIndex) {
    if (block is ListNode) {
      return _buildList(block, blockIndex);
    }

    Widget field = _buildEditableBlock(block, blockIndex);

    if (block is HeadingNode) {
      field = Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: field,
      );
    } else if (block is QuoteNode) {
      field = Container(
        decoration:
            _theme.quoteDecoration ??
            BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey.shade400, width: 3),
              ),
            ),
        padding:
            _theme.quotePadding ??
            const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: field,
      );
    }

    return Padding(padding: const EdgeInsets.only(bottom: 4), child: field);
  }

  Widget _buildEditableBlock(ElementNode block, int blockIndex) {
    final controller = _blockControllers[blockIndex];
    final focusNode = _blockFocusNodes[blockIndex];
    if (controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    final baseStyle = _getBaseStyle(block);
    final isEmpty = controller.text.isEmpty;
    final isFirst = blockIndex == 0;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: baseStyle,
      autofocus: widget.autofocus && isFirst,
      cursorColor: _theme.cursorColor,
      textDirection: TextDirection.ltr,
      maxLines: null,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: isFirst && isEmpty ? widget.placeholder : null,
        hintStyle: _theme.placeholderStyle,
      ),
      onChanged: (text) => _handleBlockTextChanged(blockIndex, text),
      onTap: () {
        widget.controller.updateSelection(
          FlexicalSelection.collapsed(
            blockIndex: blockIndex,
            offset: controller.selection.baseOffset,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // List rendering
  // ---------------------------------------------------------------------------

  Widget _buildList(ListNode list, int blockIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < list.children.length; i++)
            _buildListItem(list, i, blockIndex),
        ],
      ),
    );
  }

  Widget _buildListItem(ListNode list, int itemIndex, int blockIndex) {
    final key = '$blockIndex:$itemIndex';
    final controller = _listItemControllers[key];
    final focusNode = _listItemFocusNodes[key];
    if (controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    final isBullet = list.listType == 'bullet';
    final prefix = isBullet ? '•' : '${itemIndex + 1}.';
    final baseStyle = _theme.textStyle ?? const TextStyle(fontSize: 16);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.ltr,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              prefix,
              style: baseStyle.copyWith(
                color: _theme.bulletColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: baseStyle,
              textDirection: TextDirection.ltr,
              maxLines: null,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: itemIndex == 0 ? 'List item...' : null,
                hintStyle: _theme.placeholderStyle,
              ),
              onChanged:
                  (text) => _handleListItemChanged(blockIndex, itemIndex, text),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  void _handleBlockTextChanged(int blockIndex, String newText) {
    _isSyncing = true;

    // Update the controller's active block index.
    widget.controller.updateSelection(
      FlexicalSelection.collapsed(
        blockIndex: blockIndex,
        offset:
            _blockControllers[blockIndex]?.selection.baseOffset ??
            newText.length,
      ),
    );

    // Detect Enter key: newline in the text.
    final newlineIndex = newText.indexOf('\n');
    if (newlineIndex != -1) {
      _handleBlockSplit(blockIndex, newText, newlineIndex);
      return;
    }

    // Backspace merge: if non-first block becomes empty via deletion.
    final oldText = _previousBlockTexts[blockIndex] ?? '';
    if (newText.isEmpty && oldText.isNotEmpty && blockIndex > 0) {
      _handleBackspaceMergeWithText(blockIndex, '');
      return;
    }

    // Normal text change — compute diff and apply to model.
    final cursorPos =
        _blockControllers[blockIndex]?.selection.baseOffset ?? newText.length;

    widget.controller.handleBlockTextChange(
      blockIndex,
      oldText,
      newText,
      cursorPos,
    );

    // Update the custom controller's formatting info.
    final block = widget.controller.document.children[blockIndex];
    _blockControllers[blockIndex]?.updateFormatting(
      block.children,
      _getBaseStyle(block),
      _applyFormat,
    );

    _previousBlockTexts[blockIndex] = newText;
    _isSyncing = false;
    widget.onChanged?.call(widget.controller.toJson());
  }

  void _handleBlockSplit(int blockIndex, String fullText, int newlineIndex) {
    final before = fullText.substring(0, newlineIndex);
    final after = fullText.substring(newlineIndex + 1);

    final block = widget.controller.document.children[blockIndex];
    final activeFormat = widget.controller.currentFormat;

    // Lexical behavior: Enter on empty heading/quote → convert to paragraph.
    if (before.isEmpty && after.isEmpty) {
      if (block is HeadingNode || block is QuoteNode) {
        final para = ParagraphNode(
          children: [TextNode(text: '', format: activeFormat)],
        );
        widget.controller.document.children[blockIndex] = para;

        _isSyncing = false;
        _syncAllControllers();
        widget.onChanged?.call(widget.controller.toJson());
        setState(() {});

        widget.controller.setPendingFormat(activeFormat);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _blockFocusNodes[blockIndex]?.requestFocus();
          _blockControllers[blockIndex]
              ?.selection = const TextSelection.collapsed(offset: 0);
        });
        return;
      }
    }

    // Split text nodes at the newline position, preserving format structure.
    final beforeChildren = <LexicalNode>[];
    final afterChildren = <LexicalNode>[];
    int acc = 0;

    for (final child in block.children) {
      if (child is TextNode) {
        final nodeStart = acc;
        final nodeEnd = acc + child.text.length;

        if (nodeEnd <= newlineIndex) {
          beforeChildren.add(child.copy());
        } else if (nodeStart >= newlineIndex) {
          afterChildren.add(child.copy());
        } else {
          final splitAt = newlineIndex - nodeStart;
          if (splitAt > 0) {
            beforeChildren.add(
              TextNode(
                text: child.text.substring(0, splitAt),
                format: child.format,
              ),
            );
          }
          if (splitAt < child.text.length) {
            afterChildren.add(
              TextNode(
                text: child.text.substring(splitAt),
                format: child.format,
              ),
            );
          }
        }

        acc = nodeEnd;
      } else {
        if (acc <= newlineIndex) {
          beforeChildren.add(child.copy());
        } else {
          afterChildren.add(child.copy());
        }
      }
    }

    if (beforeChildren.isEmpty) {
      beforeChildren.add(TextNode(text: '', format: activeFormat));
    }
    if (afterChildren.isEmpty) {
      afterChildren.add(TextNode(text: '', format: activeFormat));
    }

    block.children
      ..clear()
      ..addAll(beforeChildren);

    final newBlock = ParagraphNode(children: afterChildren);
    widget.controller.document.children.insert(blockIndex + 1, newBlock);

    _isSyncing = false;
    _syncAllControllers();
    widget.onChanged?.call(widget.controller.toJson());
    setState(() {});

    widget.controller.setPendingFormat(activeFormat);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _blockFocusNodes[blockIndex + 1]?.requestFocus();
      _blockControllers[blockIndex + 1]
          ?.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  /// Merges a block with the previous block, appending remainingText.
  ///
  /// Handles both empty blocks (backspace on empty) and backspace at start
  /// of a block with remaining text.
  void _handleBackspaceMergeWithText(int blockIndex, String remainingText) {
    if (blockIndex <= 0) return;
    _isSyncing = true;

    final prevBlock = widget.controller.document.children[blockIndex - 1];
    final prevTextLen = prevBlock.plainText.length;

    if (remainingText.isNotEmpty) {
      // Append remaining text to the previous block.
      if (prevBlock.children.isNotEmpty &&
          prevBlock.children.last is TextNode) {
        (prevBlock.children.last as TextNode).text += remainingText;
      } else {
        prevBlock.children.add(TextNode(text: remainingText));
      }
    }

    // Remove the current block.
    widget.controller.document.children.removeAt(blockIndex);

    _isSyncing = false;
    _syncAllControllers();
    widget.onChanged?.call(widget.controller.toJson());
    setState(() {});

    // Focus previous block at the merge point.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (prevBlock is ListNode) {
        final lastItemIndex = prevBlock.children.length - 1;
        final key = '${blockIndex - 1}:$lastItemIndex';
        _listItemFocusNodes[key]?.requestFocus();
        final ctrl = _listItemControllers[key];
        if (ctrl != null) {
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        }
      } else {
        _blockFocusNodes[blockIndex - 1]?.requestFocus();
        final ctrl = _blockControllers[blockIndex - 1];
        if (ctrl != null) {
          ctrl.selection = TextSelection.collapsed(offset: prevTextLen);
        }
      }
    });
  }

  void _handleListItemChanged(int blockIndex, int itemIndex, String newText) {
    _isSyncing = true;

    final block = widget.controller.document.children[blockIndex];
    if (block is! ListNode) {
      _isSyncing = false;
      return;
    }

    // Detect Enter key.
    final newlineIndex = newText.indexOf('\n');
    if (newlineIndex != -1) {
      _handleListItemSplit(block, blockIndex, itemIndex, newText, newlineIndex);
      return;
    }

    // Normal text change.
    final item = block.children[itemIndex];
    if (item is ElementNode) {
      item.children
        ..clear()
        ..add(TextNode(text: newText));
    }

    final key = '$blockIndex:$itemIndex';
    _previousListItemTexts[key] = newText;
    _isSyncing = false;
    widget.onChanged?.call(widget.controller.toJson());
  }

  void _handleListItemSplit(
    ListNode list,
    int blockIndex,
    int itemIndex,
    String fullText,
    int newlineIndex,
  ) {
    final before = fullText.substring(0, newlineIndex);
    final after = fullText.substring(newlineIndex + 1);

    // Enter on empty list item → exit list.
    if (before.isEmpty && after.isEmpty) {
      _exitListItem(list, blockIndex, itemIndex);
      return;
    }

    // Update current item.
    final item = list.children[itemIndex];
    if (item is ElementNode) {
      item.children
        ..clear()
        ..add(TextNode(text: before));
    }

    // Insert new list item.
    final newItem = ListItemNode(
      value: itemIndex + 2,
      children: [TextNode(text: after)],
    );
    list.children.insert(itemIndex + 1, newItem);

    for (int j = itemIndex + 2; j < list.children.length; j++) {
      final it = list.children[j];
      if (it is ListItemNode) {
        it.value = j + 1;
      }
    }

    _isSyncing = false;
    _syncAllControllers();
    widget.onChanged?.call(widget.controller.toJson());
    setState(() {});

    final newKey = '$blockIndex:${itemIndex + 1}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listItemFocusNodes[newKey]?.requestFocus();
      _listItemControllers[newKey]?.selection = const TextSelection.collapsed(
        offset: 0,
      );
    });
  }

  /// Exits list mode for an empty item.
  void _exitListItem(ListNode list, int blockIndex, int itemIndex) {
    list.children.removeAt(itemIndex);

    int focusBlockIndex;

    if (list.children.isEmpty) {
      final newPara = ParagraphNode(children: [TextNode(text: '')]);
      widget.controller.document.children[blockIndex] = newPara;
      focusBlockIndex = blockIndex;
    } else {
      final newPara = ParagraphNode(children: [TextNode(text: '')]);
      widget.controller.document.children.insert(blockIndex + 1, newPara);
      focusBlockIndex = blockIndex + 1;
    }

    _isSyncing = false;
    _syncAllControllers();
    widget.onChanged?.call(widget.controller.toJson());
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _blockFocusNodes[focusBlockIndex]?.requestFocus();
      _blockControllers[focusBlockIndex]
          ?.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  /// Exits a list item with remaining text — converts it to a paragraph.
  void _exitListItemWithText(
    ListNode list,
    int blockIndex,
    int itemIndex,
    String text,
  ) {
    _isSyncing = true;

    if (itemIndex == 0 && list.children.length == 1) {
      // Only item → replace list with paragraph.
      final para = ParagraphNode(children: [TextNode(text: text)]);
      widget.controller.document.children[blockIndex] = para;
    } else if (itemIndex == 0) {
      // First item but others exist → extract to paragraph before list.
      list.children.removeAt(0);
      final para = ParagraphNode(children: [TextNode(text: text)]);
      widget.controller.document.children.insert(blockIndex, para);
    } else {
      // Remove from list, insert paragraph after the list.
      list.children.removeAt(itemIndex);
      final para = ParagraphNode(children: [TextNode(text: text)]);
      widget.controller.document.children.insert(blockIndex + 1, para);
    }

    _isSyncing = false;
    _syncAllControllers();
    widget.onChanged?.call(widget.controller.toJson());
    setState(() {});

    final focusIndex = itemIndex == 0 ? blockIndex : blockIndex + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _blockFocusNodes[focusIndex]?.requestFocus();
      _blockControllers[focusIndex]?.selection = const TextSelection.collapsed(
        offset: 0,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  TextStyle _getBaseStyle(ElementNode block) {
    TextStyle style = _theme.textStyle ?? const TextStyle(fontSize: 16);
    if (block is HeadingNode) {
      final level = block.level.clamp(1, 3) - 1;
      if (_theme.headingStyles != null &&
          level < _theme.headingStyles!.length) {
        style = _theme.headingStyles![level];
      }
    } else if (block is QuoteNode) {
      style =
          _theme.quoteTextStyle ?? style.copyWith(fontStyle: FontStyle.italic);
    }
    return style;
  }

  // Removed _buildTextSpans as it is now handled by LexicalParser.

  TextStyle _applyFormat(TextStyle base, int format) {
    var style = base;
    if (TextFormat.has(format, TextFormat.bold)) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    if (TextFormat.has(format, TextFormat.italic)) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (TextFormat.has(format, TextFormat.underline)) {
      style = style.copyWith(
        decoration: TextDecoration.combine([
          style.decoration ?? TextDecoration.none,
          TextDecoration.underline,
        ]),
      );
    }
    if (TextFormat.has(format, TextFormat.strikethrough)) {
      style = style.copyWith(
        decoration: TextDecoration.combine([
          style.decoration ?? TextDecoration.none,
          TextDecoration.lineThrough,
        ]),
      );
    }
    if (TextFormat.has(format, TextFormat.code)) {
      style = style.copyWith(
        fontFamily: 'monospace',
        backgroundColor: Colors.grey.shade200,
      );
    }
    return style;
  }
}

// =============================================================================
// Custom TextEditingController that renders inline formatting via buildTextSpan
// =============================================================================

class _FormattedBlockController extends TextEditingController {
  List<LexicalNode> _children = [];
  TextStyle _baseStyle = const TextStyle();
  TextStyle Function(TextStyle, int)? _formatApplier;

  void updateFormatting(
    List<LexicalNode> children,
    TextStyle baseStyle,
    TextStyle Function(TextStyle, int) formatApplier,
  ) {
    _children = children;
    _baseStyle = baseStyle;
    _formatApplier = formatApplier;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? _baseStyle;

    if (_children.isEmpty || text.isEmpty || _formatApplier == null) {
      return TextSpan(text: text, style: effectiveStyle);
    }

    final spans = <InlineSpan>[];
    int consumed = 0;

    for (final child in _children) {
      if (child is TextNode) {
        if (consumed >= text.length) break;
        final end = (consumed + child.text.length).clamp(0, text.length);

        spans.add(
          TextSpan(
            text: text.substring(consumed, end),
            style: _formatApplier!(effectiveStyle, child.format),
          ),
        );
        consumed = end;
      }
    }

    if (consumed < text.length) {
      spans.add(
        TextSpan(text: text.substring(consumed), style: effectiveStyle),
      );
    }

    return TextSpan(children: spans, style: effectiveStyle);
  }
}
