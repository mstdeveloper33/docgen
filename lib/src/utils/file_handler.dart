import 'dart:io';

import 'package:path/path.dart' as p;

class FileHandler {
  static const _outputDir = 'docs';

  static Future<String> writeDocumentation({
    required String sourceFilePath,
    required String markdownContent,
  }) async {
    final dir = Directory(_outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Sanitize filename to prevent path traversal
    final baseName = p.basenameWithoutExtension(p.basename(sourceFilePath));
    final sanitized = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final outputPath = p.join(_outputDir, '$sanitized.md');

    final file = File(outputPath);
    await file.writeAsString(markdownContent);

    return outputPath;
  }
}
