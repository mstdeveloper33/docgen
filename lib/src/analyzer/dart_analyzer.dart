import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class DartFileAnalyzer {
  static Future<Map<String, dynamic>?> analyze(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final source = await file.readAsString();
    final parseResult = parseString(content: source);
    final unit = parseResult.unit;

    final visitor = _StructureVisitor();
    unit.accept(visitor);

    if (visitor.classes.isEmpty && visitor.topLevelFunctions.isEmpty) {
      return null;
    }

    return {
      'file': filePath,
      'classes': visitor.classes,
      'topLevelFunctions': visitor.topLevelFunctions,
    };
  }
}

class _StructureVisitor extends RecursiveAstVisitor<void> {
  final List<Map<String, dynamic>> classes = [];
  final List<Map<String, dynamic>> topLevelFunctions = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.typeName.lexeme;
    if (className.startsWith('_')) return;

    final constructors = <Map<String, dynamic>>[];
    final methods = <Map<String, dynamic>>[];

    for (final member in node.body.members) {
      if (member is ConstructorDeclaration) {
        final name = member.name?.lexeme ?? className;
        if (name.startsWith('_')) continue;

        constructors.add({
          'name': name,
          'parameters': _extractParameters(member.parameters),
        });
      } else if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        if (methodName.startsWith('_')) continue;

        methods.add({
          'name': methodName,
          'returnType': member.returnType?.toSource() ?? 'void',
          'parameters': _extractParameters(member.parameters),
        });
      }
    }

    classes.add({
      'name': className,
      'constructors': constructors,
      'methods': methods,
    });

    // Don't recurse into nested classes
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final name = node.name.lexeme;
    if (name.startsWith('_')) return;

    topLevelFunctions.add({
      'name': name,
      'returnType': node.returnType?.toSource() ?? 'void',
      'parameters': _extractParameters(
        node.functionExpression.parameters,
      ),
    });
  }

  List<Map<String, String>> _extractParameters(
    FormalParameterList? parameterList,
  ) {
    if (parameterList == null) return [];

    final params = <Map<String, String>>[];
    for (final param in parameterList.parameters) {
      final paramName = param.name?.lexeme ?? '';
      String paramType = 'dynamic';

      if (param is SimpleFormalParameter && param.type != null) {
        paramType = param.type!.toSource();
      } else if (param is DefaultFormalParameter) {
        final innerParam = param.parameter;
        if (innerParam is SimpleFormalParameter && innerParam.type != null) {
          paramType = innerParam.type!.toSource();
        }
      } else if (param is FieldFormalParameter) {
        paramType = param.type?.toSource() ?? 'dynamic';
      }

      params.add({'name': paramName, 'type': paramType});
    }

    return params;
  }
}
