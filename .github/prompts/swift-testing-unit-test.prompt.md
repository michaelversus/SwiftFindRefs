---
mode: 'agent'
description: 'Generate a new Swift-Tesing (the new apple framework that will replace XCTest. More details below) unit test file for a given Swift type by analyzing its public API (pure logic, value-returning & side‑effect methods), leveraging optional fixtures, and producing focused, intention‑revealing tests.'
---
Your goal is to intelligently generate a new **unit test** file for a given Swift type (struct/class/enum). You will (introducing the term once): **System Under Test (SUT)** refers to the type under test; after this point use the variable name `sut` consistently.
1. Read the instructions to understand apple's new Swift Testing library at `/.github/instructions/swift-testing_api.md` and `/.github/instructions/swift-testingplaybook.md`.
2. Read the source file of the type.
3. Infer its public API (methods, computed properties, initializers).
4. Propose meaningful test scenarios focusing on logic branches and value transformations.
5. Use any provided fixtures file to instantiate complex model arguments.
6. Create a test file under the proper path using Swift Testing only.

The emphasis is on producing *runnable, useful starting tests* that cover:
- Return values & transformations
- Branching (conditionals / optional handling / enum switches)
- Error throwing paths (if any)
- Async functions (if any)
- Mutating / side‑effect methods (state change assertions)

If code semantics cannot be fully inferred, generate a test skeleton with clear `// TODO:` guidance while still wiring compilation‑ready scaffolding.

---
## 1. Required User Input (ask for JSON):
Prompt the user for a JSON object with this shape:
```json
{
    "typeName": "XcodeParser",
    "typeRelativePath": "Sources/XcodeParser/XcodeParser.swift",
    "testFilePath": "Tests/XcodeParser/XcodeParserTests.swift",
    "mocksFilePaths": [
        "Tests/Mocks/ServiceMocks.swift",
        "Tests/Mocks/RepositoryMocks.swift"
    ]
}
```
Field explanations:
- `typeName` (required): Name of the Swift type to test.
- `typeRelativePath` (required): Path to the `.swift` file *relative to project root*.
- `mocksFilePaths` (optional): Relative paths to files containing mock dependencies.
- `testFilePath` (optional): Full path where the test file should be created.

Try to propose a json input to the user based on context and existing file structure.
Reject / re‑ask if mandatory fields are missing.

---
## 2. Analyze the Source File
Read `typeRelativePath`.
Identify inside `typeName`:
1. Public & internal (default) initializers (`init`).
2. Public & internal instance methods (exclude private/fileprivate/static unless clearly utility for logic under test).
3. Public & internal static methods (only include if they contain logic, not trivial constants).
4. Public computed properties (non‑trivial bodies) — treat as zero‑argument functions returning a value.
5. Conformance‑driven methods (e.g., `encode(to:)`, `hash(into:)`, `==`, `Comparable` funcs) — generate at most 1 targeted test each if logic exists.

Collect for each method:
- Name
- Parameters (label, type, optionality, default)
- Return type (and optionality)
- Mutating / non‑mutating
- `async` / `throws`
- Branch indicators: presence of `if`, `guard`, `switch` in body (approximate by text scan)

---
## 3. Determine Test Scenarios
For each method/property pick representative scenarios ("scenario" is the consistent term; avoid mixing with "case"):
- Optional parameter: test nil & non‑nil.
- Enum parameter: at least 2 distinct cases (or all if <=3).
- Bool parameter: `true` & `false`.
- Numeric parameter: typical + boundary (e.g. 0, positive, maybe negative if meaningful).
- Collections: empty vs non‑empty.
- Throwing methods: success path + at least one expected error (infer by searching `throw` expressions or custom `Error` enums nearby). If not inferable, create TODO for error scenario.
- Branch heuristics: if body has `switch` over an enum property/parameter, attempt a test per significant case.

Limit explosion: Cap default generated scenarios per method to **max 4** unless method is trivial (then just 1). Prioritize coverage: success + main alternative branches.

---
## 4. Deciding Between Fixtures and Mocks (Models vs Dependencies)
Distinguish between **models (value data)** that should use `fixtures()` and **dependencies (collaborators)** that should use mocks. Follow this decision strategy for every initializer parameter and (if needed) public stored property participating in dependency injection.

### 4.1 Classification Algorithm
For each initializer parameter (and any factory method parameters):
1. Extract the parameter type name (strip optionals & generics, e.g. `SomeService?` -> `SomeService`).
2. Determine if it is a protocol dependency:
    - If the source file itself declares `protocol <TypeName>` OR
    - The type name ends with `Protocol` OR
    - A mock type for it exists in `mocksFilePath` (pattern: `<TypeName>Mock`, `Mock<TypeName>`, or `<TypeName>MockImpl`).
    -> Then treat as a **dependency** (use a mock, NOT a fixture).
3. Else determine if it is a model:
    - Custom (capitalized) non-protocol type and not one of the primitive / standard types: `String`, `Int`, `Double`, `Bool`, `Array`, `Dictionary`, `Set`, `Date`, `URL`, `Data`, `UUID`, `CGFloat`, `Result`, `Optional`, `ClosedRange`, `Range`.
    -> Treat as **model** (use fixture if available).
4. If still ambiguous (e.g. generic `T`, `Element`, or unknown): create a TODO and synthesize a minimal placeholder value if possible.

### 4.2 Retrieving / Creating Fixtures for Models
For any classified **model** type:
1. Search text for `extension <Type> {` followed by `static func fixtures`.
2. If found:
    - Instantiate with `<Type>.fixtures()`.
    - To produce scenario variations, pass parameters present in the `fixtures` signature (e.g. toggling optional arguments, boundary numeric values, enum alternatives). Only override arguments necessary for a scenario.
3. If not found but the model has a public initializer (detected by scanning for `init(` inside its declaration) use that initializer with simple literal arguments.
4. If neither found, insert placeholder comment `// TODO: supply <Type>` and create a temporary `_ = /* <Type> placeholder */` to keep code compiling.

### 4.3 Locating or Synthesizing Mocks for Dependencies
For any classified **dependency** (protocol type `SomeService`):
1. If `mocksFilePaths` provided, read it (only once; cache content).
2. Search for concrete mock declarations matching regex-like textual patterns:
    - `class SomeServiceMock`, `final class SomeServiceMock`, `struct SomeServiceMock`
    - `class MockSomeService`
    - `class SomeServiceMockImpl`
3. If a mock type is found, instantiate with its simplest accessible initializer (prefer parameterless). Name the variable `someServiceMock` (camelCase of type + `Mock`).
4. If no mock exists, synthesize an inline private mock inside the test file:
```swift
private final class SomeServiceMock: SomeService {
     // Track calls
     var fetchCalled = false
     // Provide stubbed returns
     func fetch() throws -> [Item] { 
        fetchCalled = true 
        return [] 
    } // Adjust signature as discovered
}
```
5. Store mock instance(s) as **private stored properties on the test case**. `makeSUT()` only focuses on constructing the SUT. This avoids returning tuples and keeps tests cleaner.
```swift
@Suite("XcodeParserTests", .serialized)
struct XcodeParserTests {
    // MARK: - Mocks
    private var serviceMock = ServiceMock()

    private func makeSUT() -> XcodeParser {
        XcodeParser(service: serviceMock)
    }
}
```
6. For multiple dependencies create one property per mock (e.g., `analyticsMock`, `cacheMock`).
7. If interaction assertions are required (e.g., verifying `fetchCalled`), assert directly on the stored mock property after invoking the SUT method.

### 4.4 Choosing Between Fixture vs Mock
Use fixtures for: pure data inputs whose values influence logic (entities, value objects, DTOs, configuration structs, enums with associated data).
Use mocks for: collaborators that perform side effects, IO, network, persistence, system queries, clocks, formatters with behavior, strategy objects.

Heuristics for identifying a collaborator (thus mock):
- Protocol requirement names contain verbs (`fetch`, `load`, `save`, `update`, `calculate`, `notify`).
- The type or protocol name ends with `Service`, `Repository`, `Client`, `Provider`, `Manager`, `Store`, `Engine`, `Formatter`.
- Methods are `async` or `throws` (often side‑effectful). (Not definitive, but strong hint.)

If a type satisfies both (e.g., `XcodeTargetsProvider` struct with pure data), default to fixture unless it conforms to a protocol injected into SUT.

### 4.5 Scenario Variation Strategy
When generating multiple test scenarios:
- Vary model fixtures across meaningful axes (optional set/unset, enum cases, boundary numerics) while keeping mocks constant (unless testing interaction differences).
- Use mock state tracking flags (e.g., `fetchCalled`) for interaction assertions.
- Do not overfit: at most 1 interaction assertion per test unless multiple calls matter.

### 4.6 Caching & Efficiency
Read each element of `mocksFilePaths` at most once. Reuse parsed info to avoid redundant work.

### 4.7 Fallback
If classification uncertain or required methods of a protocol can't be inferred, generate a minimal empty mock with TODO markers for unimplemented methods so the file still compiles.

---
## 5. Test File Path & Creation for Modules
Derive sub-path relative to the module's `Sources/<moduleName>/` directory.
Example: If `typeRelativePath` = `Sources/XcodeParser/XcodeParser.swift` then sub-path = `XcodeParser/`.
Target test directory path: `Tests/${subPath}`. Create directories as needed.
Filename: `${typeName}Tests.swift`.

If `testFilePath` is provided, use it directly instead of deriving from module structure.

### Handling Existing Test File
If a `${typeName}Tests.swift` file already exists:
1. Read existing test class(es) and collect current `func test_` names.
2. Only add new test functions whose names are not already present.
3. If a generated scenario name collides but logic differs, append a suffix like `_Variant2` OR prefer adding a TODO instead of duplicating ambiguous logic.
4. Preserve existing helpers, mocks, MARK sections; append new tests under a new `// MARK: - <MethodName>` group.
5. If multiple test classes target the same type, choose the one whose name matches `${typeName}Tests`; otherwise add a TODO noting divergence and append to the first class.
6. Never overwrite or delete user-written code; only append.

---
## 6. Generate Test File Content
Imports (conditionally include only what compiles):
```swift
import Testing
@testable import XcodeTargets
```
Add any additional frameworks only if referenced (e.g., `Foundation`).

Access Level Assumptions:
- Assume the test target uses `@testable import` so `internal` members are visible.
- If a needed member is not accessible (e.g., truly `private` / `fileprivate` or different module), skip generating that specific test and insert a TODO comment: `// TODO: Cannot access <member>; adjust visibility or add seam`.

Use the Structure:
```swift
@Suite("${typeName} Tests")
struct ${typeName}Tests {

    // MARK: - Tests
    @Test("test methodName ScenarioDescription")
    func test_methodName_ScenarioDescription() throws { 
        // Given
        let sut = ${typeName}(/* init params */)

        // When 
        let result = sut.methodName(/* params */)

        // Then
        #expect(result == /* expected value */)
    }
}
```

Guidelines:
- Use `// Given`, `// When`, `// Then` comments.
- Prefer arranging input values with clearly named locals.
- For value returning methods use `#expect(value == /* expected value */)`. Provide expected placeholders if actual logic opaque.
- For mutations: capture initial state, call method, assert changed/new state.
- For throwing funcs: use `#expect(throws: ErrorType.self)`. If error type known, assert it.
- Prefer specific error assertions:
```swift
let error = #expect(throws: SomeError.self) {
    try sut.methodThatThrows()
}
#expect(error == .specificCase)
```
- Prefer `#require(optionalValue)` over force-unwrapping (`!`). If optional unwrapping is logically required, do:
```swift
let value = try #require(optionalValue, "Expected non-nil <Description>")
```
    Never use `!` inside test bodies; if unwrap fails the test should fail explicitly.
- For async callback / delegate style APIs use expectations:
```swift
@Test func truckEvents() async {
  await confirmation("…") { soldFood in
    FoodTruck.shared.eventHandler = { event in
      if case .soldFood = event {
        soldFood()
      }
    }
    await Customer().buy(.soup)
  }
  ...
}
```
- Async methods: declare test as `async` (or wrap with expectations for legacy). Example:
```swift
@Test("test fetchPrices returns expected models")
func test_fetchPrices_ReturnsExpectedModels() async throws {
    // Given
    let sut = makeSUT()
    // When
    let result = try await sut.fetchPrices()
    // Then
    #expect(result.isEmpty == false)
}
```
- If randomness / time involved: inject deterministic seed or add TODO.
- Add a `// MARK: - Helpers` section for any test helpers (e.g., dummy errors, mock collaborators) you synthesize.

### Test Naming Convention
Each test function MUST follow this base signature:
```swift
@Test("test <SubjectOrMethod> <ScenarioDescription>")
func test_<SubjectOrMethod>_<ScenarioDescription>() { ... }
```

Where:
- `<SubjectOrMethod>` is the method name under test. For initializer tests use `init`. For computed properties use the property name.
- `<ScenarioDescription>` should encode the Given / When / Then narrative in a concise underscore-separated form.

Preferred structural pattern:
`Given<GivenState>_When<ActionOrInvocation>_Then<ExpectedOutcome>`

However, to stay idiomatic with common Swift style, you MAY omit the explicit `When` token if the action is obvious (method invocation) and start directly after the method with a `With/Without` or contextual clause followed by the expected outcome, e.g.:
`test_total_WithTaxAndNoDiscount_returnsBasePlusTax`
`test_total_WithNilTaxAndDiscount_returnsBaseMinusDiscount`

Rules & Heuristics for auto-generation:
1. Start scenario with `With` or `Given` when highlighting input conditions (e.g., `WithNilUser`, `GivenEmptyCache`).
2. For absence states use `Without` (e.g., `WithoutDiscount`).
3. Use camelCase inside each segment; separate major segments with underscores.
4. Expected outcome segment should start with a present-tense verb like `returns`, `produces`, `yields`, `throws`, `emits`, `updates`, or `sets`.
5. For throwing scenarios use suffix `_throws<ErrorName>` if specific, else `_throwsError`.
6. For async operations that produce a value, treat them the same; do not add `Async` unless disambiguation is needed.
7. If multiple variants differ only by one input dimension, share the common prefix to visually group them.

Fallback: If the agent cannot confidently infer a rich scenario name, produce a safe placeholder like `test_methodName_GivenInputs_WhenExecuted_ThenTODO` and insert a TODO comment inside the test body to refine.

---
## 7. Helper Generation Rules
If the type interacts with protocols (search for `protocol` usages in same file & stored properties typed as protocol):
- For a collaborator property (e.g., `let api: PricingAPI` passed in initializer), emit a minimal nested mock class/struct implementing required methods with deterministic return values.

Example mock:
```swift
private final class PricingAPIMock: PricingAPI {
    var fetchPricesCalled = false
    
    func fetchPrices() async throws -> [Price] { 
        fetchPricesCalled = true
        return [.fixtures()]
    }
}
```

Use mocks (collaborator test doubles) in `makeSUT()` by referencing the test-case stored properties. Do not return tuples; instead assert directly on the stored mock properties (e.g., `#expect(pricingServiceMock.fetchPricesCalled == true)`).

---
## 8. Edge Cases & Quality
Handle special patterns:
- Generic Types: Include generic arguments if constraints resolvable; otherwise add TODO.
- Actors: Mark tests `@MainActor` or use `await` properly when calling actor-isolated methods.
- Value Types Mutating Methods: Create `var sut = makeSUT()` then call.
- Singletons / static caches: Provide TODO to inject overriding mechanism.

Actors & Isolation:
- If SUT is an `actor` or methods are `@MainActor`, annotate tests or specific methods with `@MainActor` for thread safety.
- Always `await` actor method invocations; never access actor-isolated state without `await`.

Deterministic Concurrency:
- Avoid `Task.sleep` in tests; prefer `await confirmation`.
- If production code internally sleeps or dispatches with delays and there's no injection point, add a TODO suggesting a schedulable abstraction.

Randomness & Time:
- If code uses `Date()`, `UUID()`, random numbers, capture values immediately and assert relationships (e.g., ordering) rather than exact equality.
- Prefer injecting a `Clock` / `UUIDProvider` / `RandomNumberGenerator` into the SUT; add TODO if such seam does not exist.

Additional Edge Patterns:
- Protocols with Associated Types / Complex `where` Clauses: If a dependency protocol has associated types or multiple generic constraints and no lightweight existing mock is found, generate a minimal placeholder mock only for methods actually invoked (others: TODO stubs). If requirements appear large, skip detailed mock and add `// TODO: Provide specialized test double for <Protocol>`.
- Static Factory Methods (e.g., `static func makeDefault()`): Treat as convenience initializers. Generate at least one test that builds the SUT via the factory and asserts key invariants (naming pattern: `test_makeDefault_Given..._Then...`).
- Result-returning Methods (`Result<T, E>`): Add tests asserting both `.success` and `.failure` when error production paths are detectable. Pattern:
```swift
switch result {
case .success(let value): #require(value)
case .failure(let error): #expect(error as? MyError == .someCase)
}
```
If only one branch is inferable, add TODO for the other.
- Availability Attributes (`@available`): If the method or type under test is gated by availability, wrap the test in the same availability annotation. If current deployment target may exclude it, add TODO noting environment mismatch.
- Conditional Compilation (`#if DEBUG`, feature flags): If core logic appears only inside a conditional block, emit a TODO: `// TODO: Logic under #if DEBUG not testable in current build configuration` and skip generating unreachable assertions.

### Safeguards
- Never introduce `fatalError("TODO")` (or any `fatalError`) as a placeholder inside generated tests or helper mocks. Use `Issue.record("TODO: <describe missing assertion or setup>")` plus a clarifying comment instead so the test suite surfaces actionable failures without aborting the process.
- Avoid dumping large model or JSON representations in assertions or logs. Keep expected values concise (e.g., assert on key fields or counts). If a full object comparison is desired but would be verbose, add a TODO suggesting a custom equality helper.
- Refrain from printing (`print`) in generated tests; rely on assertions. If diagnostic output seems necessary, add a TODO recommending structured logging instead.

Always ensure file compiles: no unused variables (underscore prefix if placeholder), no referencing unresolved types (use TODO comments when unknown). Prefer at least 1 concrete assertion per generated method test; where impossible, insert `Issue.record("TODO: Implement assertion for <method>")` so the test reminds developers to finalize it.

---
## 9. Output Expectations
After generation:
1. State the path where the file was written.
2. Provide a grouped summary by method:
    - For each method/property under test output: `- methodName: <count> scenario(s)` followed by an indented list of scenario test function names.
3. List any methods that were discovered but skipped with an explicit reason (e.g., "private", "unreachable due to availability", "complex associated type protocol", "no observable effect").
4. Provide total counts: methods covered, methods skipped, total scenarios generated.
5. List unresolved custom types (those that required TODO placeholders) under a separate heading `Unresolved Types:` distinct from generic TODOs.
6. Summarize TODO placeholders (excluding unresolved type list) grouped by category (e.g., `inaccessible member`, `randomness injection`, `time dependency`, `error scenario not inferred`).
7. (If existing test file merged) Indicate how many new tests appended vs already existing.

---
## 10. Example
*Source (`PriceCalculator.swift`)*
```swift
public struct PriceCalculator {
    let base: Decimal
    public init(base: Decimal) { self.base = base }
    public func total(applying tax: Decimal?, discount: Decimal = 0) -> Decimal {
        var result = base - discount
        if let tax { result += result * tax }
        return result
    }
}
```
*Generated Test (`PriceCalculatorTests.swift`)*
```swift
import Testing
@testable import XcodeTargets

@Suite("PriceCalculator Tests")
struct PriceCalculatorTests {

    private func makeSUT(base: Decimal = 100) -> PriceCalculator { 
        PriceCalculator(base: base)
    }

    @Test("test total with tax and no discount returns base plus tax")
    func test_total_WithTaxAndNoDiscount_returnsBasePlusTax() {
        // Given
        let sut = makeSUT(base: 100)
        let tax: Decimal = 0.20

        // When
        let result = sut.total(applying: tax, discount: 0)

        // Then
        #expect(result == 120)
    }

    @Test("test total with nil tax and discount returns base minus discount")
    func test_total_WithNilTaxAndDiscount_returnsBaseMinusDiscount() {
        // Given
        let sut = makeSUT(base: 100)

        // When
        let result = sut.total(applying: nil, discount: 10)

        // Then
        #expect(result == 90)
    }
}
```

---
## 11. Requirements Recap (Must Do)
- Ask for & validate JSON input (Step 1 structure).
- Read & parse target type source file.
- Infer testable API surface & propose scenarios.
- Use fixtures for custom model arguments when available.
- Classify initializer parameters as fixtures (models) vs mocks (dependencies) per Section 4 and apply correct creation strategy.
- Mirror directory structure inside `Tests`.
- Generate class named `${typeName}Tests` with `Given/When/Then` sections.
- At least one test per non‑trivial method; cap at 4 scenarios each.
- Async / throwing handled properly.
- Enforce test naming convention `test_<SubjectOrMethod>_<ScenarioDescription>` with Given/When/Then encoded (Section: Test Naming Convention).
- Prefer `#require` over force unwrapping; never use `!` in test bodies.
- Handle existing `${typeName}Tests.swift` by merging (append new unique tests, no overwrites).
- Provide specific error assertions using `#expect(throws: <ErrorType>)` with error type casting.
- Use `await confirmation` for callback / delegate async APIs.
- Apply `@MainActor` to tests interacting with main-actor isolated APIs or actors when needed.
- Avoid `Task.sleep`; favor `await confirmation`.
- Add TODOs when randomness/time prevent deterministic assertions and recommend injecting time/UUID/random providers.
- Handle protocols with associated types by minimal placeholder mocks or TODO if heavy.
- Treat static factory methods as alternative initializer scenarios.
- For `Result<T,E>` methods cover success and failure when possible; add TODO for unreachable branch.
- Mirror `@available` attributes or add TODO if unavailable.
- Add TODO when logic only present inside `#if` blocks not active under current configuration.
- Output grouped summary by method with scenario counts, list skipped methods with reasons, and enumerate unresolved types separately from generic TODOs.
- Never use `fatalError` placeholders; prefer `Issue.record` with a descriptive TODO.
- Avoid large model dumps or excessive printing; assert on minimal, meaningful properties.
- Insert TODOs only when logic not inferable; summarize them at end.
- Produce compilation‑ready Swift (best effort) with placeholders instead of invalid code.

---
## 12. Nice-to-Haves (If Simple)
- Factor repeated arrangement into helper methods.
- Provide `// MARK:` separators.
- Add mutation test for each mutating method.

Focus purely on Swift Testing unit tests.
