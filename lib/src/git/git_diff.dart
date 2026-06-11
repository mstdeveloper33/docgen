import 'dart:io';

class GitWatcher {
  static const _ignoredDirs = {
    '.dart_tool',
    '.git',
    '.idea',
    '.vscode',
    'build',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
    'node_modules',
  };

  static Future<List<String>> getTargetFiles({
    String? only,
    List<String> exclude = const [],
    String? diffRef,
  }) async {
    List<String>? files;

    if (diffRef != null) {
      files = await _getGitDiffFiles(diffRef);
    } else {
      files = await _getGitChangedFiles();
    }

    if (files != null && files.isNotEmpty) {
      return _applyFilters(files, only: only, exclude: exclude);
    }

    // Fallback: scan entire directory
    final scanned = _scanDirectory(Directory.current);
    return _applyFilters(scanned, only: only, exclude: exclude);
  }

  static List<String> _applyFilters(
    List<String> files, {
    String? only,
    List<String> exclude = const [],
  }) {
    var result = files;

    if (only != null && only.isNotEmpty) {
      result = result.where((f) => f.contains(only)).toList();
    }

    if (exclude.isNotEmpty) {
      result = result.where((f) {
        return !exclude.any((ex) => f.contains(ex));
      }).toList();
    }

    return result;
  }

  static Future<List<String>?> _getGitDiffFiles(String ref) async {
    try {
      final result = await Process.run(
        'git',
        ['diff', '--name-only', ref],
      );
      if (result.exitCode != 0) return null;

      final output = result.stdout as String;
      if (output.trim().isEmpty) return null;

      final files = <String>[];
      for (final line in output.split('\n')) {
        final filePath = line.trim();
        if (filePath.isNotEmpty && _isSupportedFile(filePath)) {
          files.add(filePath);
        }
      }

      return files.isEmpty ? null : files;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>?> _getGitChangedFiles() async {
    try {
      final result = await Process.run('git', ['status', '--porcelain']);
      if (result.exitCode != 0) return null;

      final output = result.stdout as String;
      if (output.trim().isEmpty) return null;

      final files = <String>[];
      for (final line in output.split('\n')) {
        if (line.length < 4) continue;
        final filePath = line.substring(3).trim();
        if (_isSupportedFile(filePath)) {
          files.add(filePath);
        }
      }

      return files.isEmpty ? null : files;
    } catch (_) {
      return null;
    }
  }

  static List<String> _scanDirectory(Directory dir) {
    final files = <String>[];

    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path;

        // Skip ignored directories
        final segments = path.split(Platform.pathSeparator);
        if (segments.any((s) => _ignoredDirs.contains(s))) continue;

        if (_isSupportedFile(path)) {
          files.add(path);
        }
      }
    }

    return files;
  }

  static bool _isSupportedFile(String path) {
    return path.endsWith('.dart') || path.endsWith('.kt');
  }
}
