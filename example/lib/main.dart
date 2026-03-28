import 'dart:convert';

import 'package:flexical/flexical.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FlexicalExampleApp());
}

class FlexicalExampleApp extends StatelessWidget {
  const FlexicalExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flexical Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const FlexicalExamplePage(),
    );
  }
}

class FlexicalExamplePage extends StatefulWidget {
  const FlexicalExamplePage({super.key});

  @override
  State<FlexicalExamplePage> createState() => _FlexicalExamplePageState();
}

class _FlexicalExamplePageState extends State<FlexicalExamplePage> {
  late FlexicalController _controller;
  String _jsonOutput = '';

  @override
  void initState() {
    super.initState();
    _controller = FlexicalController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flexical Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Show JSON Output',
            onPressed: _showJsonOutput,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Load Sample',
            onPressed: _loadSample,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FlexicalEditor(
                controller: _controller,
                placeholder: 'Start writing your content...',
                autofocus: true,
                onChanged: (json) {
                  setState(() {
                    _jsonOutput = const JsonEncoder.withIndent(
                      '  ',
                    ).convert(json);
                  });
                },
              ),
            ),
          ),
          if (_jsonOutput.isNotEmpty) ...[
            const Divider(),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: SingleChildScrollView(
                  child: SelectableText(
                    _jsonOutput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showJsonOutput() {
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(_controller.toJson());
    setState(() {
      _jsonOutput = json;
    });
  }

  void _loadSample() {
    const sampleJson = {
      'root': {
        'type': 'root',
        'version': 1,
        'direction': 'ltr',
        'format': '',
        'indent': 0,
        'children': [
          {
            'type': 'heading',
            'version': 1,
            'tag': 'h1',
            'direction': 'ltr',
            'format': '',
            'indent': 0,
            'children': [
              {
                'type': 'text',
                'version': 1,
                'text': 'Welcome to Flexical',
                'format': 0,
                'detail': 0,
                'mode': 'normal',
                'style': '',
              },
            ],
          },
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
                'text': 'This is a ',
                'format': 0,
                'detail': 0,
                'mode': 'normal',
                'style': '',
              },
              {
                'type': 'text',
                'version': 1,
                'text': 'rich text editor',
                'format': 1,
                'detail': 0,
                'mode': 'normal',
                'style': '',
              },
              {
                'type': 'text',
                'version': 1,
                'text': ' that outputs ',
                'format': 0,
                'detail': 0,
                'mode': 'normal',
                'style': '',
              },
              {
                'type': 'text',
                'version': 1,
                'text': 'Lexical JSON',
                'format': 2,
                'detail': 0,
                'mode': 'normal',
                'style': '',
              },
              {
                'type': 'text',
                'version': 1,
                'text': '.',
                'format': 0,
                'detail': 0,
                'mode': 'normal',
                'style': '',
              },
            ],
          },
          {
            'type': 'quote',
            'version': 1,
            'direction': 'ltr',
            'format': '',
            'indent': 0,
            'children': [
              {
                'type': 'text',
                'version': 1,
                'text': 'Edit in Flutter, view everywhere.',
                'format': 0,
                'detail': 0,
                'mode': 'normal',
                'style': '',
              },
            ],
          },
        ],
      },
    };

    _controller.loadJson(sampleJson);
    setState(() {
      _jsonOutput = const JsonEncoder.withIndent('  ').convert(sampleJson);
    });
  }
}
