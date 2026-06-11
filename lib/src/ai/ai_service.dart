import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../utils/config.dart';
import 'prompts.dart';

abstract class AiService {
  Future<String?> generateDocumentation(Map<String, dynamic> structure);

  factory AiService.fromConfig(DocgenConfig config) {
    switch (config.provider) {
      case AiProvider.gemini:
        return GeminiService(
          apiKey: config.apiKey,
          model: config.model ?? 'gemini-2.0-flash',
        );
      case AiProvider.openai:
        return OpenAiCompatibleService(
          apiKey: config.apiKey,
          baseUrl: config.baseUrl ?? 'https://api.openai.com/v1',
          model: config.model ?? 'gpt-4o-mini',
        );
      case AiProvider.claude:
        return ClaudeService(
          apiKey: config.apiKey,
          model: config.model ?? 'claude-sonnet-4-20250514',
        );
      case AiProvider.ollama:
        return OpenAiCompatibleService(
          apiKey: '',
          baseUrl: config.baseUrl ?? 'http://localhost:11434/v1',
          model: config.model ?? 'llama3',
        );
    }
  }
}

class GeminiService implements AiService {
  final GenerativeModel _model;

  GeminiService({required String apiKey, required String model})
      : _model = GenerativeModel(model: model, apiKey: apiKey);

  @override
  Future<String?> generateDocumentation(Map<String, dynamic> structure) async {
    final structureJson = const JsonEncoder.withIndent('  ').convert(structure);
    final prompt = Prompts.generateDocumentation(structureJson);

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text;
    } on GenerativeAIException catch (e) {
      print('  ❌ Gemini error: ${e.message}');
      return null;
    } catch (e) {
      print('  ❌ Unexpected error: $e');
      return null;
    }
  }
}

/// Works with OpenAI, Ollama, and any OpenAI-compatible API.
class OpenAiCompatibleService implements AiService {
  final String apiKey;
  final String baseUrl;
  final String model;

  OpenAiCompatibleService({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  @override
  Future<String?> generateDocumentation(Map<String, dynamic> structure) async {
    final structureJson = const JsonEncoder.withIndent('  ').convert(structure);
    final prompt = Prompts.generateDocumentation(structureJson);

    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      if (!_isAllowedUrl(uri)) {
        print('  ❌ Invalid or disallowed base URL.');
        return null;
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      final request = await client.postUrl(uri);

      request.headers.set('Content-Type', 'application/json');
      if (apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }

      final body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
      });

      request.write(body);
      final response = await request.close().timeout(
            const Duration(seconds: 120),
          );
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        print('  ❌ API error (${response.statusCode})');
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      if (choices.isEmpty) return null;

      final message = choices[0]['message'] as Map<String, dynamic>;
      return message['content'] as String?;
    } catch (e) {
      print('  ❌ Request failed: ${e.runtimeType}');
      return null;
    }
  }

  static bool _isAllowedUrl(Uri uri) {
    final scheme = uri.scheme;
    if (scheme != 'http' && scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    // Block obvious internal network targets
    if (host == 'metadata.google.internal') return false;
    if (host == '169.254.169.254') return false;
    // Allow localhost for Ollama
    return true;
  }
}

class ClaudeService implements AiService {
  final String apiKey;
  final String model;

  ClaudeService({required this.apiKey, required this.model});

  @override
  Future<String?> generateDocumentation(Map<String, dynamic> structure) async {
    final structureJson = const JsonEncoder.withIndent('  ').convert(structure);
    final prompt = Prompts.generateDocumentation(structureJson);

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      final uri = Uri.parse('https://api.anthropic.com/v1/messages');
      final request = await client.postUrl(uri);

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('x-api-key', apiKey);
      request.headers.set('anthropic-version', '2023-06-01');

      final body = jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      });

      request.write(body);
      final response = await request.close().timeout(
            const Duration(seconds: 120),
          );
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        print('  ❌ Claude error (${response.statusCode})');
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = json['content'] as List<dynamic>;
      if (content.isEmpty) return null;

      return content[0]['text'] as String?;
    } catch (e) {
      print('  ❌ Request failed: ${e.runtimeType}');
      return null;
    }
  }
}
