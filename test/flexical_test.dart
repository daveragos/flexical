import 'dart:convert';

import 'package:flexical/flexical.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlexicalDocument', () {
    test('empty document serializes correctly', () {
      final doc = FlexicalDocument.empty();
      final json = doc.toJson();

      expect(json['root'], isA<Map<String, dynamic>>());
      expect(json['root']['type'], 'root');
      expect(json['root']['children'], isA<List>());
      expect(json['root']['children'].length, 1); // single empty paragraph
    });

    test('document with paragraph serializes correctly', () {
      final doc = FlexicalDocument(
        children: [
          ParagraphNode(children: [TextNode(text: 'Hello world')]),
        ],
      );
      final json = doc.toJson();
      final para = json['root']['children'][0];

      expect(para['type'], 'paragraph');
      expect(para['children'][0]['text'], 'Hello world');
      expect(para['children'][0]['type'], 'text');
    });

    test('document with heading serializes correctly', () {
      final doc = FlexicalDocument(
        children: [
          HeadingNode(tag: 'h2', children: [TextNode(text: 'Title')]),
        ],
      );
      final json = doc.toJson();
      final heading = json['root']['children'][0];

      expect(heading['type'], 'heading');
      expect(heading['tag'], 'h2');
      expect(heading['children'][0]['text'], 'Title');
    });
  });

  group('TextNode formatting', () {
    test('format bitmask works correctly', () {
      final node = TextNode(text: 'Bold', format: TextFormat.bold);
      expect(node.isBold, isTrue);
      expect(node.isItalic, isFalse);
    });

    test('combined formats work', () {
      final node = TextNode(
        text: 'Bold+Italic',
        format: TextFormat.bold | TextFormat.italic,
      );
      expect(node.isBold, isTrue);
      expect(node.isItalic, isTrue);
      expect(node.isUnderline, isFalse);
    });

    test('toggle format', () {
      int format = 0;
      format = TextFormat.toggle(format, TextFormat.bold);
      expect(TextFormat.has(format, TextFormat.bold), isTrue);
      format = TextFormat.toggle(format, TextFormat.bold);
      expect(TextFormat.has(format, TextFormat.bold), isFalse);
    });
  });

  group('Serialization round-trip', () {
    test('paragraph round-trips correctly', () {
      final original = FlexicalDocument(
        children: [
          ParagraphNode(
            children: [
              TextNode(text: 'Hello '),
              TextNode(text: 'world', format: TextFormat.bold),
            ],
          ),
        ],
      );

      final json = original.toJson();
      final restored = const FlexicalDeserializer().deserialize(json);
      final restoredJson = restored.toJson();

      expect(jsonEncode(restoredJson), jsonEncode(json));
    });

    test('heading round-trips correctly', () {
      final original = FlexicalDocument(
        children: [
          HeadingNode(tag: 'h1', children: [TextNode(text: 'Title')]),
        ],
      );

      final json = original.toJson();
      final restored = const FlexicalDeserializer().deserialize(json);
      final restoredJson = restored.toJson();

      expect(jsonEncode(restoredJson), jsonEncode(json));
    });

    test('quote round-trips correctly', () {
      final original = FlexicalDocument(
        children: [
          QuoteNode(children: [TextNode(text: 'A quote')]),
        ],
      );

      final json = original.toJson();
      final restored = const FlexicalDeserializer().deserialize(json);
      final restoredJson = restored.toJson();

      expect(jsonEncode(restoredJson), jsonEncode(json));
    });

    test('list round-trips correctly', () {
      final original = FlexicalDocument(
        children: [
          ListNode(
            listType: 'bullet',
            children: [
              ListItemNode(children: [TextNode(text: 'Item 1')]),
              ListItemNode(value: 2, children: [TextNode(text: 'Item 2')]),
            ],
          ),
        ],
      );

      final json = original.toJson();
      final restored = const FlexicalDeserializer().deserialize(json);
      final restoredJson = restored.toJson();

      expect(jsonEncode(restoredJson), jsonEncode(json));
    });

    test('complex document round-trips correctly', () {
      final original = FlexicalDocument(
        children: [
          HeadingNode(tag: 'h1', children: [TextNode(text: 'Title')]),
          ParagraphNode(
            children: [
              TextNode(text: 'Normal '),
              TextNode(text: 'bold', format: TextFormat.bold),
              TextNode(text: ' and '),
              TextNode(text: 'italic', format: TextFormat.italic),
            ],
          ),
          QuoteNode(children: [TextNode(text: 'A quote')]),
          ListNode(
            listType: 'number',
            children: [
              ListItemNode(children: [TextNode(text: 'First')]),
              ListItemNode(value: 2, children: [TextNode(text: 'Second')]),
            ],
          ),
        ],
      );

      final json = original.toJson();
      final restored = const FlexicalDeserializer().deserialize(json);
      final restoredJson = restored.toJson();

      expect(jsonEncode(restoredJson), jsonEncode(json));
    });
  });

  group('FlexicalController', () {
    test('initializes with empty document', () {
      final controller = FlexicalController();
      expect(controller.document.children.length, 1);
      expect(controller.document.children.first, isA<ParagraphNode>());
      controller.dispose();
    });

    test('insertText works', () {
      final controller = FlexicalController();
      controller.insertText('Hello');
      expect(controller.document.children.first.plainText, 'Hello');
      controller.dispose();
    });

    test('undo/redo works', () {
      final controller = FlexicalController();
      controller.insertText('Hello');
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.document.children.first.plainText, '');
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.document.children.first.plainText, 'Hello');
      controller.dispose();
    });

    test('loadJson works', () {
      final controller = FlexicalController();
      controller.loadJson({
        'root': {
          'type': 'root',
          'version': 1,
          'direction': 'ltr',
          'format': '',
          'indent': 0,
          'children': [
            {
              'type': 'paragraph',
              'version': 1,
              'direction': 'ltr',
              'format': '',
              'indent': 0,
              'children': [
                {
                  'type': 'text',
                  'version': 1,
                  'text': 'Loaded text',
                  'format': 0,
                  'detail': 0,
                  'mode': 'normal',
                  'style': '',
                },
              ],
            },
          ],
        },
      });

      expect(controller.document.children.first.plainText, 'Loaded text');
      controller.dispose();
    });

    test('toJson produces valid Lexical JSON', () {
      final controller = FlexicalController();
      controller.insertText('Test');
      final json = controller.toJson();

      expect(json.containsKey('root'), isTrue);
      expect(json['root']['type'], 'root');
      expect(json['root']['children'], isA<List>());
      controller.dispose();
    });
  });
}
