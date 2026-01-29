<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.0-red.svg" />
    <img src="https://codecov.io/gh/michaelversus/SwiftFindRefs/graph/badge.svg?token=QZY0GAVROV"/>
</p>

# 🔎 SwiftFindRefs
A Swift Package Manager CLI that helps you interact with Xcode's IndexStoreDB. It provides two main features:
- **Search**: Locates every file in your Xcode DerivedData index referencing a chosen symbol
- **RemoveUTI**: Automatically removes unnecessary `@testable import` statements from your test files

It resolves the correct IndexStore path automatically, queries Apple's IndexStoreDB, and uses Swift concurrency to scan multiple files in parallel, keeping operations fast even for large workspaces.

## 🚀 Common use cases 

### Finding symbol references
When working with multiple modules and moving models between them, finding all references to add missing imports is tedious. Using this CLI to feed file lists to AI agents dramatically improves refactoring results.
Just tell your AI agent to execute the script below and add missing import statements to all files
```bash
swiftfindrefs -p SomeProject -n SomeSymbolName -t SomeSymbolType | while read file; do
  if ! grep -q "import SomeModule" "$file"; then
    echo "$file"
  fi
done
```

### Cleaning up unnecessary testable imports
After refactoring code to make symbols public, you may have leftover `@testable import` statements in your test files that are no longer needed. This CLI can automatically detect and remove them, keeping your test files clean.
```bash
swiftfindrefs rmUTI -p SomeProject
```

## 🛠️ Installation
```bash
brew tap michaelversus/SwiftFindRefs https://github.com/michaelversus/SwiftFindRefs.git
brew install swiftfindrefs
```

## ⚙️ Command line options

### Common options (available for all subcommands)
- `-p, --projectName` helps the tool infer the right DerivedData folder when `dataStorePath` is not provided.
- `-d, --dataStorePath` points directly to a DataStore directory. When provided, this takes priority over `--projectName`.
- `-v, --verbose` enables verbose output for diagnostic purposes (flag, no value required).

### Search subcommand
- `-n, --symbolName` is the symbol you want to inspect. This is required.
- `-t, --symbolType` narrows matches to a specific kind (e.g. `class`, `function`).

### RemoveUTI subcommand (`removeUnnecessaryTestableImports` or `rmUTI`)
- `--excludeCompilationConditionals` excludes `@testable import` statements inside `#if/#elseif/#else/#endif` blocks from analysis (useful for multi-target apps).

## 🚀 Usage

### Search for symbol references
```bash
swiftfindrefs \
    --projectName MyApp \
    --symbolName SelectionViewController \
    --symbolType class
```
Sample output:
```
🔍 Searching for references to symbol 'SelectionViewController' of type 'class'
✅ Found 5 references:
/Users/me/MyApp/Sources/UI/SelectionViewController.swift
/Users/me/MyApp/Tests/SelectionViewControllerTests.swift
...
```

### Remove unnecessary @testable imports
```bash
swiftfindrefs removeUnnecessaryTestableImports \
    --projectName MyApp \
    --verbose \
    --excludeCompilationConditionals
```

Or use the shorter alias:
```bash
swiftfindrefs rmUTI \
    --projectName MyApp \
    --verbose \
    --excludeCompilationConditionals
```

Sample output:
```
DerivedData path: /Users/me/Library/Developer/Xcode/DerivedData/MyApp-...
IndexStoreDB path: /Users/me/Library/Developer/Xcode/DerivedData/MyApp-.../Index.noindex/DataStore/IndexStoreDB
Planning to remove unnecessary @testable imports from 3 files.
Removed unnecessary @testable imports from 3 files.
✅ Updated 3 files
Updated files:
/Users/me/MyApp/Tests/SomeTests.swift
/Users/me/MyApp/Tests/OtherTests.swift
...
```

## 🧠 How it works

### Search functionality
1. **Derived data resolution** – `DerivedDataLocator` uses the provided path or infers the newest `ProjectName-*` folder under `~/Library/Developer/Xcode/DerivedData`.
2. **Index routing** – `DerivedDataPaths` ensures the path points into `Index.noindex/DataStore/IndexStoreDB` so we can open the index without extra setup.
3. **Symbol querying** – Queries IndexStoreDB for all occurrences of the specified symbol, filtering by type if provided.
4. **Output formatting** – Paths are normalized, deduplicated, and printed once for easier scripting.

### Remove functionality
1. **Index analysis** – Scans all units in the IndexStoreDB to identify files with `@testable import` statements.
2. **Symbol analysis** – For each `@testable import`, checks if any referenced symbols from that module are actually public (and thus don't require `@testable`).
3. **File rewriting** – Removes unnecessary `@testable` imports from files, preserving other imports and code structure.
4. **Performance** – Uses async/await and parallel processing to handle large codebases efficiently. Files are read lazily only when needed, and units are indexed by module to avoid O(n²) scans.

## Agent Skill (OpenSkills)

This repository includes an OpenSkills-compatible agent skill located in `swiftfindrefs/`.
It teaches AI coding agents to use IndexStore-based reference discovery via `swiftfindrefs`
instead of unreliable text search.

### Install OpenSkills
```bash
npm i -g openskills
```

### Install this skill
```bash
openskills install michaelversus/SwiftFindRefs
```

### Sync into your project
```bash
openskills sync
```

### Example agent prompt
Use the swiftfindrefs skill to find all references to `SelectionViewController` (class) and add
`import UIComponents` only where missing.


## 🧪 Testing
The package uses the Swift Testing framework (`swift test`) with mocks for filesystem and derived-data resolution. Tests cover locator edge cases, path building, and index error handling.

## 🤝 Contributions
Issues and pull requests are welcome. Please run `swift test` before submitting and include coverage for new behaviors.

## 🙏 Special Thanks
SwiftFindRefs relies on [MobileNativeFoundation/swift-index-store](https://github.com/MobileNativeFoundation/swift-index-store) for direct IndexStore access.

Swift, the Swift logo, and Xcode are trademarks of Apple Inc., registered in the U.S. and other countries.
