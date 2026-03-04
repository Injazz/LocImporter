# LocImporter

A Swift CLI tool built mainly to replace occurencies of string references to direct struct usage - defined in a single swift package. What i personally use this tool for is redefining l10n string defined all around various packages to point to a single struct defined in one package. Built with SwiftSyntax for accurate AST-based code transformation.

## Example

Migrates code like this:

```swift
// Before
import UIKit

class ProfileViewController {
    let title = ProfileStrings.screenTitle // Defined somewhere in this package
    let message = "ProfileStrings in a string" 
}
```

To this:

```swift
// After
import L10n //the tool imports specified package
import UIKit

class ProfileViewController {
    let title = Texts.screenTitle // Now defined in L10n package
    let message = "ProfileStrings in a string" 
}
```

## Features

- **AST-based parsing** — Uses SwiftSyntax to accurately identify type references
- **Preserves string literals** — Text inside `"..."` is never modified
- **Preserves comments** — Single-line and multi-line comments are untouched
- **Handles edge cases** — Dictionary keys, multiline strings, nested quotes, type contexts
- **Dry run mode** — Preview changes before applying
- **Configurable** — Custom target struct and package names
- **Optional cleanup** — Delete typealias declaration files after migration

## Building from source

```bash
git clone <repo-url>
cd LocImporter
swift build -c release
strip .build/release/loc-importer
```

## CLI usage examples

### Basic

```bash
loc-importer --path /path/to/project
```

### Dry Run (Preview Changes)

```bash
loc-importer --path /path/to/project --dry-run --verbose
```

### Migrate and Delete Typealias Files

```bash
loc-importer --path /path/to/project --delete-typealiases
```

### Generate Report

```bash
loc-importer --path /path/to/project --report migration-report.md
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--path` | (required) | Directory to scan for Swift files |
| `--target` | `LocalizedTexts` | Target struct name to replace with |
| `--package-name` | `L10n` | Package name for import statement |
| `--dry-run` | `false` | Preview changes without modifying files |
| `--delete-typealiases` | `false` | Delete typealias declaration files after migration |
| `--report` | (none) | Path to write a markdown report |
| `--verbose` | `false` | Show detailed output including diffs |

### Run Tests

```bash
swift test
```

### Run Specific Test

```bash
swift test --filter testMigrateFile_ReplacesTypeReferences
```

## Requirements

- Swift 5.9+
- macOS 13+

## Dependencies

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) — CLI argument handling
- [swift-syntax](https://github.com/apple/swift-syntax) — Swift AST parsing

## License

MIT
