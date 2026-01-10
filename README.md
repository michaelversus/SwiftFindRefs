<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.0-red.svg" />
    <img src="https://codecov.io/gh/michaelversus/SwiftFindRefs/graph/badge.svg?token=QZY0GAVROV"/>
</p>

# 🔎 SwiftFindRefs
A Swift Package Manager CLI that locates every file in your Xcode DerivedData index referencing a chosen symbol. It resolves the correct IndexStore path automatically, queries Apple’s IndexStoreDB, and prints a deduplicated list of source files.

## 🛠️ Installation
```bash
brew tap michaelversus/SwiftFindRefs https://github.com/michaelversus/SwiftFindRefs.git
brew install swiftfindrefs
```

## ⚙️ Command line flags
- `-p, --projectName` helps the tool infer the right DerivedData folder when you do not pass `derivedDataPath`.
- `-d, --derivedDataPath` points directly to a DerivedData (or IndexStoreDB) directory and skips discovery.
- `-n, --symbolName` is the symbol you want to inspect. This is required.
- `-t, --symbolType` narrows matches to a specific kind (e.g. `class`, `function`).
- `-v, --verbose` prints discovery steps, resolved paths, and finder diagnostics.

## 🚀 Usage
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

## 🧠 How it works
1. **Derived data resolution** – `DerivedDataLocator` uses the provided path or infers the newest `ProjectName-*` folder under `~/Library/Developer/Xcode/DerivedData`.
2. **Index routing** – `DerivedDataPaths` ensures the path points into `Index.noindex/DataStore/IndexStoreDB` so we can open the index without extra setup.
3. **Output formatting** – Paths are normalized, deduplicated, and printed once for easier scripting.

## 🧪 Testing
The package uses the Swift Testing framework (`swift test`) with mocks for filesystem and derived-data resolution. Tests cover locator edge cases, path building, and index error handling.

## 🤝 Contributions
Issues and pull requests are welcome. Please run `swift test` before submitting and include coverage for new behaviors.

## 🙏 Special Thanks
SwiftFindRefs relies on [MobileNativeFoundation/swift-index-store](https://github.com/MobileNativeFoundation/swift-index-store) for direct IndexStore access.

Swift, the Swift logo, and Xcode are trademarks of Apple Inc., registered in the U.S. and other countries.
