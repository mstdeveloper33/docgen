import 'dart:convert';
import 'dart:io';

import '../analyzer/dart_analyzer.dart';
import '../analyzer/kotlin_parser.dart';

/// Generates a single README.md by analyzing the entire project structure.
class ReadmeGenerator {
  static Future<String> generate(List<String> files) async {
    final buffer = StringBuffer();
    final allStructures = <Map<String, dynamic>>[];

    for (final file in files) {
      Map<String, dynamic>? structure;
      if (file.endsWith('.dart')) {
        structure = await DartFileAnalyzer.analyze(file);
      } else if (file.endsWith('.kt')) {
        structure = await KotlinParser.analyze(file);
      }
      if (structure != null) allStructures.add(structure);
    }

    if (allStructures.isEmpty) return '';

    // Project name from directory
    final projectName = _detectProjectName();

    buffer.writeln('# $projectName');
    buffer.writeln();
    buffer.writeln('> Auto-generated project documentation by docgen');
    buffer.writeln();

    // Architecture overview
    buffer.writeln('## Architecture Overview');
    buffer.writeln();
    buffer.writeln('| File | Classes | Functions |');
    buffer.writeln('|------|---------|-----------|');

    for (final structure in allStructures) {
      final file = structure['file'] as String;
      final classes = structure['classes'] as List<dynamic>? ?? [];
      final functions = structure['topLevelFunctions'] as List<dynamic>? ?? [];

      final classNames = classes
          .map((c) => '`${(c as Map)['name']}`')
          .join(', ');
      final funcNames = functions
          .map((f) => '`${(f as Map)['name']}`')
          .join(', ');

      buffer.writeln(
        '| `${_shortenPath(file)}` | ${classNames.isEmpty ? '—' : classNames} | ${funcNames.isEmpty ? '—' : funcNames} |',
      );
    }

    buffer.writeln();

    // Class details
    buffer.writeln('## API Reference');
    buffer.writeln();

    for (final structure in allStructures) {
      final classes = structure['classes'] as List<dynamic>? ?? [];
      for (final cls in classes) {
        final classMap = cls as Map<String, dynamic>;
        final name = classMap['name'] as String;
        final methods = classMap['methods'] as List<dynamic>? ?? [];

        buffer.writeln('### $name');
        buffer.writeln();

        if (methods.isNotEmpty) {
          buffer.writeln('| Method | Parameters | Return Type |');
          buffer.writeln('|--------|-----------|-------------|');
          for (final m in methods) {
            final method = m as Map<String, dynamic>;
            final mName = method['name'] as String;
            final returnType = method['returnType'] as String? ?? 'void';
            final params = method['parameters'] as List<dynamic>? ?? [];
            final paramStr = params.isEmpty
                ? '—'
                : params
                    .map((p) =>
                        '`${(p as Map)['type']}` ${p['name']}')
                    .join(', ');
            buffer.writeln('| `$mName` | $paramStr | `$returnType` |');
          }
          buffer.writeln();
        }
      }
    }

    // Stats
    final totalClasses = allStructures.fold<int>(
      0,
      (sum, s) => sum + ((s['classes'] as List?)?.length ?? 0),
    );
    final totalFunctions = allStructures.fold<int>(
      0,
      (sum, s) => sum + ((s['topLevelFunctions'] as List?)?.length ?? 0),
    );

    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(
      '📊 **Stats:** ${allStructures.length} files, $totalClasses classes, $totalFunctions top-level functions',
    );

    return buffer.toString();
  }

  /// Returns a JSON summary for AI-based readme generation.
  static Future<String> generateStructureJson(List<String> files) async {
    final allStructures = <Map<String, dynamic>>[];

    for (final file in files) {
      Map<String, dynamic>? structure;
      if (file.endsWith('.dart')) {
        structure = await DartFileAnalyzer.analyze(file);
      } else if (file.endsWith('.kt')) {
        structure = await KotlinParser.analyze(file);
      }
      if (structure != null) allStructures.add(structure);
    }

    return const JsonEncoder.withIndent('  ').convert({
      'project': _detectProjectName(),
      'files': allStructures,
    });
  }

  static String _detectProjectName() {
    final pubspec = File('pubspec.yaml');
    if (pubspec.existsSync()) {
      final lines = pubspec.readAsLinesSync();
      for (final line in lines) {
        if (line.startsWith('name:')) {
          return line.split(':').last.trim();
        }
      }
    }
    return Directory.current.path.split(Platform.pathSeparator).last;
  }

  static String _shortenPath(String path) {
    // Remove current directory prefix
    final cwd = Directory.current.path;
    if (path.startsWith(cwd)) {
      return path.substring(cwd.length + 1);
    }
    return path;
  }
}
