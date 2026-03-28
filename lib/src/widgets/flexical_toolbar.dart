import 'package:flutter/material.dart';

import '../editor/controller.dart';
import '../model/text_node.dart';
import '../theme/flexical_theme.dart';

/// A toolbar widget for the Flexical editor.
///
/// Displays formatting and block-type buttons. Updates reactively
/// based on the [FlexicalController]'s current state.
class FlexicalToolbar extends StatelessWidget {
  const FlexicalToolbar({
    super.key,
    required this.controller,
    this.theme,
    this.showBold = true,
    this.showItalic = true,
    this.showUnderline = true,
    this.showStrikethrough = true,
    this.showHeadings = true,
    this.showQuote = true,
    this.showBulletList = true,
    this.showNumberedList = true,
    this.showUndo = true,
    this.showRedo = true,
    this.showPreview = true,
    this.onPreviewToggle,
    this.isPreview = false,
  });

  /// The controller that manages the editor's state.
  final FlexicalController controller;

  /// The theme to use for the toolbar's appearance.
  final FlexicalTheme? theme;

  /// Whether to show the Bold button.
  final bool showBold;

  /// Whether to show the Italic button.
  final bool showItalic;

  /// Whether to show the Underline button.
  final bool showUnderline;

  /// Whether to show the Strikethrough button.
  final bool showStrikethrough;

  /// Whether to show the Heading (H1, H2, H3) buttons.
  final bool showHeadings;

  /// Whether to show the Block Quote button.
  final bool showQuote;

  /// Whether to show the Bullet List button.
  final bool showBulletList;

  /// Whether to show the Numbered List button.
  final bool showNumberedList;

  /// Whether to show the Undo button.
  final bool showUndo;

  /// Whether to show the Redo button.
  final bool showRedo;

  /// Whether to show the Preview toggle button.
  final bool showPreview;

  /// A callback that is called when the preview mode is toggled.
  final VoidCallback? onPreviewToggle;

  /// Whether the editor is currently in preview mode.
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? FlexicalTheme.fromTheme(Theme.of(context));

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final format = controller.currentFormat;
        final blockType = controller.currentBlockType;

        return Container(
          decoration: BoxDecoration(
            color: effectiveTheme.toolbarColor,
            border: Border(
              bottom: BorderSide(
                color:
                    effectiveTheme.toolbarDividerColor ?? Colors.grey.shade300,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // --- Inline format buttons ---
                if (showBold)
                  _FormatButton(
                    icon: Icons.format_bold,
                    isActive: TextFormat.has(format, TextFormat.bold),
                    onPressed: () => controller.toggleFormat(TextFormat.bold),
                    theme: effectiveTheme,
                    tooltip: 'Bold',
                  ),
                if (showItalic)
                  _FormatButton(
                    icon: Icons.format_italic,
                    isActive: TextFormat.has(format, TextFormat.italic),
                    onPressed: () => controller.toggleFormat(TextFormat.italic),
                    theme: effectiveTheme,
                    tooltip: 'Italic',
                  ),
                if (showUnderline)
                  _FormatButton(
                    icon: Icons.format_underline,
                    isActive: TextFormat.has(format, TextFormat.underline),
                    onPressed:
                        () => controller.toggleFormat(TextFormat.underline),
                    theme: effectiveTheme,
                    tooltip: 'Underline',
                  ),
                if (showStrikethrough)
                  _FormatButton(
                    icon: Icons.format_strikethrough,
                    isActive: TextFormat.has(format, TextFormat.strikethrough),
                    onPressed:
                        () => controller.toggleFormat(TextFormat.strikethrough),
                    theme: effectiveTheme,
                    tooltip: 'Strikethrough',
                  ),
                if (showHeadings ||
                    showQuote ||
                    showBulletList ||
                    showNumberedList) ...[
                  _ToolbarDivider(theme: effectiveTheme),
                ],
                // --- Block type buttons ---
                if (showHeadings) ...[
                  _BlockButton(
                    label: 'H1',
                    isActive: blockType == 'heading:h1',
                    onPressed:
                        () => controller.setBlockToHeading(
                          controller.selection.blockIndex,
                          'h1',
                        ),
                    theme: effectiveTheme,
                    tooltip: 'Heading 1',
                  ),
                  _BlockButton(
                    label: 'H2',
                    isActive: blockType == 'heading:h2',
                    onPressed:
                        () => controller.setBlockToHeading(
                          controller.selection.blockIndex,
                          'h2',
                        ),
                    theme: effectiveTheme,
                    tooltip: 'Heading 2',
                  ),
                  _BlockButton(
                    label: 'H3',
                    isActive: blockType == 'heading:h3',
                    onPressed:
                        () => controller.setBlockToHeading(
                          controller.selection.blockIndex,
                          'h3',
                        ),
                    theme: effectiveTheme,
                    tooltip: 'Heading 3',
                  ),
                ],
                if (showQuote)
                  _FormatButton(
                    icon: Icons.format_quote,
                    isActive: blockType == 'quote',
                    onPressed:
                        () => controller.setBlockToQuote(
                          controller.selection.blockIndex,
                        ),
                    theme: effectiveTheme,
                    tooltip: 'Block Quote',
                  ),
                if (showBulletList)
                  _FormatButton(
                    icon: Icons.format_list_bulleted,
                    isActive: blockType == 'list:bullet',
                    onPressed:
                        () => controller.setBlockToList(
                          controller.selection.blockIndex,
                          'bullet',
                        ),
                    theme: effectiveTheme,
                    tooltip: 'Bullet List',
                  ),
                if (showNumberedList)
                  _FormatButton(
                    icon: Icons.format_list_numbered,
                    isActive: blockType == 'list:number',
                    onPressed:
                        () => controller.setBlockToList(
                          controller.selection.blockIndex,
                          'number',
                        ),
                    theme: effectiveTheme,
                    tooltip: 'Numbered List',
                  ),
                if (showUndo || showRedo) ...[
                  _ToolbarDivider(theme: effectiveTheme),
                ],
                if (showUndo)
                  _FormatButton(
                    icon: Icons.undo,
                    isActive: false,
                    onPressed: controller.canUndo ? controller.undo : null,
                    theme: effectiveTheme,
                    tooltip: 'Undo',
                  ),
                if (showRedo)
                  _FormatButton(
                    icon: Icons.redo,
                    isActive: false,
                    onPressed: controller.canRedo ? controller.redo : null,
                    theme: effectiveTheme,
                    tooltip: 'Redo',
                  ),
                if (showPreview) ...[
                  _ToolbarDivider(theme: effectiveTheme),
                  _FormatButton(
                    icon: isPreview ? Icons.edit : Icons.visibility,
                    isActive: isPreview,
                    onPressed: onPreviewToggle,
                    theme: effectiveTheme,
                    tooltip: isPreview ? 'Edit' : 'Preview',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.theme,
    required this.tooltip,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;
  final FlexicalTheme theme;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration:
              isActive
                  ? BoxDecoration(
                    color: (theme.toolbarActiveIconColor ?? Colors.blue)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  )
                  : null,
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color:
                onPressed == null
                    ? (theme.toolbarIconColor ?? Colors.grey).withValues(
                      alpha: 0.4,
                    )
                    : isActive
                    ? theme.toolbarActiveIconColor
                    : theme.toolbarIconColor,
          ),
        ),
      ),
    );
  }
}

class _BlockButton extends StatelessWidget {
  const _BlockButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
    required this.theme,
    required this.tooltip,
  });

  final String label;
  final bool isActive;
  final VoidCallback? onPressed;
  final FlexicalTheme theme;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration:
              isActive
                  ? BoxDecoration(
                    color: (theme.toolbarActiveIconColor ?? Colors.blue)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  )
                  : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color:
                  isActive
                      ? theme.toolbarActiveIconColor
                      : theme.toolbarIconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider({required this.theme});

  final FlexicalTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: theme.toolbarDividerColor ?? Colors.grey.shade300,
    );
  }
}
