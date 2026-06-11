import 'dart:io';

import '../ai/ai_service.dart';
import '../analyzer/dart_analyzer.dart';
import '../analyzer/kotlin_parser.dart';
import '../generator/local_generator.dart';
import '../git/git_diff.dart';
import '../utils/config.dart';
import '../utils/file_handler.dart';

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

  static Future<void> run({bool useAi = false}) async {
    final mode = useAi ? 'AI' : 'Local';
    print('📖 docgen run [$mode] - Generating documentation...\n');

    // 1. Load config if AI mode
    AiService? aiService;
    if (useAi) {
      final config = await ConfigManager.load();
      if (config == null) {
        print('❌ Config not found. Run "docgen init" first.');
        return;
      }
      aiService = AiService.fromConfig(config);
      print('   Provider: ${config.provider.name}');
      print('   Model: ${config.model ?? 'default'}\n');
    }

    // 2. Find target files
    print('🔍 Scanning for target files...');
    final files = await GitWatcher.getTargetFiles();

    if (files.isEmpty) {
      print('⚠️  No .dart or .kt files found to process.');
      return;
    }

    print('📂 Found ${files.length} file(s).\n');

    int successCount = 0;
    int skipCount = 0;

    // 3. Process each file
    for (final filePath in files) {
      final fileName = filePath.split(Platform.pathSeparator).last;
      print('📄 Processing: $fileName');

      // 3a. Analyze
      Map<String, dynamic>? structure;

      if (filePath.endsWith('.dart')) {
        print('  🔬 Running Dart AST analysis...');
        structure = await DartFileAnalyzer.analyze(filePath);
      } else if (filePath.endsWith('.kt')) {
        print('  🔬 Running Kotlin structure analysis...');
        structure = await KotlinParser.analyze(filePath);
      }

      if (structure == null) {
        print('  ⏭️  No structure found, skipping.\n');
        skipCount++;
        continue;
      }

      // 3b. Generate documentation
      String? markdown;

      if (useAi && aiService != null) {
        print('  🤖 Generating docs with AI...');
        markdown = await aiService.generateDocumentation(structure);
      } else {
        print('  📝 Generating docs with local template...');
        markdown = LocalGenerator.generate(structure);
      }

      if (markdown == null || markdown.isEmpty) {
        print('  ⏭️  Could not generate docs, skipping.\n');
        skipCount++;
        continue;
      }

      // 3c. Write output
      final outputPath = await FileHandler.writeDocumentation(
        sourceFilePath: filePath,
        markdownContent: markdown,
      );

      print('  ✅ Saved: $outputPath\n');
      successCount++;
    }

    // 4. Summary
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 Summary: $successCount succeeded, $skipCount skipped');
    print('📁 Output folder: docs/');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
