import 'dart:io';

class KotlinParser {
  static final _classPattern = RegExp(
    r'(?:public\s+|open\s+|data\s+|sealed\s+|abstract\s+)*class\s+(\w+)',
  );

  static final _functionPattern = RegExp(
    r'(?:public\s+|open\s+|override\s+)*fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*(\S+))?',
  );

  static final _paramPattern = RegExp(
    r'(\w+)\s*:\s*([\w<>,\s\?]+)',
  );

  static Future<Map<String, dynamic>?> analyze(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final source = await file.readAsString();
    final lines = source.split('\n');

    final classes = <Map<String, dynamic>>[];
    final topLevelFunctions = <Map<String, dynamic>>[];

    String? currentClass;
    List<Map<String, dynamic>> currentMethods = [];
    int braceDepth = 0;
    bool insideClass = false;

    for (final line in lines) {
      final trimmed = line.trim();

      // Skip private or internal
      if (trimmed.startsWith('private ') || trimmed.startsWith('internal ')) {
        continue;
      }

      // Detect class declarations
      final classMatch = _classPattern.firstMatch(trimmed);
      if (classMatch != null && !insideClass) {
        currentClass = classMatch.group(1);
        currentMethods = [];
        insideClass = true;
        braceDepth = 0;
      }

      // Track brace depth for class scope
      if (insideClass) {
        braceDepth += '{'.allMatches(trimmed).length;
        braceDepth -= '}'.allMatches(trimmed).length;

        if (braceDepth <= 0 && currentClass != null) {
          classes.add({
            'name': currentClass,
            'constructors': <Map<String, dynamic>>[],
            'methods': currentMethods,
          });
          currentClass = null;
          insideClass = false;
          continue;
        }
      }

      // Detect function declarations
      final funcMatch = _functionPattern.firstMatch(trimmed);
      if (funcMatch != null) {
        final funcName = funcMatch.group(1)!;
        final paramsRaw = funcMatch.group(2) ?? '';
        final returnType = funcMatch.group(3) ?? 'Unit';

        final parameters = _parseParameters(paramsRaw);

        final funcData = {
          'name': funcName,
          'returnType': returnType,
          'parameters': parameters,
        };

        if (insideClass) {
          currentMethods.add(funcData);
        } else {
          topLevelFunctions.add(funcData);
        }
      }
    }

    // Handle class without closing brace on separate line
    if (currentClass != null) {
      classes.add({
        'name': currentClass,
        'constructors': <Map<String, dynamic>>[],
        'methods': currentMethods,
      });
    }

    if (classes.isEmpty && topLevelFunctions.isEmpty) return null;

    return {
      'file': filePath,
      'classes': classes,
      'topLevelFunctions': topLevelFunctions,
    };
  }

  static List<Map<String, String>> _parseParameters(String raw) {
    if (raw.trim().isEmpty) return [];

    final params = <Map<String, String>>[];
    final matches = _paramPattern.allMatches(raw);

    for (final match in matches) {
      params.add({
        'name': match.group(1)!.trim(),
        'type': match.group(2)!.trim(),
      });
    }

    return params;
  }
}
