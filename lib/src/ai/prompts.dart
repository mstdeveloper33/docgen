class Prompts {
  static String generateDocumentation(String structureJson) {
    return '''
You are a senior technical documentation writer specializing in mobile and backend development.

## TASK
Analyze the following class/function structure JSON. Your job is to generate a professional, production-ready Markdown documentation file.

## INSTRUCTIONS
1. Deduce the architectural pattern this code follows (e.g., BLoC, Repository, UseCase, ViewModel, Service, Controller, Provider, Widget).
2. Write a concise "Overview" section explaining WHY this class/module exists and what problem it solves.
3. Generate a clean Markdown table documenting each public method with columns: Method | Parameters | Return Type | Description.
4. Provide a complete, realistic, production-ready code snippet example showing how a developer should use this class in a real project.
5. If the structure has multiple classes, document each one in its own section.

## RULES
- Output RAW Markdown only. No conversational text, no intro, no outro.
- Do NOT wrap the output in a markdown code fence.
- Use proper heading hierarchy (# for title, ## for sections, ### for sub-sections).
- Method descriptions should be inferred from naming conventions and parameter types.
- Code examples must be syntactically correct and follow idiomatic patterns.
- Be concise but thorough.

## STRUCTURE JSON
```json
$structureJson
```
''';
  }
}
