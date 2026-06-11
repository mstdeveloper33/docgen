import 'dart:convert';
import 'dart:io';

enum AiProvider {
  gemini,
  openai,
  claude,
  ollama;

  static AiProvider fromString(String value) {
    return AiProvider.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AiProvider.gemini,
    );
  }
}

class DocgenConfig {
  final String apiKey;
  final AiProvider provider;
  final String? baseUrl; // For Ollama or custom endpoints
  final String? model; // Custom model override

  DocgenConfig({
    required this.apiKey,
    this.provider = AiProvider.gemini,
    this.baseUrl,
    this.model,
  });

  factory DocgenConfig.fromJson(Map<String, dynamic> json) {
    return DocgenConfig(
      apiKey: json['apiKey'] as String? ?? '',
      provider: AiProvider.fromString(json['provider'] as String? ?? 'gemini'),
      baseUrl: json['baseUrl'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'provider': provider.name,
      'apiKey': apiKey,
    };
    if (baseUrl != null) map['baseUrl'] = baseUrl;
    if (model != null) map['model'] = model;
    return map;
  }
}

class ConfigManager {
  static const _configFileName = '.docgen.json';

  static File get _configFile => File(_configFileName);

  static Future<void> save(DocgenConfig config) async {
    final encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(config.toJson());
    await _configFile.writeAsString(jsonString);
    // Restrict file permissions to owner-only (600)
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', _configFileName]);
    }
  }

  static Future<DocgenConfig?> load() async {
    if (!_configFile.existsSync()) return null;

    final content = await _configFile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return DocgenConfig.fromJson(json);
  }

  static bool get exists => _configFile.existsSync();
}
