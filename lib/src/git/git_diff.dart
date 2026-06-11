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

  static Future<List<String>> getTargetFiles() async {
    final changedFiles = await _getGitChangedFiles();
    if (changedFiles != null && changedFiles.isNotEmpty) {
      return changedFiles;
    }

    // Fallback: scan entire directory
    return _scanDirectory(Directory.current);
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
