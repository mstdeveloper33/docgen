import 'dart:io';

import 'package:path/path.dart' as p;

/// Analyzes import statements to build a dependency graph between files.
class CrossReferenceAnalyzer {
  /// Returns a map of file -> list of files it imports (within project).
  static Future<Map<String, List<String>>> buildDependencyGraph(
    List<String> files,
  ) async {
    final graph = <String, List<String>>{};
    final projectFiles = files.map((f) => p.basename(f)).toSet();

    for (final filePath in files) {
      final file = File(filePath);
      if (!file.existsSync()) continue;

      final imports = <String>[];
      final lines = await file.readAsLines();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('import ') && !trimmed.contains('dart:')) {
          final match = RegExp(r"import\s+'([^']+)'").firstMatch(trimmed);
          if (match != null) {
            final importPath = match.group(1)!;
            final importFile = p.basename(importPath);
            // Only track internal project imports
            if (projectFiles.contains(importFile)) {
              imports.add(importFile);
            }
          }
        }
      }

      graph[p.basename(filePath)] = imports;
    }

    return graph;
  }

  /// Generates a Mermaid diagram string from the dependency graph.
  static String generateMermaidDiagram(Map<String, List<String>> graph) {
    final buffer = StringBuffer();
    buffer.writeln('```mermaid');
    buffer.writeln('graph TD');

    final nodeIds = <String, String>{};
    var counter = 0;

    String nodeId(String name) {
      return nodeIds.putIfAbsent(name, () => 'N${counter++}');
    }

    for (final entry in graph.entries) {
      final from = entry.key;
      final fromId = nodeId(from);
      final label = from.replaceAll('.dart', '').replaceAll('.kt', '');

      buffer.writeln('    $fromId["$label"]');

      for (final to in entry.value) {
        final toId = nodeId(to);
        final toLabel = to.replaceAll('.dart', '').replaceAll('.kt', '');
        buffer.writeln('    $toId["$toLabel"]');
        buffer.writeln('    $fromId --> $toId');
      }
    }

    buffer.writeln('```');
    return buffer.toString();
  }

  /// Generates a markdown section with dependency info for a specific file.
  static String generateDependencySection(
    String fileName,
    Map<String, List<String>> graph,
  ) {
    final buffer = StringBuffer();
    final baseName = p.basename(fileName);

    // What this file depends on
    final deps = graph[baseName] ?? [];
    // What depends on this file
    final dependents = graph.entries
        .where((e) => e.value.contains(baseName))
        .map((e) => e.key)
        .toList();

    if (deps.isEmpty && dependents.isEmpty) return '';

    buffer.writeln('### Dependencies');
    buffer.writeln();

    if (deps.isNotEmpty) {
      buffer.writeln('**Uses:** ${deps.map((d) => '`$d`').join(', ')}');
    }
    if (dependents.isNotEmpty) {
      buffer.writeln(
        '**Used by:** ${dependents.map((d) => '`$d`').join(', ')}',
      );
    }

    buffer.writeln();
    return buffer.toString();
  }
}
