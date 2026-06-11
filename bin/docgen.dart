import 'package:docgen_cli/src/commands/run_command.dart';
import 'package:docgen_cli/src/utils/file_handler.dart';

const String version = '1.1.0';

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
      final options = _parseRunOptions(args);
      await RunCommand.run(options);
    case 'readme':
      final useAi = args.contains('--ai');
      await RunCommand.readme(useAi: useAi);
    case 'graph':
      await RunCommand.graph();
    case 'setup-ci':
      await RunCommand.setupCi();
    case 'template':
      await RunCommand.createTemplate();
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

RunOptions _parseRunOptions(List<String> args) {
  final useAi = args.contains('--ai');
  final watch = args.contains('--watch');

  // --only lib/src/auth/
  String? only;
  final onlyIndex = args.indexOf('--only');
  if (onlyIndex != -1 && onlyIndex + 1 < args.length) {
    only = args[onlyIndex + 1];
  }

  // --exclude test/,generated/
  List<String> exclude = [];
  final excludeIndex = args.indexOf('--exclude');
  if (excludeIndex != -1 && excludeIndex + 1 < args.length) {
    exclude = args[excludeIndex + 1].split(',');
  }

  // --format markdown|html|json
  OutputFormat format = OutputFormat.markdown;
  final formatIndex = args.indexOf('--format');
  if (formatIndex != -1 && formatIndex + 1 < args.length) {
    final formatStr = args[formatIndex + 1].toLowerCase();
    format = switch (formatStr) {
      'html' => OutputFormat.html,
      'json' => OutputFormat.json,
      _ => OutputFormat.markdown,
    };
  }

  // --diff HEAD~3
  String? diffRef;
  final diffIndex = args.indexOf('--diff');
  if (diffIndex != -1 && diffIndex + 1 < args.length) {
    diffRef = args[diffIndex + 1];
  }

  // --version v1.2.0 (versioned docs)
  String? version;
  final versionIndex = args.indexOf('--tag');
  if (versionIndex != -1 && versionIndex + 1 < args.length) {
    version = args[versionIndex + 1];
  }

  return RunOptions(
    useAi: useAi,
    watch: watch,
    only: only,
    exclude: exclude,
    format: format,
    diffRef: diffRef,
    version: version,
  );
}

void _printUsage() {
  print('''
📖 docgen - AI-powered documentation generator

Usage:
  docgen <command> [options]

Commands:
  init                  Configure AI provider and API key
  run                   Generate docs (local template)
  run --ai             Generate docs with AI
  readme               Generate project README
  readme --ai          Generate README with AI
  graph                Generate dependency graph (Mermaid)
  setup-ci             Install GitHub Actions workflows
  template             Create customizable doc template

Run Options:
  --ai                 Use configured AI provider
  --watch              Watch for file changes and auto-regenerate
  --only <path>        Only process files matching path
  --exclude <paths>    Exclude paths (comma-separated)
  --format <type>      Output format: markdown, html, json
  --diff <ref>         Only process files changed since git ref
  --tag <version>      Save docs under docs/<version>/

Supported Providers:
  Gemini, OpenAI, Claude, Ollama (local)

Examples:
  docgen run                              # Local docs for all files
  docgen run --ai --only lib/src/         # AI docs for lib/src only
  docgen run --format html                # HTML output
  docgen run --watch                      # Auto-regenerate on save
  docgen run --diff HEAD~5                # Only last 5 commits' changes
  docgen run --exclude test/,generated/   # Skip folders
  docgen run --tag v1.2.0                 # Versioned docs
  docgen graph                            # Dependency diagram
  docgen setup-ci                         # Install CI/CD workflows
  docgen readme --ai                      # Full project README with AI

Options:
  -h, --help       Show help
  -v, --version    Show version
''');
}
