import 'dart:io';

/// Simple progress indicator for CLI output.
class ProgressBar {
  final int total;
  int _current = 0;

  ProgressBar({required this.total});

  void increment(String label) {
    _current++;
    final percent = ((_current / total) * 100).round();
    final filled = (percent / 5).round();
    final empty = 20 - filled;
    final bar = '${'█' * filled}${'░' * empty}';
    stdout.write('\r  [$bar] $percent% ($_current/$total) $label');
    if (_current == total) stdout.write('\n');
  }
}
