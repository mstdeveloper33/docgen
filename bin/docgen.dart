import 'package:docgen/src/commands/run_command.dart';

const String version = '1.0.0';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    return;
  }

  final command = args.first;

  switch (command) {
    case 'init':
      await RunCommand.init();
    case 'run':
      final useAi = args.contains('--ai');
      await RunCommand.run(useAi: useAi);
    case '--version':
    case '-v':
      print('docgen v$version');
    case '--help':
    case '-h':
      _printUsage();
    default:
      print('❌ Unknown command: $command\n');
      _printUsage();
  }
}

void _printUsage() {
  print('''
📖 docgen - AI-powered documentation generator

Usage:
  docgen <command> [options]

Commands:
  init          Configure AI provider and API key
  run           Generate docs (local template)
  run --ai      Generate docs (with configured AI provider)

Supported Providers:
  Gemini, OpenAI, Claude, Ollama (local)

Options:
  -h, --help       Show help
  -v, --version    Show version
''');
}
