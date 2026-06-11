import 'dart:async';
import 'dart:io';

/// Watches for file changes and triggers a callback.
class FileWatcher {
  final List<String> watchPaths;
  final Set<String> extensions;
  final Set<String> excludeDirs;

  FileWatcher({
    required this.watchPaths,
    this.extensions = const {'.dart', '.kt'},
    this.excludeDirs = const {
      '.dart_tool', '.git', '.idea', '.vscode',
      'build', 'node_modules',
    },
  });

  /// Watches for file system changes and calls [onChanged] with the changed file path.
  Future<void> watch(Future<void> Function(String filePath) onChanged) async {
    print('👀 Watching for file changes... (Ctrl+C to stop)\n');

    final watchers = <StreamSubscription<FileSystemEvent>>[];

    for (final path in watchPaths) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;

      final watcher = dir.watch(recursive: true).listen((event) {
        if (event is FileSystemModifyEvent || event is FileSystemCreateEvent) {
          final filePath = event.path;

          // Check extension
          if (!extensions.any((ext) => filePath.endsWith(ext))) return;

          // Check excluded dirs
          final segments = filePath.split(Platform.pathSeparator);
          if (segments.any((s) => excludeDirs.contains(s))) return;

          onChanged(filePath);
        }
      });

      watchers.add(watcher);
    }

    // Keep alive until process killed
    await ProcessSignal.sigint.watch().first;

    for (final w in watchers) {
      await w.cancel();
    }
    print('\n👋 Stopped watching.');
  }
}
