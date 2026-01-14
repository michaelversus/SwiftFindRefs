# Swift Concurrency Analysis & Improvement Recommendations

## Project Context

- **Swift Version**: 6.2 (from `Package.swift`)
- **Current Concurrency Model**: GCD (`DispatchQueue.concurrentPerform`) with manual locking (`NSLock`)
- **Target Platform**: macOS 15+

## Current State Analysis

### Issues Identified

1. **Legacy GCD Pattern** (`IndexStoreFinder.swift:30`)
   - Uses `DispatchQueue.concurrentPerform` instead of structured concurrency
   - No cancellation support
   - No error propagation from parallel work
   - Harder to reason about and test

2. **Manual Locking Pattern** (`IndexStoreFinder.swift:62-78`)
   - `ThreadSafeSet` uses `NSLock` with `@unchecked Sendable`
   - Manual lock management is error-prone
   - No compile-time safety guarantees
   - Requires careful documentation of safety invariants

3. **No Async/Await Adoption**
   - All APIs are synchronous despite performing parallel work
   - Missing benefits of structured concurrency (cancellation, error handling, task hierarchy)

## Recommended Improvements

### Priority 1: Replace `DispatchQueue.concurrentPerform` with Task Groups

**Current Code:**
```swift
private func searchRecordsInParallel(
    store: some IndexStoreProviding & Sendable,
    index: RecordIndex,
    query: SymbolQuery
) -> [String] {
    let referencedFiles = ThreadSafeSet<String>()
    
    DispatchQueue.concurrentPerform(iterations: index.recordNames.count) { i in
        let recordName = index.recordNames[i]
        if recordContainsSymbol(store: store, recordName: recordName, query: query) {
            let filename = index.sourcePath(for: recordName)
            referencedFiles.insert(filename)
        }
    }
    
    return referencedFiles.values().sorted()
}
```

**Recommended Improvement:**
```swift
private func searchRecordsInParallel(
    store: some IndexStoreProviding & Sendable,
    index: RecordIndex,
    query: SymbolQuery
) async -> [String] {
    await withTaskGroup(of: String?.self) { group in
        for recordName in index.recordNames {
            group.addTask {
                guard recordContainsSymbol(store: store, recordName: recordName, query: query) else {
                    return nil
                }
                return index.sourcePath(for: recordName)
            }
        }
        
        var referencedFiles = Set<String>()
        for await filename in group {
            if let filename = filename {
                referencedFiles.insert(filename)
            }
        }
        
        return Array(referencedFiles).sorted()
    }
}
```

**Benefits:**
- ✅ Structured concurrency with automatic cancellation
- ✅ Better error handling capabilities
- ✅ No manual synchronization needed
- ✅ Compile-time safety
- ✅ Can be extended with cancellation support

### Priority 2: Replace `ThreadSafeSet` with an Actor

**Current Code:**
```swift
private final class ThreadSafeSet<Element: Hashable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Set<Element>()
    
    func insert(_ element: Element) {
        lock.lock()
        storage.insert(element)
        lock.unlock()
    }
    
    func values() -> [Element] {
        lock.lock()
        let snapshot = Array(storage)
        lock.unlock()
        return snapshot
    }
}
```

**Recommended Improvement:**
```swift
private actor ThreadSafeSet<Element: Hashable & Sendable> {
    private var storage = Set<Element>()
    
    func insert(_ element: Element) {
        storage.insert(element)
    }
    
    func values() -> [Element] {
        Array(storage)
    }
}
```

**Benefits:**
- ✅ Compile-time thread safety guarantees
- ✅ No manual lock management
- ✅ Automatic `Sendable` conformance
- ✅ Eliminates `@unchecked Sendable` annotation
- ✅ Simpler, more maintainable code

**Note:** With the Task Group approach above, the actor may not be needed if we collect results directly. However, if you need shared mutable state elsewhere, actors are the modern approach.

### Priority 3: Make API Async (Optional)

**Consideration:** Since this is a CLI tool (`SwiftFindRefs`), the synchronous API might be acceptable. However, making it async would:
- Enable better cancellation support
- Allow for future async operations (e.g., async file I/O)
- Align with modern Swift patterns

**If making async:**
```swift
func fileReferences(of symbolName: String, symbolType: String?) async throws -> [String] {
    let store = try IndexStore(path: indexStorePath)
    return try await fileReferences(of: symbolName, symbolType: symbolType, from: store)
}

func fileReferences(
    of symbolName: String,
    symbolType: String?,
    from store: some IndexStoreProviding & Sendable
) async throws -> [String] {
    let query = SymbolQuery(name: symbolName, kindString: symbolType)
    let index = RecordIndex.build(from: store)
    return await searchRecordsInParallel(store: store, index: index, query: query)
}
```

**Update call site in `CompositionRoot.swift`:**
```swift
func run() async throws {
    // ... existing code ...
    let references = try await indexStoreFinder.fileReferences(
        of: symbolName,
        symbolType: symbolType
    )
    // ... existing code ...
}
```

**Update `SwiftFindRefs.swift`:**
```swift
func run() throws {
    // ... existing code ...
    Task {
        do {
            try await compositionRoot.run()
        } catch {
            // Handle error
        }
    }
}
```

## Migration Strategy

### Phase 1: Internal Refactoring (Low Risk)
1. Replace `ThreadSafeSet` with actor
2. Replace `DispatchQueue.concurrentPerform` with `withTaskGroup`
3. Keep public API synchronous initially
4. Run existing tests to verify behavior

### Phase 2: API Modernization (Medium Risk)
1. Make `fileReferences` methods `async`
2. Update `CompositionRoot.run()` to be `async`
3. Update `SwiftFindRefs.run()` to bridge sync to async
4. Update tests to use async patterns

### Phase 3: Enhanced Features (Future)
1. Add cancellation support
2. Add progress reporting via `AsyncSequence`
3. Consider parallelizing `RecordIndex.build()` if needed

## Testing Considerations

When migrating, ensure:
- ✅ All existing tests pass
- ✅ Parallel execution behavior is preserved
- ✅ Results remain deterministic (sorted order)
- ✅ Error handling works correctly
- ✅ No data races (use Thread Sanitizer)

## Additional Recommendations

### 1. Enable Strict Concurrency Checking

Add to `Package.swift`:
```swift
.target(
    name: "SwiftFindRefs",
    dependencies: [...],
    swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency=targeted")
    ]
)
```

This will help catch concurrency issues during development.

### 2. Consider Sendable Conformance

Ensure types that cross isolation boundaries conform to `Sendable`:
- `RecordIndex` - already a struct (value type), should be `Sendable`
- `SymbolQuery` - check if it needs `Sendable` conformance

### 3. Documentation

When using `@unchecked Sendable` or actors, document:
- Why the approach is safe
- What invariants must be maintained
- Any known limitations

## References

- [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)
- [Swift Evolution: Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
- [Swift Evolution: Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
