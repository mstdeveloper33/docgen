import 'dart:io';

import '../ai/ai_service.dart';
import '../analyzer/dart_analyzer.dart';
import '../analyzer/kotlin_parser.dart';
import '../generator/local_generator.dart';
import '../generator/readme_generator.dart';
import '../git/git_diff.dart';
import '../utils/config.dart';
import '../utils/file_handler.dart';
import '../utils/file_watcher.dart';
import '../utils/progress.dart';

class RunOptions {
  final bool useAi;
  final bool watch;
  final String? only;
  final List<String> exclude;
  final OutputFormat format;
  final String? diffRef;

  RunOptions({
    this.useAi = false,
    this.watch = false,
    this.only,
    this.exclude = const [],
    this.format = OutputFormat.markdown,
    this.diffRef,
  });
}

class RunCommand {
  static Future<void> init() async {
    print('🔧 docgen init - Setting up configuration...\n');

    if (ConfigManager.exists) {
      print('⚠️  .docgen.json already exists. Overwrite? (y/n)');
      final answer = stdin.readLineSync()?.trim().toLowerCase();
      if (answer != 'y') {
        print('❌ Cancelled.');
        return;
      }
    }

    // Provider selection
    print('📡 Select AI provider:');
    print('  1) Gemini (Google)');
    print('  2) OpenAI (GPT)');
    print('  3) Claude (Anthropic)');
    print('  4) Ollama (Local LLM)');
    print('');
    stdout.write('Choice [1-4]: ');
    final choice = stdin.readLineSync()?.trim() ?? '1';

    final provider = switch (choice) {
      '2' => AiProvider.openai,
      '3' => AiProvider.claude,
      '4' => AiProvider.ollama,
      _ => AiProvider.gemini,
    };

    // API key (not needed for Ollama)
    String apiKey = '';
    if (provider != AiProvider.ollama) {
      print('\n🔑 Enter your ${provider.name} API key:');
      apiKey = stdin.readLineSync()?.trim() ?? '';

      if (apiKey.isEmpty) {
        print('❌ API key cannot be empty.');
        return;
      }
    }

    // Base URL for Ollama or custom endpoints
    String? baseUrl;
    if (provider == AiProvider.ollama) {
      print('\n🌐 Ollama base URL [http://localhost:11434/v1]:');
      final input = stdin.readLineSync()?.trim();
      if (input != null && input.isNotEmpty) baseUrl = input;
    }

    // Optional model override
    final defaultModel = switch (provider) {
      AiProvider.gemini => 'gemini-2.0-flash',
      AiProvider.openai => 'gpt-4o-mini',
      AiProvider.claude => 'claude-sonnet-4-20250514',
      AiProvider.ollama => 'llama3',
    };

    print('\n🤖 Model [$defaultModel]:');
    final modelInput = stdin.readLineSync()?.trim();
    final model = (modelInput != null && modelInput.isNotEmpty)
        ? modelInput
        : null;

    final config = DocgenConfig(
      apiKey: apiKey,
      provider: provider,
      baseUrl: baseUrl,
      model: model,
    );
    await ConfigManager.save(config);

    print('\n✅ Configuration saved to .docgen.json');
    print('   Provider: ${provider.name}');
    print('   Model: ${model ?? defaultModel}');
    print('🚀 You can now use "docgen run --ai"\n');
  }

  static Future<void> run(RunOptions options) async {
    if (options.watch) {
      await _runWatch(options);
      return;
    }

    await _runOnce(options);
  }

  static Future<void> readme({bool useAi = false}) async {
    print('📖 docgen readme - Generating project README...\n');

    print('🔍 Scanning all project files...');
    final files = await GitWatcher.getTargetFiles();

    if (files.isEmpty) {
      print('⚠️  No .dart or .kt files found.');
      return;
    }

    print('📂 Found ${files.length} file(s).\n');

    String content;

    if (useAi) {
      final config = await ConfigManager.load();
      if (config == null) {
        print('❌ Config not found. Run "docgen init" first.');
        return;
      }
      final aiService = AiService.fromConfig(config);
      print('🤖 Generating README with AI (${config.provider.name})...');

      final structureJson = await ReadmeGenerator.generateStructureJson(files);
      final prompt = '''
You are a technical writer. Generate a professional README.md for this project.
Include: project name, description, architecture overview, installation,
usage examples, and API reference.
Output RAW markdown only.

Project structure:
$structureJson
''';
      // Use AI service directly with custom prompt
      final result = await aiService.generateDocumentation(
        {'_raw_prompt': prompt},
      );
      content = result ?? await ReadmeGenerator.generate(files);
    } else {
      print('📝 Generating README with local template...');
      content = await ReadmeGenerator.generate(files);
    }

    if (content.isEmpty) {
      print('⚠️  Could not generate README.');
      return;
    }

    final file = File('README_GENERATED.md');
    await file.writeAsString(content);
    print('\n✅ Saved: README_GENERATED.md');
  }

  static Future<void> _runOnce(RunOptions options) async {
    final mode = options.useAi ? 'AI' : 'Local';
    print('📖 docgen run [$mode] - Generating documentation...\n');

    // 1. Load config if AI mode
    AiService? aiService;
    if (options.useAi) {
      final config = await ConfigManager.load();
      if (config == null) {
        print('❌ Config not found. Run "docgen init" first.');
        return;
      }
      aiService = AiService.fromConfig(config);
      print('   Provider: ${config.provider.name}');
      print('   Model: ${config.model ?? 'default'}');
      print('   Format: ${options.format.name}\n');
    }

    // 2. Find target files
    print('🔍 Scanning for target files...');
    final files = await GitWatcher.getTargetFiles(
      only: options.only,
      exclude: options.exclude,
      diffRef: options.diffRef,
    );

    if (files.isEmpty) {
      print('⚠️  No .dart or .kt files found to process.');
      return;
    }

    print('📂 Found ${files.length} file(s).\n');

    int successCount = 0;
    int skipCount = 0;

    // 3. Progress bar for 10+ files
    final useProgress = files.length >= 10;
    ProgressBar? progress;
    if (useProgress) {
      progress = ProgressBar(total: files.length);
    }

    // 4. Process each file
    for (final filePath in files) {
      final fileName = filePath.split(Platform.pathSeparator).last;

      if (useProgress) {
        progress!.increment(fileName);
      } else {
        print('📄 Processing: $fileName');
      }

      // 4a. Analyze
      final structure = await _analyzeFile(filePath, verbose: !useProgress);

      if (structure == null) {
        if (!useProgress) print('  ⏭️  No structure found, skipping.\n');
        skipCount++;
        continue;
      }

      // 4b. Generate documentation
      String? markdown;

      if (options.useAi && aiService != null) {
        if (!useProgress) print('  🤖 Generating docs with AI...');
        markdown = await aiService.generateDocumentation(structure);
      } else {
        if (!useProgress) print('  📝 Generating docs with local template...');
        markdown = LocalGenerator.generate(structure);
      }

      if (markdown == null || markdown.isEmpty) {
        if (!useProgress) print('  ⏭️  Could not generate docs, skipping.\n');
        skipCount++;
        continue;
      }

      // 4c. Write output
      final outputPath = await FileHandler.writeDocumentation(
        sourceFilePath: filePath,
        markdownContent: markdown,
        format: options.format,
      );

      if (!useProgress) print('  ✅ Saved: $outputPath\n');
      successCount++;
    }

    // 5. Summary
    if (useProgress) print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 Summary: $successCount succeeded, $skipCount skipped');
    print('📁 Output folder: docs/');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  static Future<void> _runWatch(RunOptions options) async {
    // First, run once
    await _runOnce(options);

    print('\n👀 Watching for file changes... (Ctrl+C to stop)\n');

    final watcher = FileWatcher(watchPaths: [Directory.current.path]);
    await watcher.watch((filePath) async {
      final fileName = filePath.split(Platform.pathSeparator).last;
      print('🔄 Changed: $fileName');

      final structure = await _analyzeFile(filePath, verbose: false);
      if (structure == null) return;

      String? markdown;
      if (options.useAi) {
        final config = await ConfigManager.load();
        if (config != null) {
          final aiService = AiService.fromConfig(config);
          markdown = await aiService.generateDocumentation(structure);
        }
      }
      markdown ??= LocalGenerator.generate(structure);

      if (markdown.isNotEmpty) {
        final outputPath = await FileHandler.writeDocumentation(
          sourceFilePath: filePath,
          markdownContent: markdown,
          format: options.format,
        );
        print('  ✅ Updated: $outputPath');
      }
    });
  }

  static Future<Map<String, dynamic>?> _analyzeFile(
    String filePath, {
    bool verbose = true,
  }) async {
    if (filePath.endsWith('.dart')) {
      if (verbose) print('  🔬 Running Dart AST analysis...');
      return DartFileAnalyzer.analyze(filePath);
    } else if (filePath.endsWith('.kt')) {
      if (verbose) print('  🔬 Running Kotlin structure analysis...');
      return KotlinParser.analyze(filePath);
    }
    return null;
  }
}
