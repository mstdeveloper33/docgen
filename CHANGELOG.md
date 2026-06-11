## 1.1.0

- Add `--watch` mode: auto-regenerate docs on file save
- Add `--only` filter: process specific files/folders only
- Add `--exclude` option: skip specified paths
- Add `--format` option: output as markdown, html, or json
- Add `--diff` option: only process files changed since a git ref
- Add `docgen readme` command: generate full project README
- Add progress bar for projects with 10+ files
- Improved file scanning with filter support

## 1.0.0

- Initial release
- Dart AST analysis with `package:analyzer`
- Kotlin regex-based parser
- Local template documentation generation (no API key required)
- Gemini AI documentation generation (`--ai` flag)
- Git-aware file detection with full-scan fallback
- Native binary compilation support
