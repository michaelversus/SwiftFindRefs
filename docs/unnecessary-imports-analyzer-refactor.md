# UnnecessaryImportsAnalyzer Refactor Plan

## Overview
The `UnnecessaryImportsAnalyzer` currently performs collection, import extraction, module usage evaluation, and result aggregation in a single `analyze(store:indexStorePath:)` function (~400 lines). This plan decomposes that logic into smaller collaborators to improve readability, testability, and future extensibility.

## Current Responsibilities to Separate
- **Index store collection**: Invokes `IndexStoreCollecting.collectUnitsAndRecords` and builds helper dictionaries.
- **File pre-processing**: Reads source lines, filters generated/third-party files, caches results.
- **Import discovery**: Chooses between IndexStore-derived imports and parsed imports per file.
- **Per-file orchestration**: Creates task-group work items, handles async execution, and aggregates results.
- **Module requirement evaluation**: Cross-references occurrences, USRs, symbol names, typealiases, and source text.
- **Error handling**: Detects missing modules and surfaces `RemoveError.missingModuleInIndex`.

## Proposed Components
1. **`UnitContextProvider`**
    - Input: `IndexStoreProviding`, `indexStorePath`.
    - Output: `(unitsByModule: [String: [UnitSnapshot]], occurrencesByFile: [String: [OccurrenceSnapshot]])`.
    - Responsibility: wrap `collector.collectUnitsAndRecords` and build memoized lookups.
    - Test notes: mock `IndexStoreCollecting` to verify correct grouping.

2. **`FileLinesCache`**
    - Input: `FileSystemProvider` and list of paths.
    - Responsibility: lazily read and cache file lines while skipping generated/third-party files.
    - Exposes `lines(for:) -> [String]?` for downstream consumers.

3. **`ImportSourceResolver`**
    - Protocol layering `IndexStoreImportExtracting` and `ImportExtracting` decisions.
    - Handles ignored modules, prefixes, and fallback logic.
    - Returns `importsByFile: [String: Set<String>]`.

4. **`PerFileAnalysisCoordinator`**
    - Owns `TaskGroup` creation, filters eligible files, and delegates to `ModuleUsageAnalyzer`.
    - Consolidates `(file, unnecessaryModules)` pairs.

5. **`ModuleUsageAnalyzer`**
    - Input struct capturing one file’s imports, `unitsByModule`, cached lines, and occurrences.
    - Delegates detail work to narrower helpers:
        - `DefinitionMatchEvaluator`
        - `USRContainmentChecker`
        - `SymbolNameFallbackMatcher`
        - `TypeAliasUsageDetector`
    - Returns `ModuleUsageResult` containing `required`, `seen`, and error context.

6. **`ResultAssembler`**
    - Consumes `ModuleUsageResult` to produce final `[String: Set<String>]` map and raises missing-module errors.

## Data & Control Flow
1. `UnnecessaryImportsAnalyzer` receives `store`/`indexStorePath` and orchestrates:
    1. `UnitContextProvider.makeContext()` → base data structures.
    2. `FileLinesCache.preload()` for non-generated files.
    3. `ImportSourceResolver.resolveImports(for:unitSnapshots)`.
    4. `PerFileAnalysisCoordinator.run(importsByFile:...)` spawns tasks.
2. Each task uses `ModuleUsageAnalyzer` to evaluate a single source file:
    - Pulls referenced symbols via existing `ImportSymbolReferenceResolver`.
    - Consults helper analyzers to mark modules as required.
3. `ResultAssembler` aggregates task outputs, subtracts required modules, and returns unnecessary imports.
4. Errors propagate via `throws` from helpers; coordinator adds file context before rethrowing.

## Testing Strategy
- **Unit level**:
    - `UnitContextProviderTests`: verify grouping by module and filtering logic.
    - `FileLinesCacheTests`: assert caching behavior and generated/third-party filtering.
    - `ImportSourceResolverTests`: use fake extractor implementations to cover IndexStore vs fallback paths.
    - `ModuleUsageAnalyzerTests`: inject stub occurrences/unit maps to validate USR, name, and typealias heuristics.
    - Helper tests (Definition/TypeAlias) focus on edge cases without async concerns.
- **Integration level**:
    - Keep/extend existing analyzer test to ensure same observable behavior.
    - Add regression tests around `RemoveError.missingModuleInIndex`.

## Incremental Migration Steps
1. **Encapsulate context creation**: Move unit/occurrence grouping into `UnitContextProvider` and update `analyze` to call it.
2. **Introduce `FileLinesCache`**: Replace ad-hoc dictionaries with cache usage.
3. **Extract import resolution logic**: Build `ImportSourceResolver`, inject into analyzer, and cover with tests.
4. **Refactor per-file loop**: Create `ModuleUsageAnalyzer` + helpers; call from within existing task-group loop.
5. **Wrap results**: Add `ResultAssembler` to centralize missing-module detection and difference calculation.
6. **Finalize**: Once all responsibilities move out, shrink `UnnecessaryImportsAnalyzer` into a coordinator wiring dependencies in the composition root.

## Open Questions / Decisions
- Should `ImportSourceResolver` live beside current extractor types or within analyzer namespace?
- Do we want configuration toggles (e.g., skip typealias scan) for performance-sensitive contexts?
- Should the new helpers be internal structs or protocols to allow swapping implementations later?
