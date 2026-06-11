import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

enum OutputFormat { markdown, html, json }

class FileHandler {
  static const _outputDir = 'docs';

  static Future<String> writeDocumentation({
    required String sourceFilePath,
    required String markdownContent,
    OutputFormat format = OutputFormat.markdown,
  }) async {
    final dir = Directory(_outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Sanitize filename to prevent path traversal
    final baseName = p.basenameWithoutExtension(p.basename(sourceFilePath));
    final sanitized = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

    final extension = switch (format) {
      OutputFormat.markdown => 'md',
      OutputFormat.html => 'html',
      OutputFormat.json => 'json',
    };

    final outputPath = p.join(_outputDir, '$sanitized.$extension');
    final content = switch (format) {
      OutputFormat.markdown => markdownContent,
      OutputFormat.html => _markdownToHtml(markdownContent),
      OutputFormat.json => _markdownToJson(sanitized, markdownContent),
    };

    final file = File(outputPath);
    await file.writeAsString(content);

    return outputPath;
  }

  static String _markdownToHtml(String markdown) {
    // Simple markdown to HTML conversion
    var html = markdown;
    // Headers
    html = html.replaceAllMapped(
      RegExp(r'^### (.+)$', multiLine: true),
      (m) => '<h3>${m[1]}</h3>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^## (.+)$', multiLine: true),
      (m) => '<h2>${m[1]}</h2>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^# (.+)$', multiLine: true),
      (m) => '<h1>${m[1]}</h1>',
    );
    // Code blocks
    html = html.replaceAllMapped(
      RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true),
      (m) => '<pre><code class="language-${m[1]}">${m[2]}</code></pre>',
    );
    // Inline code
    html = html.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m[1]}</code>',
    );
    // Bold
    html = html.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (m) => '<strong>${m[1]}</strong>',
    );
    // Paragraphs
    html = html.replaceAllMapped(
      RegExp(r'^(?!<[hH\d]|<pre|<code|<strong|\|)(.+)$', multiLine: true),
      (m) => '<p>${m[1]}</p>',
    );

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Documentation</title>
  <style>
    body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; }
    pre { background: #f4f4f4; padding: 1rem; border-radius: 4px; overflow-x: auto; }
    code { background: #f4f4f4; padding: 0.2rem 0.4rem; border-radius: 3px; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
  </style>
</head>
<body>
$html
</body>
</html>''';
  }

  static String _markdownToJson(String name, String markdown) {
    return const JsonEncoder.withIndent('  ').convert({
      'name': name,
      'content': markdown,
      'generatedAt': DateTime.now().toIso8601String(),
    });
  }
}
